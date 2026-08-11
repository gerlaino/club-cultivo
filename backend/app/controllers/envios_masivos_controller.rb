# Envíos masivos de correo. Sólo admin: sale con la firma de la organización a mucha gente de
# una, y es la clase de acción que no se puede deshacer.
class EnviosMasivosController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:mailer) }
  before_action :require_admin!

  # GET /envios_masivos — historial + cuánto cupo queda hoy.
  def index
    envios = current_club.envios_masivos.recientes.limit(30).includes(:user, :plantilla_mail)

    render json: {
      data: envios.map { |e| serialize(e) },
      cupo: { limite: Correo::CupoDiario::LIMITE, restante: Correo::CupoDiario.restante(current_club) },
    }
  end

  # POST /envios_masivos
  def create
    plantilla = current_club.plantillas_mail.find_by(id: params[:plantilla_mail_id]) if params[:plantilla_mail_id].present?

    r = Correo::PrepararEnvio.call(
      club: current_club, usuario: current_user,
      asunto: params[:asunto], cuerpo: params[:cuerpo],
      destino: params[:destino].presence_in(EnvioMasivo::DESTINOS) || 'pacientes',
      plantilla: plantilla,
      paciente_ids: params[:paciente_ids], emails: params[:emails]
    )

    unless r.ok?
      return render json: { error: r.error, salteados: r.salteados }, status: :unprocessable_entity
    end

    render json: { data: serialize(r.envio), salteados: r.salteados }, status: :created
  end

  # GET /envios_masivos/:id — para seguir el progreso mientras manda.
  def show
    render json: { data: serialize(current_club.envios_masivos.find(params[:id]), detalle: true) }
  end

  private

  def current_club = current_user.club

  def require_admin!
    return if current_user.admin?

    render json: { error: 'Sólo un administrador puede hacer envíos masivos.' }, status: :forbidden
  end

  def serialize(e, detalle: false)
    base = {
      id: e.id, asunto: e.asunto, destino: e.destino, estado: e.estado,
      total: e.total, enviados: e.enviados, fallidos: e.fallidos,
      plantilla: e.plantilla_mail&.nombre,
      enviado_por: e.user&.nombre_completo,
      created_at: e.created_at, terminado_at: e.terminado_at,
    }
    # Los errores por destinatario sólo en el detalle: son lo que se necesita para saber a quién
    # reenviarle, pero en una lista de 30 envíos son ruido.
    base[:fallas] = e.resultados.reject { |r| r['ok'] } if detalle
    base
  end
end
