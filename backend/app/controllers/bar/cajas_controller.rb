module Bar
  # Caja de turno de un bar (anidado bajo /bares/:bar_id/cajas). Abrir/cerrar/ver la actual:
  # operadores del bar (admin/supervisor/dispensador, que manejan la caja). Historial de
  # cierres: gestión (admin/supervisor). Feature flag :bar.
  class CajasController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :set_bar
    before_action :require_operador, only: [:actual, :confirmar_apertura, :solicitar_cierre]
    before_action :require_gestion,  only: [:index, :abrir, :cerrar, :confirmar_cierre]

    # GET /bares/:bar_id/cajas/actual — la caja activa (abierta o pendiente de cierre), o null
    def actual
      render json: { caja: serialize(@bar.caja_turnos.activas.first) }
    end

    # GET /bares/:bar_id/cajas — historial de cierres
    def index
      cajas = @bar.caja_turnos.recientes.limit(50)
      render json: cajas.map { |c| serialize(c) }
    end

    # POST /bares/:bar_id/cajas/abrir  { monto_inicial_ars } — admin/supervisor
    def abrir
      return render json: { error: 'Ya hay una caja activa para este bar' }, status: :unprocessable_entity if @bar.caja_turnos.activas.exists?

      caja = @bar.caja_turnos.build(
        club: current_user.club, sede: @bar.sede, abierta_por: current_user,
        monto_inicial_ars: params[:monto_inicial_ars].to_d, abierta_at: Time.current
      )
      if caja.save
        render json: serialize(caja), status: :created
      else
        render json: { errors: caja.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # POST /bares/:bar_id/cajas/:id/confirmar_apertura — el operador confirma que está el fondo
    def confirmar_apertura
      con_caja { |caja| caja.confirmar_apertura!(usuario: current_user) }
    end

    # POST /bares/:bar_id/cajas/:id/solicitar_cierre { efectivo_declarado_ars, notas? }
    # El dispensador cuenta y envía: queda pendiente de confirmación del admin/supervisor.
    def solicitar_cierre
      con_caja { |caja| caja.solicitar_cierre!(efectivo_declarado: params[:efectivo_declarado_ars].to_d, solicitada_por: current_user, notas: params[:notas]) }
    end

    # POST /bares/:bar_id/cajas/:id/confirmar_cierre — admin/supervisor confirma el cierre enviado
    def confirmar_cierre
      con_caja { |caja| caja.cerrar!(cerrada_por: current_user) }
    end

    # POST /bares/:bar_id/cajas/:id/cerrar { efectivo_declarado_ars, notas? } — cierre directo (gestión)
    def cerrar
      con_caja { |caja| caja.cerrar!(efectivo_declarado: params[:efectivo_declarado_ars].to_d, cerrada_por: current_user, notas: params[:notas]) }
    end

    private

    def con_caja
      caja = @bar.caja_turnos.find(params[:id])
      yield caja
      render json: serialize(caja)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Caja no encontrada' }, status: :not_found
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def set_bar
      @bar = current_user.club.bares.find(params[:bar_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bar no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    ROLES_OPERADOR = %w[admin supervisor dispensador].freeze
    ROLES_GESTION  = %w[admin supervisor].freeze

    def require_operador
      render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_OPERADOR.include?(current_user&.role)
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_GESTION.include?(current_user&.role)
    end

    def serialize(c)
      return nil if c.nil?

      {
        id:                     c.id,
        estado:                 c.estado,
        monto_inicial_ars:      c.monto_inicial_ars.to_f,
        total_ventas_ars:       c.total_ventas_ars,
        total_efectivo_ars:     c.total_efectivo_ars,
        total_digital_ars:      c.total_digital_ars,
        tickets:                c.tickets,
        efectivo_esperado_ars:  c.efectivo_esperado_ars,
        efectivo_declarado_ars: c.efectivo_declarado_ars&.to_f,
        diferencia_ars:         c.diferencia_ars,
        apertura_confirmada:    c.apertura_confirmada?,
        abierta_at:             c.abierta_at,
        cerrada_at:             c.cerrada_at,
        cierre_solicitado_at:   c.cierre_solicitado_at,
        abierta_por:            c.abierta_por&.nombre_completo,
        apertura_confirmada_por: c.apertura_confirmada_por&.nombre_completo,
        cierre_solicitado_por:  c.cierre_solicitado_por&.nombre_completo,
        cerrada_por:            c.cerrada_por&.nombre_completo,
        notas:                  c.notas,
      }
    end
  end
end
