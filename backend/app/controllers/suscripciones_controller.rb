# GET/POST /suscripcion — la suscripción del AUTOCULTIVO, desde la propia cuenta (12-oct-2026).
#
# El precio es el fijo de la plataforma (`AjustePlataforma.precio_autocultivo_ars`, lo carga super
# admin); la persona sólo dice con qué mail de Mercado Pago va a pagar. Las organizaciones no se
# suscriben solas: su link (con su monto) lo genera super admin.
#
# Tiene que andar con la cuenta PAUSADA por fin de prueba o falta de pago: es justamente lo que
# hay que hacer para despausarla. Pausada por otra cosa, no.
class SuscripcionesController < ApplicationController
  skip_before_action :check_club_activo!
  before_action :authenticate_user!
  before_action :exigir_autocultivo_habilitado

  def show
    actual = club.suscripciones.order(created_at: :desc).first
    render json: { precio_ars: AjustePlataforma.precio_autocultivo_ars&.to_f,
                   mp_configurado: Pagos::MercadoPago.configurado?,
                   actual: SuscripcionSerializer.call(actual),
                   plan_activo_hasta: club.plan_activo_hasta, en_prueba: club.plan_trial?,
                   email_sugerido: actual&.payer_email || current_user.email_real || current_user.email }
  end

  def create
    precio = AjustePlataforma.precio_autocultivo_ars
    return render json: { errors: ['Todavía no hay un precio cargado para suscribirse. Escribinos.'] }, status: :unprocessable_entity unless precio

    s = Pagos::Suscripciones::Crear.new(club: club, monto_ars: precio, payer_email: params[:payer_email].presence || current_user.email,
                                        origen: 'autocultivo', por: current_user).call
    render json: SuscripcionSerializer.call(s), status: :created
  rescue Pagos::Suscripciones::Crear::Error => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def club = current_user.club

  def exigir_autocultivo_habilitado
    ok = club&.personal? && current_user.admin? && !club.eliminado? &&
         (club.activo? || %w[prueba_terminada no_pago].include?(club.suspension_motivo))
    render json: { error: 'No autorizado' }, status: :forbidden unless ok
  end
end
