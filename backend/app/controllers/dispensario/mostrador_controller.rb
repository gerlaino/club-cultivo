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
    before_action :set_mostrador, except: [:resumen]
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

    # GET /mostradores — el estado de CADA mostrador del club, para elegir a cuál entrar.
    #
    # Sin esto, elegir sede es un desplegable de nombres: hay que entrar a cada una para saber si
    # alguien está atendiendo. Con el estado al lado, la pantalla de elección es además el
    # pantallazo del día — que es lo que administración viene a buscar.
    #
    # Sólo las sedes que ATIENDEN (`social`/`mixta`) y sólo las visibles para esta persona: un
    # dispensador de Norte no monitorea Centro.
    def resumen
      sedes = current_user.club.sedes
                          .where(id: current_user.sedes_visibles_ids, tipo: %w[social mixta])
                          .order(:nombre)

      # `mostrador` y no `mostrador!`: un GET que escribe en la base es una sorpresa que se paga
      # cara, y una sede que nunca abrió su mostrador simplemente no tiene fila todavía.
      render json: { mostradores: sedes.map { |sede| resumen_de(sede) } }
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

    # GET /sedes/:sede_id/mostrador/evolucion?desde=&hasta=
    #
    # LO QUE TENÍA QUE HABER CONTRA LO QUE SE CONTÓ, día por día y PRODUCTO POR PRODUCTO.
    #
    # Por producto y no en total, que era la idea de Germán y resuelve el problema de fondo: en un
    # total hay que sumar gramos de flor con unidades de preroll, y eso da un número que no
    # significa nada. Por producto no hay nada que sumar — cada uno en su unidad.
    #
    # Y cada uno con SU escala en la pantalla: así se ve igual de bien el desplome de 23 g de un
    # día y el gramo que gotea todos los días, que es el que sangra sin disparar ninguna alarma y
    # el que un eje compartido esconde.
    #
    # Se cuenta por STOCK y no por genética: dos frascos de la misma variedad son dos conteos, y
    # sumarlos perdería la trazabilidad lote→dispensación.
    def evolucion
      return render json: { error: 'No autorizado' }, status: :forbidden unless gestiona?

      desde = params[:desde].presence&.to_date || Time.zone.today.beginning_of_month
      hasta = params[:hasta].presence&.to_date || Time.zone.today

      items = TurnoMostradorItem
              .joins(:turno_mostrador).includes(:stock)
              .where(turno_mostradores: { mostrador_id: @mostrador.id })
              .where.not(turno_mostradores: { cerrado_at: nil })
              .where(turno_mostradores: { cerrado_at: desde.beginning_of_day..hasta.end_of_day })
              .where.not(esperado_cierre: nil).where.not(cantidad_cierre: nil)

      render json: { desde: desde, hasta: hasta, productos: evolucion_por_producto(items) }
    rescue ArgumentError, Date::Error
      render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
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

    # POST /sedes/:sede_id/mostrador/reponer — { stock_id }
    #
    # QUIEN ATIENDE PIDE, ADMINISTRACIÓN REPONE.
    #
    # Él no ve el depósito —no es asunto suyo cuánto hay guardado— pero sí necesita decir "se me
    # está acabando esto". Antes la única forma era verlo en su pantalla de Stock y avisar por
    # fuera de la app; ahora es un botón, y el pedido llega a la campana y al celular de quien
    # puede hacer algo.
    #
    # NO ELIGE CUÁNTO ni de dónde: eso lo decide administración, que es la que gobierna la mesa.
    #
    # UNO POR PRODUCTO Y POR DÍA. Un botón que se puede apretar diez veces llena la campana de
    # avisos iguales, y eso es cómo se aprende a ignorarla.
    def reponer
      stock = @mostrador.club.stocks.find_by(id: params[:stock_id])
      return render json: { error: 'Ese producto no existe' }, status: :not_found if stock.nil?

      if pedidos_de_reposicion_de_hoy.include?(stock.id)
        return render json: { ok: true, ya_pedido: true }
      end

      quien  = current_user.nombre_completo
      donde  = @mostrador.sede&.nombre
      texto  = "#{quien} pide reponer #{stock.etiqueta} en el mostrador de #{donde}."

      # Una sola fila: el admin ve TODAS las alertas de su organización (`scoped_alertas`) y el
      # supervisor sólo las suyas, así que marcada para supervisor le llega a los dos. Dos filas
      # le mostrarían el mismo pedido dos veces al admin.
      AlertaInterna.create!(
        club: @mostrador.club, tipo: 'reposicion_mostrador', mensaje: texto, severidad: 'info',
        destinada_a_role: 'supervisor',
        contexto: { stock_id: stock.id, sede_id: @mostrador.sede_id, sede_nombre: donde,
                    pedido_por: quien, pedido_por_id: current_user.id }
      )
      PushNotificationService.notify_roles_async(
        @mostrador.club, 'admin', 'supervisor',
        title: 'Reponer en el mostrador', body: texto,
        url: "/mostrador?sede=#{@mostrador.sede_id}"
      )

      render json: { ok: true, stock_id: stock.id }
    end

    # GET /sedes/:sede_id/mostrador/turnos — los turnos cerrados.
    #
    # Administración los ve todos; el que atiende, LOS SUYOS. Cerraba un turno y no tenía dónde
    # mirarlo después: si al día siguiente le preguntan por una diferencia, no tiene con qué.
    def turnos
      escala = @mostrador.turno_mostradores.cerrados
      # QUIEN ATENDIÓ ES EL QUE ABRIÓ **O** EL QUE CERRÓ, no sólo el que abrió. La caja es del
      # mostrador y no de una persona: es normal que la abra el admin a la mañana y la cierre
      # contando quien atendió todo el día. Con el filtro sólo por `abierto_por_id`, ése cerraba
      # su turno y la pantalla le decía "todavía no cerraste ningún turno acá" — justo lo que
      # necesita si al día siguiente le preguntan por una diferencia que él anotó.
      unless gestiona?
        escala = escala.where('abierto_por_id = :id OR cerrado_por_id = :id', id: current_user.id)
      end

      escala = escala.includes(:cerrado_por, :abierto_por, :caja_turno, items: :stock)
                     .order(cerrado_at: :desc)

      # LA LISTA DE TRABAJO VIVE ACÁ, no en otra solapa.
      #
      # «Para mirar» era esta misma lista, filtrada, viviendo en Merma con otro nombre: dos listas
      # de cierres en dos lugares, y la que decía qué hacer estaba en la solapa de análisis. Acá
      # es un filtro, que es lo que siempre fue.
      escala = escala.where(revisado_at: nil).where(id: turnos_que_piden_mirada) if params[:sin_revisar].present?

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
        # Cuántos piden una mirada, para que el filtro pueda decirlo sin pedir otra vuelta.
        sin_revisar: gestiona? ? turnos_sin_revisar : 0,
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
                                             conteos: params[:conteos] || [], motivo: params[:motivo],
                                             efectivo_contado_ars: params[:efectivo_contado_ars])
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
    # Los ids de los cierres que piden una mirada. Sale del MISMO servicio que el badge y que la
    # solapa de merma: si el filtro decidiera por su cuenta qué cuenta como "para mirar", un día
    # el badge diría 2 y la lista mostraría otra cosa.
    def turnos_que_piden_mirada
      candidatos = @mostrador.turno_mostradores.cerrados.where(revisado_at: nil)
      Mostradores::MotivosDeRevision.por_turno(candidatos).keys
    end

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
        # Lo que se anotó al cargar el producto: es donde se distingue un frasco de otro que en
        # una tabla se ven en todo iguales. Lo necesita la lista de reservar, que ahora se arma
        # con la mesa, y no le sobra a la del mostrador.
        descripcion: stock.descripcion,
        # CUÁNTO DE ESTE PRODUCTO YA TIENE DUEÑO. La reserva la hace administración y el producto
        # se enfrasca recién al entregar: hasta entonces sigue arriba, mezclado con lo que se
        # puede vender. Sin decirlo, la mesa dice 110 y sólo 95 se pueden entregar.
        #
        # Va en `serialize_stock` y no en `serialize_item` porque lo necesitan LAS DOS listas: la
        # mesa y lo que se puede subir del depósito — bajar la mesa por debajo de lo reservado es
        # justo lo que hay que poder ver antes de hacerlo.
        reservado: stock.apartado_para_reservas.to_f,
        lote:      stock.lote&.codigo,
        genetica:  stock.genetica&.nombre || stock.lote&.genetica&.nombre,
        # Lo viejo sale primero: sin la fecha, el que arma la mesa no tiene con qué decidirlo.
        fecha:     stock.fecha_elaboracion || stock.created_at&.to_date,
        precio_ars: stock.precio_sugerido_ars&.to_f,
        # Sólo para quien responde por la mercadería: cuánto vale lo que se pone sobre la mesa,
        # y cuánto hay guardado en el depósito.
        costo_ars:  (stock.costo_unitario_ars&.to_f if gestiona?),
        disponible: (stock.cantidad_disponible_real.to_f if gestiona?),
        # A quien atiende no le decimos CUÁNTO hay guardado —no es asunto suyo— pero sí si queda
        # algo, que es lo único que necesita para saber si tiene sentido pedir reposición. Pedir
        # lo que no hay es hacerle perder el viaje a los dos.
        hay_en_deposito:   stock.cantidad_disponible_real.to_d.positive?,
        reposicion_pedida: pedidos_de_reposicion_de_hoy.include?(stock.id),
      }
    end

    # Los pedidos de reposición de HOY, en una query para toda la mesa: preguntarlo producto por
    # producto serían quince consultas para pintar una pantalla.
    def pedidos_de_reposicion_de_hoy
      @pedidos_de_reposicion_de_hoy ||=
        AlertaInterna.where(club_id: @mostrador.club_id, tipo: 'reposicion_mostrador')
                     .where('created_at >= ?', Time.zone.now.beginning_of_day)
                     .where("contexto->>'sede_id' = ?", @mostrador.sede_id.to_s)
                     .pluck(Arel.sql("contexto->>'stock_id'")).compact.map(&:to_i).to_set
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
        # El CSV sí lleva las cantidades además de los pesos: lo abre alguien que va a analizar,
        # no a leer de un vistazo, y ahí el detalle sirve. La PANTALLA muestra sólo los pesos,
        # porque sumar gramos con unidades da un número que no significa nada.
        csv << ['Fecha', 'Abrió', 'Cerró', 'Atendió', 'Cerrado por', 'Productos',
                'Entregado', 'Entregado ($)', 'Faltó', 'Faltó ($)', 'Productos con faltante',
                'Efectivo contado ($)', 'Diferencia caja ($)', 'Revisado']
        escala.each do |t|
          r = serialize_turno_resumen(t)
          csv << [
            t.cerrado_at&.to_date, hora_corta(t.abierto_at), hora_corta(t.cerrado_at),
            r[:atendio], r[:cerrado_por], r[:productos], r[:dispensado], r[:dispensado_ars],
            r[:faltante], r[:faltante_ars], r[:productos_con_faltante],
            r[:efectivo_contado_ars], r[:diferencia_caja_ars],
            r[:revisado] ? 'sí' : 'no',
          ]
        end
      end

      send_data "﻿#{filas}", type: 'text/csv; charset=utf-8',
                filename: "arqueos-#{@mostrador.sede&.nombre.to_s.parameterize}-#{Time.zone.today}.csv"
    end

    def resumen_de(sede)
      most  = sede.mostrador
      items = most ? most.sobre_la_mesa.to_a : []
      turno = most&.turno_abierto

      {
        sede_id: sede.id,
        sede:    sede.nombre,
        # Cuánto hay arriba, POR UNIDAD: sumar 300 g de flor con 12 prerolls da 312 de nada.
        productos: items.size,
        totales:   items.group_by { |i| i.stock&.unidad || 'g' }
                        .map { |u, is| { unidad: u, cantidad: is.sum { |i| i.cantidad.to_f } } },
        # Si hay alguien atendiendo, quién y desde cuándo. Nil = nadie, y eso NO significa que la
        # mesa esté vacía.
        turno: turno && { desde: turno.abierto_at, quien: turno.abierto_por&.nombre_completo },
        # Cierres que piden una mirada en ESA sede. Es media razón para entrar.
        sin_revisar: gestiona? && most ? Mostradores::MotivosDeRevision.por_turno(
          most.turno_mostradores.cerrados.where(revisado_at: nil)
        ).size : 0,
      }
    end

    # UN PRODUCTO POR SERIE, con sus puntos ordenados en el tiempo.
    #
    # Con varios cierres en el mismo día se toma EL ÚLTIMO: el gráfico es «cómo terminó cada día»,
    # y dos puntos en la misma fecha se pisarían en el eje.
    #
    # Ordenados por lo que costó lo que falta, no por gramos: lo que más pesa no es lo que más
    # duele. Los que nunca tuvieron diferencia viajan igual, marcados, para que la pantalla los
    # pliegue — esconderlos del payload obligaría a otra consulta para poder desplegarlos.
    def evolucion_por_producto(items)
      items.group_by(&:stock_id).map { |_sid, del_stock|
        stock  = del_stock.first.stock
        puntos = del_stock.group_by { |it| it.turno_mostrador.cerrado_at.in_time_zone.to_date }
                          .map { |dia, dels|
                            ult = dels.max_by { |it| it.turno_mostrador.cerrado_at }
                            { fecha: dia, esperado: ult.esperado_cierre.to_f,
                              contado: ult.cantidad_cierre.to_f }
                          }.sort_by { |p| p[:fecha] }

        falta = puntos.sum { |p| [p[:esperado] - p[:contado], 0].max }
        {
          stock_id: stock&.id,
          etiqueta: stock&.etiqueta,
          unidad:   stock&.unidad || 'g',
          puntos:   puntos,
          falta:    falta.round(2),
          falta_ars: (falta.to_d * stock&.costo_unitario_ars.to_d).to_f.round(2),
          # El peor día, para poder titular la ficha sin que la pantalla lo recalcule.
          peor: puntos.max_by { |p| p[:esperado] - p[:contado] }&.then { |p|
            d = (p[:esperado] - p[:contado]).round(2)
            d.positive? ? { fecha: p[:fecha], falta: d } : nil
          },
          sin_diferencias: falta.zero?,
        }
      }.sort_by { |p| [p[:sin_diferencias] ? 1 : 0, -p[:falta_ars]] }
    end

    # LOS PRODUCTOS EN LOS QUE HUBO DIFERENCIA, con nombre y con plata.
    #
    # Ordenados por lo que costaron, no por gramos: lo que más pesa no es lo que más duele.
    # Se cortan en tres — la fila es una oración, no un listado — y el resto viaja como número
    # para poder decir «y 2 más».
    TOPE_DETALLE = 3

    def detalle_diferencias(items, lado)
      con_dif = items.select do |it|
        d = it.diferencia_cierre.to_d
        lado == :falta ? d.negative? : d.positive?
      end
      filas = con_dif.map do |it|
        cant = it.diferencia_cierre.to_d.abs
        {
          etiqueta: it.stock&.etiqueta,
          cantidad: cant.to_f.round(2),
          unidad:   it.stock&.unidad || 'g',
          # Lo que costó producirlo. En la pantalla se dice así, no «a costo».
          ars:      (cant * it.stock&.costo_unitario_ars.to_d).to_f.round(2),
          # Contra qué se compara, que es lo que hoy no se ve en ningún lado.
          esperado: it.esperado_cierre&.to_f,
          contado:  it.cantidad_cierre&.to_f,
        }
      end.sort_by { |x| -x[:ars] }

      { items: filas.first(TOPE_DETALLE), total: filas.size,
        cantidad: filas.sum { |x| x[:cantidad] }.round(2),
        ars: filas.sum { |x| x[:ars] }.round(2) }
    end

    # Una consulta para toda la página, no una por fila.
    def motivos_de_revision
      @motivos_de_revision ||=
        Mostradores::MotivosDeRevision.por_turno(@mostrador.turno_mostradores.cerrados.where(revisado_at: nil))
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
        # POR QUÉ ESTE CIERRE PIDE UNA MIRADA. Un renglón que no lo dice obliga a abrirlo para
        # descubrir que no era nada. Viene del mismo servicio que el badge y que la merma.
        motivos_revision: motivos_de_revision[turno.id] || [],
        productos:   items.size,
        dispensado:  items.sum { |it| it.cantidad_dispensada.to_d }.to_f.round(2),
        # EN PLATA, porque en cantidad no se compara con nada: sumar gramos de flor con unidades
        # de preroll da un número que no significa nada ("23" era 23 g más 4 prerolls). La tabla
        # de turnos muestra los pesos, que sí se suman y se comparan entre turnos.
        dispensado_ars: items.sum { |it|
          it.cantidad_dispensada.to_d * it.stock&.precio_sugerido_ars.to_d
        }.to_f.round(2),
        # Lo que faltó, en producto y en plata.
        faltante:    items.sum { |it| [-it.diferencia_cierre.to_d, 0].max }.to_f.round(2),
        faltante_ars: items.sum { |it|
          [-it.diferencia_cierre.to_d, 0].max * it.stock&.costo_unitario_ars.to_d
        }.to_f.round(2),
        # En cuántos productos faltó: "en 1 producto" dice mucho más que un número suelto.
        productos_con_faltante: items.count { |it| it.diferencia_cierre.to_d.negative? },
        # CUÁLES faltaron, no cuántos. «En 1 producto» no sirve para hacer nada: para ir a
        # buscarlo hay que saber si es la flor o los prerolls. Van los tres más caros y el resto
        # se cuenta — con quince renglones la fila deja de ser una oración.
        faltaron:  detalle_diferencias(items, :falta),
        # Y lo mismo con lo que se contó de MÁS, que es otra cosa y se explica distinto: no se
        # carga al inventario, porque el mostrador descuenta producto y nunca lo suma.
        sobraron:  detalle_diferencias(items, :sobra),
        # DE DÓNDE SALE LA CUENTA DE LA CAJA. «$130.000, faltó $20.000» no se puede comprobar:
        # con el fondo y lo cobrado, la frase se explica sola.
        caja: turno.caja_turno && {
          fondo_ars:     turno.caja_turno.monto_inicial_ars&.to_f,
          esperado_ars:  turno.caja_turno.efectivo_esperado_ars&.to_f,
          contado_ars:   turno.caja_turno.efectivo_declarado_ars&.to_f,
          diferencia_ars: turno.caja_turno.diferencia_ars&.to_f,
        },
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
            # EL ID DEL RENGLÓN, que es con lo que se corrige (`CorregirCierre` busca por
            # `item_id`). No estaba, así que la pantalla de corregir no tenía con qué mandar
            # nada aunque hubiera listado algo.
            id: it.id,
            stock_id: it.stock_id, etiqueta: it.stock&.etiqueta, unidad: it.stock&.unidad,
            esperado: it.esperado_apertura&.to_f, contado: it.cantidad_apertura.to_f,
            diferencia: it.esperado_apertura ? (it.cantidad_apertura.to_d - it.esperado_apertura.to_d).to_f : nil,
            dispensada: it.cantidad_dispensada.to_f,
            esperado_cierre: it.esperado_cierre&.to_f,
            contado_cierre:  it.cantidad_cierre&.to_f,
          }
        end,
      }.then { |h| h.merge(items: h[:conteo_apertura]) }
      # `items` es el MISMO array, con el nombre que la pantalla de corregir siempre leyó.
      #
      # Ese modal hacía `data.items` y el payload sólo traía `conteo_apertura`: la lista salía
      # VACÍA siempre, así que quedaba un campo de motivo suelto —«se abre un modal que dice
      # ingresar motivo y no hacés nada más», lo reportó Germán— y al confirmar contestaba «no
      # cambiaste ningún número». La función existía y no era alcanzable.
      #
      # Se manda con los dos nombres en vez de renombrar: `conteo_apertura` lo lee la pantalla
      # del mostrador y romperla para arreglar esta sería cambiar un bug por otro.
    end

    def valor_de_la_mesa
      mesa.sum { |mi| mi.cantidad.to_d * mi.stock&.costo_unitario_ars.to_d }.to_f.round(2)
    end

  end
end
