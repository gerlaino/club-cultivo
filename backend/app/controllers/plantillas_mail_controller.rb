# Plantillas de correo de la organización. Sólo el admin las edita: son textos que salen con la
# firma de la organización a todos sus pacientes.
class PlantillasMailController < ApplicationController
  before_action :authenticate_user!
  # El super_admin sin organización lo corta `block_super_admin_sin_contexto!` en
  # ApplicationController con un 409; acá no hace falta repetirlo.
  before_action -> { require_feature!(:mailer) }
  before_action :require_admin!, except: [:index]
  before_action :set_plantilla, only: [:update, :destroy]

  # GET /plantillas_mail
  # Siembra las tres de fábrica la primera vez. Se hace acá y no en una migración a propósito:
  # una organización que todavía no abrió la pantalla no necesita filas, y sembrar en la
  # migración habría dejado plantillas a clubes que no tienen el módulo.
  def index
    PlantillaMail.sembrar!(current_club)

    render json: {
      data: current_club.plantillas_mail.ordenadas.map { |p| serialize(p) },
      variables: PlantillaMail::VARIABLES_AYUDA.map { |clave, ayuda| { clave: clave, ayuda: ayuda } },
    }
  end

  # POST /plantillas_mail
  def create
    plantilla = current_club.plantillas_mail.new(plantilla_params)
    plantilla.creada_por = current_user

    if plantilla.save
      render json: { data: serialize(plantilla) }, status: :created
    else
      render json: { errors: plantilla.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /plantillas_mail/:id
  def update
    if @plantilla.update(plantilla_params)
      render json: { data: serialize(@plantilla) }
    else
      render json: { errors: @plantilla.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /plantillas_mail/:id
  # Borrado lógico: los mails ya enviados con esta plantilla la siguen referenciando, y el
  # historial del paciente tiene que poder decir con qué salió.
  def destroy
    @plantilla.deleted_by = current_user if @plantilla.respond_to?(:deleted_by=)
    @plantilla.destroy
    head :no_content
  end

  private

  def current_club = current_user.club

  def set_plantilla
    @plantilla = current_club.plantillas_mail.find(params[:id])
  end

  def require_admin!
    return if current_user.admin?

    render json: { error: 'Sólo un administrador puede editar las plantillas de correo.' },
           status: :forbidden
  end

  def plantilla_params
    params.require(:plantilla_mail).permit(:nombre, :asunto, :cuerpo, :activa, :bienvenida)
  end

  # `asunto`/`cuerpo` van crudos (con las llaves) porque es lo que el admin edita. La resolución
  # contra un paciente concreto la hace la vista previa del frontend o el envío.
  def serialize(p)
    {
      id: p.id, nombre: p.nombre, asunto: p.asunto, cuerpo: p.cuerpo,
      activa: p.activa, bienvenida: p.bienvenida,
      updated_at: p.updated_at,
    }
  end
end
