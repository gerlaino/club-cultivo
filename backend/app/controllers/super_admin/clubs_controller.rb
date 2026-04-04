class SuperAdmin::ClubsController < SuperAdmin::BaseController
  before_action :set_club, only: [:show, :update, :crear_usuarios_default, :cambiar_plan]

  def index
    clubs = Club.all.includes(:users, :socios).order(:created_at)
    render json: clubs.map { |c| serialize_club(c) }
  end

  def show
    render json: serialize_club_detail(@club)
  end

  def create
    club = Club.new(club_params)
    if club.save
      usuarios = club.crear_usuarios_default!
      club.crear_geneticas_default!
      render json: {
        club:     serialize_club_detail(club),
        usuarios: usuarios.map { |u| { id: u.id, email: u.email, role: u.role } }
      }, status: :created
    else
      render json: { errors: club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @club.update(club_params)
      render json: serialize_club_detail(@club)
    else
      render json: { errors: club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def crear_usuarios_default
    @club.crear_geneticas_default!
    usuarios = @club.crear_usuarios_default!
    render json: { usuarios: usuarios.map { |u| { id: u.id, email: u.email, role: u.role } } }
  end

  def cambiar_plan
    plan      = params[:plan]
    hasta     = params[:hasta]
    trial     = params[:trial]

    unless PlanEnforcer::PLANES.key?(plan)
      return render json: { error: "Plan inválido. Opciones: #{PlanEnforcer::PLANES.keys.join(', ')}" },
                    status: :unprocessable_entity
    end

    @club.update!(
      plan:             plan,
      plan_activo_hasta: hasta.present? ? Date.parse(hasta) : nil,
      plan_trial:       trial == true || trial == 'true',
      )
    render json: serialize_club_detail(@club)
  end

  private

  def set_club
    @club = Club.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Club no encontrado' }, status: :not_found
  end

  def club_params
    params.require(:club).permit(
      :name, :legal_name, :email, :phone, :website,
      :address, :city, :state, :country, :timezone,
      :plan, :plan_activo_hasta, :plan_trial
    )
  end

  def serialize_club(c)
    {
      id:               c.id,
      name:             c.name,
      slug:             c.slug,
      legal_name:       c.legal_name,
      email:            c.email,
      phone:            c.phone,
      city:             c.city,
      state:            c.state,
      country:          c.country,
      plan:             c.plan,
      plan_trial:       c.plan_trial,
      plan_activo_hasta: c.plan_activo_hasta,
      usuarios_count:   c.users.count,
      pacientes_count:  c.socios.count,
      lotes_count:      c.lotes.count,
      created_at:       c.created_at,
    }
  end

  def serialize_club_detail(c)
    serialize_club(c).merge(
      website:   c.website,
      address:   c.address,
      timezone:  c.timezone,
      usuarios:  c.users.map { |u| { id: u.id, email: u.email, role: u.role, nombre: u.nombre_completo } },
      )
  end
end