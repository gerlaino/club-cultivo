# app/controllers/socios_controller.rb
class SociosController < ApplicationController
  before_action :authenticate_user!

  before_action :set_socio, only: [:show, :update, :destroy]
  before_action :normalize_socio_params, only: [:create, :update]

  def index
    page   = (params[:pagina] || 1).to_i
    limit  = (params[:limite] || 20).to_i
    query  = params[:query].to_s.strip
    dni    = params[:dni].to_s.gsub(/\D/, "")
    orden  = params[:orden].presence_in(%w[created_at nombre apellido]) || "created_at"
    dir    = params[:dir].to_s.downcase == "asc" ? "asc" : "desc"

    scope = Socio.for_club(current_user.club_id)

    if query.present?
      q = query.downcase
      scope = scope.where(
        "lower(nombre) LIKE :q OR lower(apellido) LIKE :q OR dni_normalizado LIKE :dni",
        q: "%#{q}%", dni: "%#{dni}%"
      )
    elsif dni.present?
      scope = scope.where("dni_normalizado LIKE ?", "%#{dni}%")
    end

    total  = scope.count
    socios = scope.order("#{orden} #{dir}")
                  .offset((page - 1) * limit)
                  .limit(limit)

    render json: {
      data: socios.as_json(methods: :nombre_completo),
      meta: { pagina: page, limite: limit, total: total }
    }
  end

  def show
    render json: { data: @socio.as_json(methods: :nombre_completo) }
  end

  def create
    socio = Socio.new(socio_params)
    socio.club_id    = current_user.club_id
    socio.created_by = current_user
    socio.updated_by = current_user

    if socio.save
      render json: { data: socio }, status: :created
    else
      render json: { errors: socio.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @socio.assign_attributes(socio_params)
    @socio.updated_by = current_user

    if @socio.save
      render json: { data: @socio }
    else
      render json: { errors: @socio.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @socio.update!(deleted_by_id: current_user.id)
    @socio.destroy # paranoia: soft delete
    head :no_content
  end

  private

  def set_socio
    @socio = Socio.for_club(current_user.club_id).find(params[:id])
  end

  # Alias EN→ES por compatibilidad con el front
  def normalize_socio_params
    return unless params[:socio].is_a?(ActionController::Parameters)
    p = params[:socio]
    p[:nombre]           ||= p.delete(:first_name)       if p[:first_name]
    p[:apellido]         ||= p.delete(:last_name)        if p[:last_name]
    p[:fecha_nacimiento] ||= p.delete(:birthday)         if p[:birthday]
    p[:telefono]         ||= p.delete(:phone)            if p[:phone]

    if p[:fecha_nacimiento].present? && p[:fecha_nacimiento] =~ %r{\A\d{2}/\d{2}/\d{4}\z}
      d, m, y = p[:fecha_nacimiento].split("/")
      p[:fecha_nacimiento] = "#{y}-#{m}-#{d}"
    end
  end

  def socio_params
    params.require(:socio).permit(
      :nombre, :apellido, :dni, :fecha_nacimiento, :es_paciente,
      :email, :telefono,
      :reprocann_numero, :reprocann_vencimiento
    )
  end
end
