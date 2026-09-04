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
    # Lo que hay sobre la mesa —que existe con la caja abierta y con la caja cerrada—, el turno
    # de caja si hay alguien atendiendo, y todo lo que se puede subir desde el depósito
    # (`disponibles`).
    def actual
      turno = @mostrador.turno_abierto
      render json: {
        mostrador:   { id: @mostrador.id, nombre: @mostrador.nombre,
                       sede: { id: @mostrador.sede_id, nombre: @mostrador.sede&.nombre } },
        # LO QUE HAY SOBRE LA MESA. Es el estado permanente del mostrador, no del turno: existe
        # con la caja abierta y con la caja cerrada, porque el producto está físicamente ahí.
        mesa:        mesa.map { |mi| serialize_item(mi) },
        # El turno de caja, si hay uno abierto. Nil = nadie está atendiendo, y eso NO significa
        # que la mesa esté vacía.
        turno:       serialize_turno(turno),
        # Quién puede hacer qué, resuelto por el backend: la pantalla no tiene que deducirlo de
        # tres campos ni repetir la matriz de permisos.
        puedo:       { cargar: gestiona?, abrir: true, cerrar: turno.present? },
        # Turnos cerrados con algo para mirar. Viaja en la carga principal a propósito: un aviso
        # que sólo aparece cuando ya entraste a mirarlo no avisa nada.
        sin_revisar: gestiona? ? turnos_sin_revisar : 0,
        # Con cuánto arrancaría la caja: lo que quedó del turno anterior. Heredado, no declarado.
        fondo_sugerido: turno ? nil : fondo_sugerido,
        # Todo lo que se puede subir a la mesa desde el depósito de esta sede.
        disponibles: disponibles.map { |s| serialize_stock(s) },
      }
    end

    # POST /sedes/:sede_id/mostrador/cargar { cambios: [{ stock_id, cantidad }], motivo }
    #
    # El admin dice cuánto tiene que haber de cada producto sobre la mesa. `cantidad` es el TOTAL,
    # no el delta: la pantalla es una tabla donde se escribe cuánto hay, y pedirle al usuario que
    # calcule la diferencia sería pedirle la cuenta que hace la máquina.
    def cargar
      return render json: { error: 'La mesa la carga administración' }, status: :forbidden unless gestiona?

      res = Mostradores::Cargar.call(mostrador: @mostrador, usuario: current_user,
                                     cambios: params[:cambios] || [], motivo: params[:motivo])
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      actual
    end

    # POST /sedes/:sede_id/mostrador/abrir { conteos: [{ stock_id, contado }], efectivo_contado_ars }
    #
    # Quien atiende pesa lo que hay, cuenta la plata y arranca. Si no coincide NO se lo bloquea:
    # pone lo que contó y abre, y la diferencia queda anotada para el admin.
    def abrir
      res = Mostradores::AbrirCaja.call(
        mostrador: @mostrador, usuario: current_user,
        conteos: params[:conteos] || [], efectivo_contado_ars: params[:efectivo_contado_ars],
        notas: params[:notas]
      )
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      render json: serialize_turno(res.turno), status: :created
    end

    # POST /sedes/:sede_id/mostrador/cerrar
    #   { conteos: [{ stock_id, contado }], efectivo_contado_ars, fondo_siguiente_ars, notas }
    def cerrar
      turno = @mostrador.turno_abierto
      return render json: { error: 'La caja del mostrador no está abierta' }, status: :unprocessable_entity if turno.nil?

      res = Mostradores::CerrarCaja.call(
        turno: turno, usuario: current_user, conteos: params[:conteos] || [],
        efectivo_contado_ars: params[:efectivo_contado_ars],
        fondo_siguiente_ars:  params[:fondo_siguiente_ars],
        # El retiro de la recaudación queda a nombre de quien responde por ella. Si cierra quien
        # atiende y no hay a quién atribuirlo, se deja todo como fondo.
        retirado_por: (current_user if MovimientoContable::ROLES_RETIRO.include?(current_user.role)),
        notas: params[:notas]
      )
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      render json: serialize_turno(res.turno)
    end

    # POST /sedes/:sede_id/mostrador/contar { stock_id, contado, motivo }
    #
    # Contar UN producto sin cerrar la caja. Cerrar y reabrir es el arqueo completo, pero con
    # quince frascos son veinte minutos: el control que cuesta eso no se hace, y el que no se
    # hace no controla nada.
    def contar
      res = Mostradores::Contar.call(mostrador: @mostrador, usuario: current_user,
                                     stock_id: params[:stock_id], contado: params[:contado],
                                     motivo: params[:motivo])
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      actual
    end

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
      escala = @mostrador.turno_mostradores.cerrados
      # Quien ATENDIÓ es quien abrió la caja contando: ése es su turno. Los de los demás no son
      # asunto suyo, y el filtro es del backend — la pantalla no es la regla.
      escala = escala.where(abierto_por_id: current_user.id) unless gestiona?

      escala = escala.includes(:cerrado_por, :abierto_por, :caja_turno, items: :stock)
                     .order(cerrado_at: :desc)

      # DESCARGA: el historial de arqueos es lo que se le muestra a un contador o a un socio, y
      # eso no se hace leyendo una pantalla. Sin tope de páginas: se baja todo lo que haya.
      return enviar_csv(escala) if params[:formato] == 'csv'

      total  = escala.count
      por    = (params[:por].presence || 20).to_i.clamp(1, 100)
      pagina = [params[:pagina].to_i, 1].max

      render json: {
        turnos:   escala.offset((pagina - 1) * por).limit(por).map { |t| serialize_turno_resumen(t) },
        gestiona: gestiona?,
        # Paginado en el backend y no cortando en el front: un mostrador con un año de arqueos son
        # cientos de turnos, y traerlos todos para mostrar veinte es hacer esperar a alguien que
        # está atendiendo.
        pagina:   pagina,
        paginas:  [(total / por.to_f).ceil, 1].max,
        total:    total,
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

    # Lo que hay sobre la mesa, con lo que hace falta para decidir y para contar.
    def mesa
      @mesa ||= begin
        items = @mostrador.sobre_la_mesa.to_a
        Stock.precargar_apartados(items.map(&:stock).compact)
        items
      end
    end

    def serialize_item(mi)
      st = mi.stock
      serialize_stock(st).merge(
        item_id:  mi.id,
        # Lo que hay sobre la mesa AHORA. Es contra esto que se cuenta al abrir y al cerrar.
        mostrador: mi.cantidad.to_f,
        senal:     senal(mi),
        # Lo que pasó con este producto mientras la caja estuvo abierta: si el admin le sacó 200 g
        # a las 15:40, quien atiende lo tiene que ver o cierra con un faltante que no es suyo.
        movimientos_del_turno: movimientos_del_turno[mi.id]&.map { |m| serialize_movimiento(m) } || []
      )
    end

    def movimientos_del_turno
      @movimientos_del_turno ||= begin
        turno = @mostrador.turno_abierto
        if turno.nil?
          {}
        else
          MostradorMovimiento.where(turno_mostrador_id: turno.id, tipo: %w[carga retiro ajuste])
                             .includes(:usuario).recientes.group_by(&:mostrador_item_id)
        end
      end
    end

    def serialize_movimiento(m)
      { tipo: m.tipo, cantidad: m.cantidad.to_f, motivo: m.motivo,
        usuario: m.usuario&.nombre_completo, cuando: m.created_at }
    end

    # El producto se contó y no está: el inventario tiene que reflejarlo. `ajuste` con motivo,
    # NUNCA `merma` — el informe de Pérdidas cuenta merma y esto puede estar entero.
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

    # El badge de la solapa Merma. Las razones viven en `Mostradores::MotivosDeRevision` — acá NO
    # se decide qué cuenta como pendiente, sólo se cuenta.
    def turnos_sin_revisar
      candidatos = @mostrador.turno_mostradores.cerrados.where(revisado_at: nil)
      Mostradores::MotivosDeRevision.por_turno(candidatos).size
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

    # Todo lo que se puede subir a la mesa: stock de esta sede habilitado para dispensa y con
    # algo libre. `cantidad_disponible_real` ya descuenta lo reservado a un paciente y lo
    # apartado a un evento: eso está en el mismo frasco pero no es del mostrador.
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

    # Se está por acabar. Se compara contra lo que se cargó en el turno —no contra un número
    # fijo— porque 20 g quedando de 500 es distinto de 20 quedando de 25.
    def senal(mi)
      queda   = mi.cantidad.to_d
      cargado = cargado_en_el_turno(mi)
      poco    = cargado.positive? ? queda <= cargado * UMBRAL_REPONER : queda.zero?
      return nil unless poco
      return 'sin_repuesto' if mi.stock&.cantidad_disponible_real.to_d <= 0

      'reponer'
    end

    # Cuánto llegó a haber de este producto durante el turno abierto: lo que se contó al abrir más
    # lo que el admin subió después.
    def cargado_en_el_turno(mi)
      turno = @mostrador.turno_abierto
      return mi.cantidad.to_d if turno.nil?

      apertura = turno.items.detect { |i| i.stock_id == mi.stock_id }&.cantidad_apertura.to_d
      subido   = (movimientos_del_turno[mi.id] || []).select { |m| m.cantidad.to_d.positive? }
                                                     .sum { |m| m.cantidad.to_d }
      apertura + subido
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
    # EL HISTORIAL DE ARQUEOS, PARA LLEVÁRSELO.
    #
    # Una fila por turno con lo mismo que muestra la pantalla: cuándo, quién, cuánto se entregó,
    # qué faltó y cómo cerró la caja. Es lo que se le pasa al contador o se archiva, y eso no se
    # hace copiando de una tabla en el navegador.
    def enviar_csv(escala)
      require 'csv'
      filas = CSV.generate(col_sep: ';', encoding: 'UTF-8') do |csv|
        csv << ['Fecha', 'Abrió', 'Cerró', 'Atendió', 'Cerrado por', 'Productos',
                'Entregado', 'Faltó', 'Faltó ($)', 'Efectivo contado ($)', 'Diferencia caja ($)',
                'Revisado']
        escala.each do |t|
          r = serialize_turno_resumen(t)
          csv << [
            t.cerrado_at&.to_date, hora_corta(t.abierto_at), hora_corta(t.cerrado_at),
            r[:atendio], r[:cerrado_por], r[:productos], r[:dispensado], r[:faltante],
            r[:faltante_ars], r[:efectivo_contado_ars], r[:diferencia_caja_ars],
            r[:revisado] ? 'sí' : 'no',
          ]
        end
      end

      send_data "﻿#{filas}", type: 'text/csv; charset=utf-8',
                filename: "arqueos-#{@mostrador.sede&.nombre.to_s.parameterize}-#{Time.zone.today}.csv"
    end

    def hora_corta(t) = t&.in_time_zone&.strftime('%H:%M')

    def serialize_turno_resumen(turno)
      items   = turno.items.to_a
      con_dif = items.count { |it| it.diferencia_cierre.to_d.nonzero? }
      {
        id:          turno.id,
        abierto_at:  turno.abierto_at,
        cerrado_at:  turno.cerrado_at,
        cerrado_por: turno.cerrado_por&.nombre_completo,
        atendio:     turno.abierto_por&.nombre_completo,
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

    # EL TURNO: quién abrió, con qué contó, y cómo va la caja. La mercadería ya NO vive acá —es
    # del mostrador— así que esto se quedó con lo suyo: el arqueo.
    def serialize_turno(turno)
      return nil if turno.nil?

      {
        id:          turno.id,
        estado:      turno.estado,
        abierto_at:  turno.abierto_at,
        abierto_por: turno.abierto_por&.nombre_completo,
        abierto_por_id: turno.abierto_por_id,
        cerrado_at:  turno.cerrado_at,
        cerrado_por: turno.cerrado_por&.nombre_completo,
        revisado:    turno.revisado_at.present?,
        notas_apertura: turno.notas_apertura,
        notas_cierre:   turno.notas_cierre,
        caja_turno_id:  turno.caja_turno_id,
        # Cuánto vale lo que hay sobre la mesa, a costo. En gramos no se compara con nada; en
        # plata se ve de un vistazo que ahí arriba hay medio sueldo. Sólo para quien responde.
        valor_mesa_ars: (gestiona? ? valor_de_la_mesa : nil),
        # El arqueo de plata. Va con el turno para que el cierre muestre los dos juntos: es un
        # gesto, aunque sean dos cuentas distintas.
        caja: turno.caja_turno && {
          id:                   turno.caja_turno.id,
          fondo_ars:            turno.caja_turno.monto_inicial_ars.to_f,
          cobrado_efectivo_ars: turno.caja_turno.total_efectivo_ars,
          cobrado_digital_ars:  turno.caja_turno.total_digital_ars,
          # Plata que entró en efectivo sin ser una dispensa: pagó una deuda, señó una reserva.
          # Aparte de lo cobrado, para que una diferencia se pueda explicar por su origen.
          otros_ingresos_efectivo_ars: turno.caja_turno.total_otros_ingresos_efectivo_ars,
          salidas_ars:          turno.caja_turno.total_salidas_ars,
          esperado_ars:         turno.caja_turno.efectivo_esperado_ars,
          contado_ars:          turno.caja_turno.efectivo_declarado_ars&.to_f,
          diferencia_ars:       turno.caja_turno.diferencia_ars,
        },
        # Lo que se contó al abrir contra lo que decía el sistema. Es lo que el admin mira
        # después: si el que abrió corrigió algo, está.
        conteo_apertura: turno.items.includes(:stock).map do |it|
          {
            stock_id: it.stock_id, etiqueta: it.stock&.etiqueta, unidad: it.stock&.unidad,
            esperado: it.esperado_apertura&.to_f, contado: it.cantidad_apertura.to_f,
            diferencia: it.esperado_apertura ? (it.cantidad_apertura.to_d - it.esperado_apertura.to_d).to_f : nil,
            dispensada: it.cantidad_dispensada.to_f,
            esperado_cierre: it.esperado_cierre&.to_f,
            contado_cierre:  it.cantidad_cierre&.to_f,
          }
        end,
      }
    end

    def valor_de_la_mesa
      mesa.sum { |mi| mi.cantidad.to_d * mi.stock&.costo_unitario_ars.to_d }.to_f.round(2)
    end

  end
end
