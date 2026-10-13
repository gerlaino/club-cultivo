module SuperAdmin
  # El cobro con Mercado Pago de cada organización (12-oct-2026): super admin genera el link con el
  # monto de ESA organización y se lo manda; lo que pasa después llega por el webhook.
  # También el precio fijo del autocultivo (`AjustePlataforma`).
  class SuscripcionesController < BaseController
    before_action :set_club, only: %i[show create cancelar]

    # GET /super_admin/clubs/:club_id/suscripcion
    def show
      actual = @club.suscripciones.order(created_at: :desc).first
      render json: { mp_configurado: Pagos::MercadoPago.configurado?,
                     actual: SuscripcionSerializer.call(actual, con_cobros: true),
                     plan_activo_hasta: @club.plan_activo_hasta,
                     email_sugerido: actual&.payer_email || @club.users.find_by(role: 'admin')&.email_real }
    end

    # POST /super_admin/clubs/:club_id/suscripcion { monto_ars, payer_email }
    def create
      s = Pagos::Suscripciones::Crear.new(club: @club, monto_ars: params[:monto_ars], payer_email: params[:payer_email],
                                          origen: @club.personal? ? 'autocultivo' : 'organizacion', por: current_user).call
      render json: SuscripcionSerializer.call(s, con_cobros: true), status: :created
    rescue Pagos::Suscripciones::Crear::Error => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end

    # POST /super_admin/clubs/:club_id/suscripcion/cancelar
    def cancelar
      s = @club.suscripciones.vivas.order(created_at: :desc).first
      return render json: { errors: ['No tiene una suscripción viva.'] }, status: :unprocessable_entity unless s

      Pagos::Suscripciones::Cancelar.new(s).call
      render json: SuscripcionSerializer.call(s.reload, con_cobros: true)
    rescue Pagos::MercadoPago::Error => e
      render json: { errors: [e.message] }, status: :bad_gateway
    end

    # GET /super_admin/precio_autocultivo
    def precio_autocultivo
      render json: { monto_ars: AjustePlataforma.precio_autocultivo_ars&.to_f, mp_configurado: Pagos::MercadoPago.configurado? }
    end

    # PUT /super_admin/precio_autocultivo { monto_ars }
    # Rige para las suscripciones NUEVAS: las que ya están cobrando siguen con su monto hasta que se
    # les genere otra (Mercado Pago no le cambia el monto a nadie sin avisarle).
    def guardar_precio_autocultivo
      monto = params[:monto_ars].to_d
      return render json: { errors: ['El precio tiene que ser mayor a cero.'] }, status: :unprocessable_entity unless monto.positive?

      AjustePlataforma.escribir!(AjustePlataforma::PRECIO_AUTOCULTIVO, { 'monto' => monto.to_s }, por: current_user)
      render json: { monto_ars: monto.to_f }
    end

    private

    def set_club
      @club = Club.find(params[:club_id])
    end
  end
end
