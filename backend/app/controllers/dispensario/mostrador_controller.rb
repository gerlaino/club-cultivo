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
        #
        # PERO al ABRIR, el que atiende sólo ve lo que heredó: abrir con un producto que no venía
        # es sacarlo del depósito, y eso lo hace quien responde por la mercadería. La regla la
        # aplica `AbrirTurno` — acá se recorta lo que se OFRECE para no invitarlo a llenar un
        # formulario que el backend va a rechazar.
        disponibles: (para_abrir_heredado? ? sugerido : disponibles.map { |s| serialize_stock(s) }),
        # Para que la pantalla lo explique en vez de mostrar una tabla corta sin decir por qué.
        apertura_heredada: para_abrir_heredado?,
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

    # GET /sedes/:sede_id/mostrador/turnos — los turnos cerrados.
    #
    # Administración los ve todos; el que atiende, LOS SUYOS. Cerraba un turno y no tenía dónde
    # mirarlo después: si al día siguiente le preguntan por una diferencia, no tiene con qué.
    def turnos
      escala = @mostrador.turno_mostradores.cerrados.includes(:cerrado_por, :confirmado_por)
      escala = escala.where(confirmado_por_id: current_user.id) unless gestiona?

      escala = escala.includes(:cerrado_por, :confirmado_por, :caja_turno, items: :stock)
      render json: {
        turnos: escala.order(cerrado_at: :desc).limit(30).map { |t| serialize_turno_resumen(t) },
        gestiona: gestiona?,
      }
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

    # El mostrador de UNA sede, y sólo si es una de las suyas.
    #
    # Sin el filtro por sedes asignadas, un dispensador de la Finca Norte abre, carga y cierra el
    # mostrador de Centro mandando otro `sede_id`: la pantalla no se lo ofrece, pero la pantalla
    # no es la regla. Es el mismo agujero que ya se había tapado en el listado de stock, y la
    # asignación de sedes existe justamente para esto.
    #
    # Quien no tiene ninguna asignada ve todas (organización de una sola sede, o un admin que no
    # se asignó ninguna): `sedes_visibles_ids` ya resuelve las dos.
    def set_mostrador
      sede       = current_user.club.sedes.where(id: current_user.sedes_visibles_ids)
                               .find(params[:sede_id])
      # `mostrador!` y no `mostrador`: acá SÍ corresponde crearlo — es la puerta de entrada al
      # mostrador de esa sede, y una organización que nunca lo abrió todavía no lo tiene.
      @mostrador = sede.mostrador!
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

    # Lo que el admin tiene que mirar. Son TRES cosas y no una: prometer una bandeja y contar
    # sólo los faltantes deja las otras dos invisibles apenas cierra el turno.
    #
    #   · un cierre con faltante
    #   · el que atiende corrigió lo que había declarado el admin
    #   · alguien bajó mercadería del depósito sin un admin al lado
    #
    # El esperado se recalcula en SQL para no traer los ítems a Ruby: esto corre en cada carga.
    def turnos_sin_revisar
      items = TurnoMostradorItem.where(turno_mostrador_id: turnos_cerrados_sin_revisar)

      con_faltante = items.where.not(cantidad_cierre: nil).where(
        'cantidad_cierre < cantidad_apertura + cantidad_repuesta - cantidad_devuelta ' \
        '+ cantidad_ajuste - cantidad_dispensada'
      ).select(:turno_mostrador_id)

      marcados = TurnoMostradorMovimiento
                 .where(turno_mostrador_item_id: items.select(:id))
                 .where("tipo = 'correccion' OR sin_supervision = TRUE")
                 .joins(:turno_mostrador_item).select('turno_mostrador_items.turno_mostrador_id')

      @mostrador.turno_mostradores.cerrados.where(revisado_at: nil)
                .where(id: con_faltante).or(
                  @mostrador.turno_mostradores.cerrados.where(revisado_at: nil).where(id: marcados)
                ).count
    end

    def turnos_cerrados_sin_revisar
      @mostrador.turno_mostradores.cerrados.where(revisado_at: nil).select(:id)
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

      # Se sugiere sobre `disponibles`, no sobre los stocks sueltos: la pantalla dibuja UNA fila
      # por producto disponible y le pone el número heredado. Si acá apareciera algo que no está
      # en esa lista —un frasco que desde anoche se agotó o se fue de la sede— su número se
      # cargaría sin fila donde verlo ni corregirlo, y el backend lo rechazaría al abrir.
      libres = disponibles.index_by(&:id)

      anterior.items.en_la_mesa.filter_map do |it|
        next if it.cantidad_cierre.to_d <= 0

        stock = libres[it.stock_id]
        next if stock.nil?

        # Y se ofrece como mucho lo que quedó libre: si anoche cerró con 20 y hoy hay 12, sugerir
        # 20 es proponer algo que no se puede cumplir.
        cantidad = [it.cantidad_cierre.to_d, stock.cantidad_disponible_real.to_d].min
        serialize_stock(stock).merge(cantidad: cantidad.to_f)
      end
    end

    # Todo lo que se puede subir a la mesa: stock de esta sede habilitado para dispensa y con
    # algo libre. `cantidad_disponible_real` ya descuenta lo reservado a un paciente y lo
    # apartado a un evento: eso está en el mismo frasco pero no es del mostrador.
    # ¿A esta persona, con el mostrador cerrado, se le ofrece sólo lo del turno anterior?
    # Administración carga lo que quiera; el que atiende hereda. Con el turno YA abierto la
    # respuesta es no: ahí baja del depósito por la puerta que deja rastro (`sin_supervision`).
    def para_abrir_heredado?
      @mostrador.turno_abierto.nil? && current_user.atiende_mostrador?
    end

    def disponibles
      @disponibles ||= calcular_disponibles
    end

    def calcular_disponibles
      candidatos = current_user.club.stocks
                               .where(sede_id: @mostrador.sede_id, estado: 'asignado')
                               .para_dispensa.disponibles
                               .includes(:lote, :genetica).to_a
      Stock.precargar_apartados(candidatos)
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

    # Lo que hace falta para DECIDIR qué baja a la mesa, no sólo para identificarlo. Es la misma
    # información que muestra el carrito de dispensa (`ModalNuevaDispensacion`): armar la mesa y
    # dispensar de ella son la misma pregunta —qué hay, de qué lote, de cuándo y a cuánto— y
    # contestarla con dos tablas distintas es cómo empiezan a contradecirse.
    def serialize_stock(stock)
      {
        stock_id:  stock.id,
        etiqueta:  stock.etiqueta,
        numero:    stock.numero_lote_producto,
        forma:     stock.forma_producto,
        unidad:    stock.unidad,
        lote:      stock.lote&.codigo,
        genetica:  stock.genetica&.nombre || stock.lote&.genetica&.nombre,
        # Lo viejo sale primero: sin la fecha, el que arma la mesa no tiene con qué decidirlo.
        fecha:     stock.fecha_elaboracion || stock.created_at&.to_date,
        precio_ars: stock.precio_sugerido_ars&.to_f,
        # Sólo para quien responde por la mercadería: cuánto vale lo que se pone sobre la mesa.
        costo_ars:  (stock.costo_unitario_ars&.to_f if gestiona?),
        disponible: stock.cantidad_disponible_real.to_f,
      }
    end

    # La lista de turnos cerrados. NO usa `serialize_turno`: ése arma la mesa entera producto por
    # producto y pregunta el depósito de cada uno —treinta turnos serían cientos de queries para
    # pintar una lista donde no se ve ni un solo producto—. Acá van los totales, y el detalle se
    # abre al entrar a uno.
    def serialize_turno_resumen(turno)
      items = turno.items.select { |it| it.en_la_mesa? }
      con_dif = items.count { |it| it.diferencia_cierre.to_d.nonzero? }
      {
        id:          turno.id,
        abierto_at:  turno.abierto_at,
        cerrado_at:  turno.cerrado_at,
        cerrado_por: turno.cerrado_por&.nombre_completo,
        atendio:     turno.confirmado_por&.nombre_completo,
        revisado:    turno.revisado_at.present?,
        productos:   items.size,
        dispensado:  items.sum { |it| it.cantidad_dispensada.to_d }.to_f.round(2),
        # Lo que faltó, en producto y en plata. En gramos no se compara con nada.
        faltante:    items.sum { |it| [-it.diferencia_cierre.to_d, 0].max }.to_f.round(2),
        faltante_ars: items.sum { |it|
          [-it.diferencia_cierre.to_d, 0].max * it.stock&.costo_unitario_ars.to_d
        }.to_f.round(2),
        con_diferencia: con_dif,
        # El arqueo de plata del mismo turno, sin abrirlo.
        efectivo_contado_ars: turno.caja_turno&.efectivo_declarado_ars&.to_f,
        diferencia_caja_ars:  turno.caja_turno&.diferencia_ars&.to_f,
      }
    end

    def serialize_turno(turno)
      return nil if turno.nil?

      {
        id:          turno.id,
        estado:      turno.estado,
        abierto_at:  turno.abierto_at,
        cerrado_at:  turno.cerrado_at,
        cerrado_por: turno.cerrado_por&.nombre_completo,
        revisado:    turno.revisado_at.present?,
        abierto_por: turno.abierto_por&.nombre_completo,
        # Lo mira la pantalla para no ofrecerle a quien cargó la mesa que se la reciba él mismo.
        abierto_por_id: turno.abierto_por_id,
        # Mientras esté en false, la pantalla pide la recepción y no deja atender.
        confirmado:     turno.confirmado?,
        confirmado_por: turno.confirmado_por&.nombre_completo,
        confirmado_at:  turno.confirmado_at,
        caja_turno_id: turno.caja_turno_id,
        # Cuánto vale lo que hay arriba, a costo. En gramos no se compara con nada: en plata se
        # ve de un vistazo que sobre esa mesa hay medio sueldo.
        valor_mesa_ars: turno.items.en_la_mesa.includes(:stock).sum { |it| it.esperado * it.stock&.costo_unitario_ars.to_d }.to_f.round(2),
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
        hubo_correccion_apertura: turno.items.en_la_mesa.any? { |it| it.diferencia_apertura.to_d.nonzero? },
        items: turno.items.en_la_mesa.includes(:stock).map do |it|
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
            diferencia_cierre:   it.diferencia_cierre&.to_f,
            motivo:              it.motivo_diferencia,
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
