# Depósitos del club: los de sistema (Cultivo/General/Salón/Dispensación) se siembran y no se
# borran; el admin puede crear/renombrar/desactivar los propios. Lectura: admin/supervisor/
# cultivador/auditor. Gestión: admin/supervisor.
class DepositosController < ApplicationController
  before_action :authenticate_user!
  before_action :asegurar_depositos, only: [:index]
  before_action :require_lectura,    only: [:index]
  before_action :require_gestion,    only: [:create, :update, :destroy]
  before_action :set_deposito,       only: [:update, :destroy]

  # GET /depositos
  def index
    depos = current_user.club.depositos.ordenados.includes(:unidad_negocio).to_a
                        .select { |d| d.disponible_para?(current_user.club) }
    render json: depos.map { |d| serialize(d) }
  end

  # POST /depositos  { deposito: { nombre } }
  def create
    d = current_user.club.depositos.build(deposito_params)
    d.es_sistema = false # un depósito creado por el admin nunca es de sistema
    if d.save
      render json: serialize(d), status: :created
    else
      render json: { errors: d.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /depositos/:id
  def update
    # Los depósitos del sistema (Cultivo/General/Salón/Dispensación) no se renombran —el nombre
    # es parte de la identidad esperada y podría confundir/romper referencias. Solo activar/ordenar.
    permitidos = @deposito.es_sistema ? deposito_params.except(:nombre) : deposito_params
    if @deposito.update(permitidos)
      render json: serialize(@deposito)
    else
      render json: { errors: @deposito.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /depositos/:id
  def destroy
    if @deposito.es_sistema
      return render json: { error: 'Los depósitos del sistema no se pueden borrar. Podés desactivarlo.' }, status: :unprocessable_entity
    end
    if @deposito.insumos.exists?
      return render json: { error: 'El depósito tiene productos. Movelos a otro depósito o desactivalo en vez de borrarlo.' }, status: :unprocessable_entity
    end
    @deposito.destroy
    head :no_content
  end

  private

  def set_deposito
    @deposito = current_user.club.depositos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Depósito no encontrado' }, status: :not_found
  end

  def asegurar_depositos
    club = current_user.club
    if club.depositos.none? || club.insumos.where(deposito_id: nil).exists?
      Finanzas::SembrarDepositos.new(club).call
    end
  end

  ROLES_LECTURA = %w[admin supervisor cultivador auditor].freeze
  ROLES_GESTION = %w[admin supervisor].freeze

  def require_lectura
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_LECTURA.include?(current_user&.role)
  end

  def require_gestion
    render json: { error: 'No autorizado' }, status: :forbidden unless ROLES_GESTION.include?(current_user&.role)
  end

  def deposito_params
    # La clave_sistema no se edita desde la API (la fija la siembra).
    params.require(:deposito).permit(:nombre, :activo, :orden, :unidad_negocio_id)
  end

  def serialize(d)
    {
      id:                  d.id,
      nombre:              d.nombre,
      clave_sistema:       d.clave_sistema,
      es_sistema:          d.es_sistema,
      activo:              d.activo,
      orden:               d.orden,
      familia:             d.familia,
      unidad_negocio_id:   d.unidad_negocio_id,
      area_nombre:         d.unidad_negocio&.nombre,
      insumos_count:       d.insumos.count,
    }
  end
end
