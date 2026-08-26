module Dispensario
  # Caja de turno del MOSTRADOR de dispensa, anidada bajo /sedes/:sede_id/caja.
  #
  # Es la misma mecánica que la del buffet y comparte el modelo (`CajaTurno` apunta a un punto de
  # venta: una `Barra` o una `Sede`). Lo que NO comparte es la plata: son cajas independientes,
  # cada una con su fondo, su arqueo y su cierre.
  #
  # El flujo, tal cual lo pidió Germán: el admin la abre declarando el fondo → el dispensador
  # confirma que ese fondo está en el cajón → se opera → el dispensador cuenta y envía el cierre →
  # el admin lo confirma. Los dos pasos de confirmación existen para que ninguno de los dos quede
  # solo respondiendo por una diferencia de arqueo.
  #
  # Lo cobrado del turno sale de los `cobros` enganchados a la caja (efectivo y transferencia). La
  # cuenta corriente no entra: es deuda registrada, no plata que entró al cajón.
  class CajasController < ApplicationController
    before_action :authenticate_user!
    before_action -> { require_feature!(:produccion_dispensa) }
    before_action :set_sede
    before_action :require_operador, only: [:actual, :confirmar_apertura, :solicitar_cierre]
    before_action :require_gestion,  only: [:responsables]
    before_action :require_gestion,  only: [:index, :abrir, :cerrar, :confirmar_cierre, :salida, :anular]

    # GET /sedes/:sede_id/caja/responsables — a quién se le puede atribuir un retiro
    def responsables
      users = current_user.club.users.where(role: MovimientoContable::ROLES_RETIRO).order(:first_name)
      render json: users.map { |u| { id: u.id, nombre: u.nombre_completo, rol: u.role } }
    end

    # GET /sedes/:sede_id/caja/actual — la caja activa del mostrador, o null
    def actual
      render json: { caja: serialize(caja_activa) }
    end

    # GET /sedes/:sede_id/caja?pagina=1&limite=10 — historial de CIERRES
    #
    # Filtra por estado en SQL, no después. Antes traía las últimas 50 de cualquier estado y el
    # front se quedaba con las cerradas: con 50 aperturas anuladas se veían CERO cierres, y a
    # partir del turno 51 los viejos desaparecían sin que nada lo dijera.
    #
    # Con un turno por día, 50 son menos de dos meses: el tope se alcanza y el silencio es el
    # problema. Ahora pagina y dice cuántas hay.
    def index
      escala  = cajas_de_la_sede.where(estado: 'cerrada')
      pagina  = [params[:pagina].to_i, 1].max
      limite  = [[(params[:limite] || 10).to_i, 1].max, 50].min

      render json: {
        cajas: escala.recientes.offset((pagina - 1) * limite).limit(limite).map { |c| serialize(c) },
        meta:  { pagina: pagina, limite: limite, total: escala.count },
      }
    end

    # POST /sedes/:sede_id/caja/abrir { monto_inicial_ars } — admin/supervisor
    def abrir
      if caja_activa
        return render json: { error: 'Ya hay una caja abierta en este mostrador' }, status: :unprocessable_entity
      end

      caja = CajaTurno.new(
        club: current_user.club, sede: @sede, punto: @sede, abierta_por: current_user,
        monto_inicial_ars: params[:monto_inicial_ars].to_d, abierta_at: Time.current
      )

      if caja.save
        render json: serialize(caja), status: :created
      else
        render json: { errors: caja.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # POST /sedes/:sede_id/caja/:id/confirmar_apertura — el dispensador confirma que está el fondo
    def confirmar_apertura
      con_caja { |caja| caja.confirmar_apertura!(usuario: current_user) }
    end

    # POST /sedes/:sede_id/caja/:id/solicitar_cierre { efectivo_declarado_ars, notas? }
    def solicitar_cierre
      con_caja do |caja|
        caja.solicitar_cierre!(efectivo_declarado: params[:efectivo_declarado_ars].to_d,
                               solicitada_por: current_user, notas: params[:notas])
      end
    end

    # POST /sedes/:sede_id/caja/:id/confirmar_cierre — admin/supervisor confirma lo que envió el operador
    def confirmar_cierre
      # `notas` acá es el motivo de la diferencia, y termina en el asiento: "faltante de caja —
      # se pagó un flete sin registrar". Un faltante sin explicación no se puede revisar después.
      con_caja { |caja| caja.cerrar!(cerrada_por: current_user, notas: params[:notas]) }
    end

    # POST /sedes/:sede_id/caja/:id/cerrar { efectivo_declarado_ars, notas? } — cierre directo
    def cerrar
      con_caja do |caja|
        caja.cerrar!(efectivo_declarado: params[:efectivo_declarado_ars].to_d,
                     cerrada_por: current_user, notas: params[:notas])
      end
    end

    # Sacar efectivo del cajón. Son DOS hechos distintos y hay que elegir cuál:
    #
    #   gasto  → el club GASTÓ esa plata (un flete, una compra). Egreso: baja el resultado.
    #   retiro → la plata salió del cajón pero sigue siendo del club, o quedó a nombre de
    #            alguien. "Dame $100.000 de la caja, anotámelos a mí" NO es un gasto: asentarlo
    #            como egreso infla los gastos por plata que nadie gastó. Va como `ajuste`, que
    #            queda afuera de los scopes de ingresos y egresos.
    #
    # Las dos restan del arqueo: en las dos, la plata no está en el cajón.
    CLASES_SALIDA = {
      'gasto'  => { tipo: 'egreso',  categoria: 'salida_caja', prefijo: 'Gasto pagado con la caja' },
      'retiro' => { tipo: 'ajuste',  categoria: 'retiro_caja', prefijo: 'Retiro de caja' },
    }.freeze

    # POST /sedes/:sede_id/caja/:id/salida { monto_ars, motivo, clase: gasto|retiro }
    #
    # Lo hace administración, no el mostrador: es plata que sale y alguien tiene que responder.
    def salida
      monto  = params[:monto_ars].to_d
      motivo = params[:motivo].to_s.strip
      clase  = CLASES_SALIDA[params[:clase].to_s.presence || 'retiro']

      return render json: { error: 'El monto debe ser mayor a $0.' }, status: :unprocessable_entity if monto <= 0
      return render json: { error: 'Escribí para qué se saca la plata.' }, status: :unprocessable_entity if motivo.blank?
      return render json: { error: 'Indicá si es un gasto o un retiro.' }, status: :unprocessable_entity if clase.nil?

      # Un retiro siempre queda a nombre de alguien, y ese alguien responde por la plata: admin o
      # supervisor. Por defecto, quien lo está registrando —el caso normal es que se la lleve él—
      # pero se puede anotar a otro: el admin registrando lo que retiró el supervisor.
      retirado_por = nil
      if clase[:categoria] == 'retiro_caja'
        retirado_por = if params[:retirado_por_id].present?
          current_user.club.users.find_by(id: params[:retirado_por_id])
        else
          current_user
        end
        return render json: { error: 'Elegí a quién se le atribuye el retiro.' }, status: :unprocessable_entity if retirado_por.nil?
      end

      con_caja do |caja|
        raise ArgumentError, 'La caja no está abierta' unless caja.abierta?
        if monto > caja.efectivo_esperado_ars.to_d
          raise ArgumentError, "No hay tanto efectivo en la caja: hay #{caja.efectivo_esperado_ars}."
        end

        caja.movimientos_contables.create!(
          club: current_user.club, sede_id: caja.sede_id, created_by: current_user,
          tipo: clase[:tipo], categoria: clase[:categoria], retirado_por: retirado_por,
          descripcion: "#{clase[:prefijo]} — #{motivo}",
          monto_ars: monto, fecha: Time.zone.today,
          pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante',
        )
      end
    end

    # POST /sedes/:sede_id/caja/:id/anular { motivo? }
    #
    # Deshacer una apertura equivocada: mal monto, la sede que no era, se arrepintió. Sólo si la
    # caja no tiene movimiento — con un cobro adentro la salida es el cierre con su arqueo.
    #
    # No es lo mismo que cerrar: cerrar con $0 contado generaría un faltante por todo el fondo, un
    # egreso inventado en el libro. Anular no toca contabilidad porque abrir tampoco la tocó.
    def anular
      con_caja { |caja| caja.anular!(usuario: current_user, motivo: params[:motivo]) }
    end

    private

    def set_sede
      @sede = current_user.club.sedes.find(params[:sede_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Sede no encontrada' }, status: :not_found
    end

    def cajas_de_la_sede
      CajaTurno.where(club_id: current_user.club_id, punto_type: 'Sede', punto_id: @sede.id)
    end

    def caja_activa = cajas_de_la_sede.activas.first

    def con_caja
      caja = cajas_de_la_sede.find(params[:id])
      yield caja
      render json: serialize(caja.reload)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Caja no encontrada' }, status: :not_found
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # Quien está en el mostrador: confirma la apertura y envía el cierre.
    def require_operador
      return if %w[admin supervisor dispensador super_admin].include?(current_user.role)

      render json: { error: 'No autorizado' }, status: :forbidden
    end

    # Quien responde por la plata: abre y confirma el cierre.
    def require_gestion
      return if %w[admin supervisor super_admin].include?(current_user.role)

      render json: { error: 'Solo administración puede abrir o cerrar la caja' }, status: :forbidden
    end

    def serialize(caja)
      return nil if caja.nil?

      {
        id:                     caja.id,
        estado:                 caja.estado,
        sede:                   { id: caja.sede_id, nombre: caja.sede&.nombre },
        monto_inicial_ars:      caja.monto_inicial_ars.to_f,
        abierta_at:             caja.abierta_at,
        abierta_por:            caja.abierta_por&.nombre_completo,
        apertura_confirmada:    caja.apertura_confirmada?,
        apertura_confirmada_por: caja.apertura_confirmada_por&.nombre_completo,
        apertura_confirmada_at: caja.apertura_confirmada_at,
        cierre_solicitado_por:  caja.cierre_solicitado_por&.nombre_completo,
        cierre_solicitado_at:   caja.cierre_solicitado_at,
        cerrada_at:             caja.cerrada_at,
        cerrada_por:            caja.cerrada_por&.nombre_completo,
        tickets:                caja.tickets,
        total_cobrado_ars:      caja.total_ventas_ars,
        total_efectivo_ars:     caja.total_efectivo_ars,
        total_digital_ars:      caja.total_digital_ars,
        total_salidas_ars:      caja.total_salidas_ars,
        salidas:                caja.salidas.order(:created_at).map { |m| { id: m.id, monto_ars: m.monto_ars.to_f, descripcion: m.descripcion, clase: m.categoria == 'retiro_caja' ? 'retiro' : 'gasto', quien: (m.retirado_por || m.created_by)&.nombre_completo } },
        efectivo_esperado_ars:  caja.efectivo_esperado_ars,
        efectivo_declarado_ars: caja.efectivo_declarado_ars&.to_f,
        diferencia_ars:         caja.diferencia_ars,
        notas:                  caja.notas,
        anulable:               caja.anulable?,
      }
    end
  end
end
