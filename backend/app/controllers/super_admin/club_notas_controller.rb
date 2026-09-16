# Lo que anotamos sobre una organización: con quién se habló y qué quedó. Se crea y se borra,
# no se edita (ver `ClubNota`).
class SuperAdmin::ClubNotasController < SuperAdmin::BaseController
  before_action :set_club

  def index
    render json: @club.notas.recientes.includes(:user).map { |n| serialize(n) }
  end

  def create
    nota = @club.notas.build(texto: params[:texto].to_s.strip, user: current_user)
    if nota.save
      render json: serialize(nota), status: :created
    else
      render json: { errors: nota.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @club.notas.find(params[:id]).destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Nota no encontrada' }, status: :not_found
  end

  private

  def set_club
    @club = Club.unscoped.find(params[:club_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Organización no encontrada' }, status: :not_found
  end

  def serialize(n)
    { id: n.id, texto: n.texto, fecha: n.created_at,
      usuario: n.user ? { id: n.user.id, nombre: n.user.nombre_completo.presence || n.user.email } : nil }
  end
end
