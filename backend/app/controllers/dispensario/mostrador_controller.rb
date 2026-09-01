module Dispensario
  # El MOSTRADOR de una sede: la mercadería que está sobre la mesa hoy.
  #
  # Es la caja de turno aplicada a producto. Se abre y se cierra desde la misma vista, tantas
  # veces por día como haga falta: dos dispensadores no atienden a la vez, se turnan, y
  # cerrar-y-reabrir es el arqueo.
  #
  # Lo abre el que va a atender —no hace falta que esté el admin—, porque el número de partida
  # se HEREDA del cierre anterior en vez de declararse. Ahí está el control: quien abre no elige
  # con cuánto arranca, solo puede corregirlo, y si lo corrige queda la diferencia con su nombre.
  class MostradorController < ApplicationController
    before_action :authenticate_user!
    before_action -> { require_feature!(:produccion_dispensa) }
    before_action :set_mostrador
    before_action :require_operador

    # GET /sedes/:sede_id/mostrador
    #
    # El turno abierto si lo hay, y si no, con qué se abriría: lo que dejó el cierre anterior
    # (`sugerido`) y todo lo que se puede subir a la mesa desde el depósito (`disponibles`).
    def actual
      turno = @mostrador.turno_abierto
      render json: {
        mostrador:   { id: @mostrador.id, nombre: @mostrador.nombre,
                       sede: { id: @mostrador.sede_id, nombre: @mostrador.sede&.nombre } },
        turno:       serialize_turno(turno),
        # Turnos cerrados con faltante que nadie miró. Viaja en la carga principal a propósito:
        # si sólo apareciera al entrar a la solapa de Merma, el aviso no avisa nada — hay que
        # verlo sin ir a buscarlo.
        sin_revisar: gestiona? ? turnos_sin_revisar : 0,
        # Con cuánto arrancaría la caja: lo que quedó anoche después de retirar la recaudación.
        # Heredado, no declarado — si el número lo pone el que abre, puede poner cualquiera.
        fondo_sugerido: turno ? nil : fondo_sugerido,
        sugerido:    turno ? [] : sugerido,
        # Siempre, no sólo al abrir: con el turno andando es de donde sale lo que se repone a
        # media tarde cuando se acaba algo y hay cola.
        disponibles: disponibles.map { |s| serialize_stock(s) },
      }
    end

    # POST /sedes/:sede_id/mostrador/abrir
    #   { monto_inicial_ars, items: [{ stock_id, cantidad }], notas }
    def abrir
      res = Mostradores::AbrirTurno.call(
        mostrador: @mostrador, usuario: current_user,
        items: params[:items] || [], notas: params[:notas],
        monto_inicial_ars: params[:monto_inicial_ars]
      )
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      render json: serialize_turno(res.turno.reload), status: :created
    end

    # POST /sedes/:sede_id/mostrador/confirmar { correcciones: [{ item_id, contado, motivo }] }
    #
    # El que va a atender recibe lo que dejó el admin. Puede confirmarlo tal cual o corregirlo, y
    # la corrección queda con su nombre. Hasta que no firma, no se dispensa: si se pudiera
    # atender sin confirmar, al cierre respondería por lo que otro declaró y nadie miró.
    def confirmar
      con_turno do |turno|
        Mostradores::ConfirmarApertura.call(turno: turno, usuario: current_user,
                                            correcciones: params[:correcciones] || [],
                                            efectivo_contado: params[:efectivo_contado_ars],
                                            motivo_efectivo: params[:motivo_efectivo],
                                            notas: params[:notas])
      end
    end

    # POST /sedes/:sede_id/mostrador/contar { item_id, contado, motivo }
    #
    # Contar UN producto sin cerrar el turno. Cerrar y reabrir es el arqueo completo, pero con
    # quince frascos son veinte minutos y termina siendo el control que no se ejecuta.
    def contar
      con_turno do |turno|
        item = turno.items.find_by(id: params[:item_id])
        next Mostradores::MoverStock::Result.new(ok: false, error: 'Ese producto no está en el turno') if item.nil?

        item.registrar_conteo!(contado: params[:contado], usuario: current_user,
                               motivo: params[:motivo])
        Mostradores::MoverStock::Result.new(ok: true, item: item)
      end
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /sedes/:sede_id/mostrador/cargar { stock_id, cantidad, notas }
    #
    # Subir mercadería del depósito a la mesa con el turno ya abierto. Lo hace administración,
    # pero un dispensador solo también puede: queda marcado como carga sin supervisión.
    def cargar
      stock = current_user.club.stocks.find_by(id: params[:stock_id])
      con_turno do |turno|
        Mostradores::MoverStock.cargar(turno: turno, usuario: current_user, stock: stock,
                                       cantidad: params[:cantidad], notas: params[:notas])
      end
    end

    # POST /sedes/:sede_id/mostrador/devolver { item_id, cantidad, notas }
    def devolver
      con_turno do |turno|
        item = turno.items.find_by(id: params[:item_id])
        next Mostradores::MoverStock::Result.new(ok: false, error: 'Ese producto no está en el turno') if item.nil?

        Mostradores::MoverStock.devolver(turno: turno, usuario: current_user, item: item,
                                         cantidad: params[:cantidad], notas: params[:notas])
      end
    end

    # POST /sedes/:sede_id/mostrador/cerrar
    #   { conteos: [{ item_id, contado, motivo }], efectivo_contado_ars,
    #     fondo_siguiente_ars, retirado_por_id, notas }
    #
    # Cierra EN EL ACTO, sin esperar al admin: si el turno quedara pendiente de su visto bueno, a
    # las once de la noche el mostrador está bloqueado y el que abre mañana no arranca. La
    # diferencia queda para que la revise cuando aparezca.
    def cerrar
      con_turno do |turno|
        Mostradores::CerrarTurno.call(
          turno: turno, usuario: current_user,
          conteos: params[:conteos] || [],
          efectivo_contado_ars: params[:efectivo_contado_ars],
          fondo_siguiente_ars:  params[:fondo_siguiente_ars],
          retirado_por: current_user.club.users.find_by(id: params[:retirado_por_id]),
          notas: params[:notas]
        )
      end
    end

    # GET /sedes/:sede_id/mostrador/merma?desde=&hasta=
    #
    # Dónde se le va el producto a la organización. No es una auditoría: la merma es inevitable y
    # el punto de medirla es encontrar el cuello de botella — qué producto, en qué momento.
    def merma
      return render json: { error: 'No autorizado' }, status: :forbidden unless gestiona?

      # `sede_id=todas` compara el club entero. La ruta sigue colgando de una sede porque es
      # como se navega, pero la pregunta "¿dónde se pierde más?" no es de una sede sola.
      objetivo = params[:todas].present? ? mostradores_del_club : @mostrador
      render json: Mostradores::Merma.call(mostrador: objetivo,
                                           desde: params[:desde], hasta: params[:hasta])
    rescue ArgumentError, Date::Error
      render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
    end

    # GET /sedes/:sede_id/mostrador/turnos/:id — un turno cerrado, para poder corregir su conteo
    def turno
      return render json: { error: 'No autorizado' }, status: :forbidden unless gestiona?

      t = @mostrador.turno_mostradores.find_by(id: params[:id])
      return render json: { error: 'Turno no encontrado' }, status: :not_found if t.nil?

      render json: serialize_turno(t)
    end

    # POST /sedes/:sede_id/mostrador/turnos/:id/corregir
    #   { conteos: [{ item_id, contado }], motivo }
    #
    # Arreglar un conteo mal cargado en un turno que ya cerró. Es el único lugar del módulo donde
    # un dedazo destruye datos —21 en vez de 215 ajusta el inventario real—, y hasta acá no tenía
    # vuelta atrás. No borra nada: asienta la diferencia entre lo contado y lo corregido.
    def corregir
      return render json: { error: 'No autorizado' }, status: :forbidden unless gestiona?

      turno = @mostrador.turno_mostradores.find_by(id: params[:id])
      return render json: { error: 'Turno no encontrado' }, status: :not_found if turno.nil?

      res = Mostradores::CorregirCierre.call(turno: turno, usuario: current_user,
                                             conteos: params[:conteos] || [], motivo: params[:motivo])
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      render json: serialize_turno(res.turno)
    end

    # POST /sedes/:sede_id/mostrador/turnos/:id/revisar — "ya lo miré"
    def revisar
      return render json: { error: 'No autorizado' }, status: :forbidden unless gestiona?

      turno = @mostrador.turno_mostradores.find_by(id: params[:id])
      return render json: { error: 'Turno no encontrado' }, status: :not_found if turno.nil?

      turno.update!(revisado_por: current_user, revisado_at: Time.current)
      render json: { id: turno.id, revisado: true }
    end

    private

    def gestiona? = %w[admin supervisor super_admin].include?(current_user.role)

    def con_turno
      turno = @mostrador.turno_abierto
      return render json: { error: 'El mostrador está cerrado' }, status: :unprocessable_entity if turno.nil?

      res = yield turno
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      render json: serialize_turno(turno.reload)
    end

    def set_mostrador
      sede       = current_user.club.sedes.find(params[:sede_id])
      @mostrador = sede.mostrador
      return if @mostrador

      render json: { error: 'Esta sede no dispensa: no tiene mostrador' }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Sede no encontrada' }, status: :not_found
    end

    # Quien atiende el mostrador lo abre y lo cierra. Que dependa del admin es lo que hace que
    # nadie lo use: a las 8 de la mañana o a las 11 de la noche puede no haber ninguno.
    def require_operador
      return if %w[admin supervisor dispensador super_admin].include?(current_user.role)

      render json: { error: 'No autorizado' }, status: :forbidden
    end

    # Un turno "con faltante" es uno donde se contó menos de lo esperado en algún producto. El
    # esperado se recalcula en SQL para no traer los ítems a Ruby: esto corre en cada carga de la
    # pantalla.
    def turnos_sin_revisar
      con_faltante = TurnoMostradorItem.where.not(cantidad_cierre: nil).where(
        'cantidad_cierre < cantidad_apertura + cantidad_repuesta - cantidad_devuelta ' \
        '+ cantidad_ajuste - cantidad_dispensada'
      ).select(:turno_mostrador_id)

      @mostrador.turno_mostradores.cerrados.where(revisado_at: nil, id: con_faltante).count
    end

    def mostradores_del_club
      current_user.club.mostradores.activos.includes(:sede).to_a.presence || [@mostrador]
    end

    def fondo_sugerido
      @mostrador.caja_turnos.cerradas.order(cerrada_at: :desc).first&.fondo_remanente_ars
    end

    # Con qué se abre: lo que quedó contado en el cierre anterior. Los stocks que desde entonces
    # se agotaron o se fueron de la sede no se ofrecen — se sugiere lo que todavía existe.
    def sugerido
      anterior = @mostrador.turno_mostradores.cerrados.order(cerrado_at: :desc).first
      return [] if anterior.nil?

      anterior.items.includes(:stock).filter_map do |it|
        next if it.cantidad_cierre.to_d <= 0
        next unless it.stock && it.stock.sede_id == @mostrador.sede_id

        serialize_stock(it.stock).merge(cantidad: it.cantidad_cierre.to_f)
      end
    end

    # Todo lo que se puede subir a la mesa: stock de esta sede habilitado para dispensa y con
    # algo libre. `cantidad_disponible_real` ya descuenta lo reservado a un paciente y lo
    # apartado a un evento: eso está en el mismo frasco pero no es del mostrador.
    def disponibles
      candidatos = current_user.club.stocks
                               .where(sede_id: @mostrador.sede_id, estado: 'asignado')
                               .para_dispensa.disponibles
                               .includes(:lote, :genetica).to_a
      Stock.precargar_apartado_mostrador(candidatos)
      candidatos.select { |s| s.cantidad_disponible_real.to_d.positive? }
    end

    # Dos señales, y la segunda es la que importa:
    #   reponer      → queda poco sobre la mesa, pero hay en el depósito. Es un recado.
    #   sin_repuesto → no queda arriba y TAMPOCO abajo. Eso no es reponer: el club se quedó sin
    #                  ese producto, y hoy no se lo dice nadie (`StockBajoJob` sólo mira el total
    #                  de flor seca por sede, así que un preroll que se acaba no lo dispara).
    #
    # El umbral es relativo a lo que se cargó, no un número configurable: un número inventado
    # antes de ver cómo trabajan es un aviso que después nadie mira.
    UMBRAL_REPONER = 0.25

    def senal(item)
      queda   = item.esperado.to_d
      cargado = item.cantidad_apertura.to_d + item.cantidad_repuesta.to_d
      poco    = cargado.positive? ? queda <= cargado * UMBRAL_REPONER : queda.zero?
      return nil unless poco
      return 'sin_repuesto' if item.stock&.cantidad_disponible_real.to_d <= 0

      'reponer'
    end

    def serialize_stock(stock)
      {
        stock_id:  stock.id,
        etiqueta:  stock.etiqueta,
        numero:    stock.numero_lote_producto,
        forma:     stock.forma_producto,
        unidad:    stock.unidad,
        lote:      stock.lote&.codigo,
        disponible: stock.cantidad_disponible_real.to_f,
      }
    end

    def serialize_turno(turno)
      return nil if turno.nil?

      {
        id:          turno.id,
        estado:      turno.estado,
        abierto_at:  turno.abierto_at,
        abierto_por: turno.abierto_por&.nombre_completo,
        # Lo mira la pantalla para no ofrecerle a quien cargó la mesa que se la reciba él mismo.
        abierto_por_id: turno.abierto_por_id,
        # Mientras esté en false, la pantalla pide la recepción y no deja atender.
        confirmado:     turno.confirmado?,
        confirmado_por: turno.confirmado_por&.nombre_completo,
        confirmado_at:  turno.confirmado_at,
        caja_turno_id: turno.caja_turno_id,
        # El arqueo de plata del mismo turno. Va acá para que el cierre muestre los dos juntos:
        # es un gesto, aunque sean dos cuentas distintas.
        caja: turno.caja_turno && {
          id:                 turno.caja_turno.id,
          fondo_ars:          turno.caja_turno.monto_inicial_ars.to_f,
          cobrado_efectivo_ars: turno.caja_turno.total_efectivo_ars,
          cobrado_digital_ars:  turno.caja_turno.total_digital_ars,
          salidas_ars:        turno.caja_turno.total_salidas_ars,
          esperado_ars:       turno.caja_turno.efectivo_esperado_ars,
        },
        # Lo que el que abrió corrigió sobre lo que dejó el turno anterior. Es la diferencia que
        # el admin mira después: nadie la tuvo que contar dos veces, pero si alguien la tocó,
        # está.
        hubo_correccion_apertura: turno.items.any? { |it| it.diferencia_apertura.to_d.nonzero? },
        items: turno.items.includes(:stock).map do |it|
          {
            id:        it.id,
            stock_id:  it.stock_id,
            etiqueta:  it.stock&.etiqueta,
            unidad:    it.stock&.unidad,
            heredada:  it.cantidad_heredada&.to_f,
            apertura:  it.cantidad_apertura.to_f,
            repuesta:  it.cantidad_repuesta.to_f,
            devuelta:  it.cantidad_devuelta.to_f,
            dispensada: it.cantidad_dispensada.to_f,
            # Lo que tiene que haber sobre la mesa ahora, y el techo de lo que se puede dispensar.
            esperado:  it.esperado.to_f,
            contado:   it.cantidad_cierre&.to_f,
            diferencia_apertura: it.diferencia_apertura&.to_f,
            # Lo que corrigió el que recibió, sobre lo que había declarado el admin.
            correccion: it.cantidad_ajuste.to_d.nonzero?&.to_f,
            # Las otras dos columnas de la pantalla: con qué reponer, y a qué ritmo se va.
            # `cantidad_disponible_real` ya descuenta lo que está sobre esta misma mesa.
            en_deposito: it.stock&.cantidad_disponible_real.to_f,
            senal:       senal(it),
            sin_supervision: it.movimientos.any?(&:sin_supervision),
          }
        end,
      }
    end
  end
end
