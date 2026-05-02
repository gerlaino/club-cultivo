class SuperAdmin::ClubsController < SuperAdmin::BaseController
  before_action :set_club, only: [:show, :update, :crear_usuarios_default, :cambiar_plan, :observar, :detener_observacion, :destroy, :restaurar]

  def index
    clubs = Club.unscoped.includes(:users, :pacientes).order(:created_at)
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
      render json: { errors: @club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def crear_usuarios_default
    @club.crear_geneticas_default!
    usuarios = @club.crear_usuarios_default!
    render json: { usuarios: usuarios.map { |u| { id: u.id, email: u.email, role: u.role } } }
  end

  def observar
    token = SecureRandom.hex(24)
    current_user.update!(
      observer_club_id:   @club.id,
      observer_token:     token,
      observer_expires_at: 15.minutes.from_now
    )
    render json: {
      token:            token,
      club_id:          @club.id,
      club_nombre:      @club.name,
      expires_at:       current_user.observer_expires_at,
      instrucciones:    'Incluir header X-Observer-Token en requests. Modo solo lectura activo.',
    }, status: :created
  end

  def detener_observacion
    current_user.update!(
      observer_club_id:    nil,
      observer_token:      nil,
      observer_expires_at: nil
    )
    head :no_content
  end

  def destroy
    @club.soft_delete!
    head :no_content
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def restaurar
    @club.restaurar!
    render json: serialize_club_detail(@club)
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
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
    @club = Club.unscoped.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Club no encontrado' }, status: :not_found
  end

  def club_params
    params.require(:club).permit(
      :name, :legal_name, :email, :phone, :website,
      :address, :city, :state, :country, :timezone,
      :plan, :plan_activo_hasta, :plan_trial, :web_activa
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
      pacientes_count:  c.pacientes.count,
      lotes_count:      c.lotes.count,
      created_at:       c.created_at,
      deleted_at:       c.deleted_at,
    }
  end

  def serialize_club_detail(c)
    serialize_club(c).merge(
      website:   c.website,
      address:   c.address,
      timezone:  c.timezone,
      usuarios:  c.users.map { |u| { id: u.id, email: u.email, role: u.role, nombre: u.nombre_completo } },
      web_activa: c.web_activa,
      )
  end
end