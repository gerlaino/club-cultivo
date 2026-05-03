# backend/app/controllers/salas_controller.rb
class SalasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_salas_role!
  before_action :set_sala, only: [:show, :update, :destroy, :cargar_lote]

  TRANSICIONES_KIND = {
    'secado'   => { desde: 'floracion', hacia: 'cosecha',  label_desde: 'floración',  label_hacia: 'cosecha'  },
    'manicura' => { desde: 'cosecha',   hacia: 'curado',   label_desde: 'cosecha',    label_hacia: 'curado'   },
  }.freeze

  def index
    salas = current_user.club.salas
                        .includes(:sede, :lotes, :created_by)
                        .order(:nombre)

    if current_user.cultivador?
      salas = salas.where(id: current_user.salas_ids_asignadas)
    elsif current_user.supervisor?
      salas = salas.where(sede_id: current_user.sedes_ids_asignadas)
    end

    render json: salas.map { |s| serialize_sala(s) }
  end

  def show
    render json: serialize_sala_detail(@sala)
  end

  def create
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Solo admins y supervisores pueden crear salas' }, status: :forbidden
    end

    sala = current_user.club.salas.build(sala_params)
    sala.created_by = current_user

    if sala.save
      render json: serialize_sala(sala), status: :created
    else
      render json: { errors: sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @sala.update(sala_params)
      render json: serialize_sala_detail(@sala)
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @sala.soft_delete!
    head :no_content
  end

  # POST /salas/:id/cargar_lote
  def cargar_lote
    unless current_user.admin? || current_user.cultivador? || current_user.manicura?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    transicion = TRANSICIONES_KIND[@sala.kind]
    unless transicion
      return render json: { error: "Esta sala (#{@sala.kind}) no acepta carga de lotes" }, status: :unprocessable_entity
    end

    if @sala.kind == 'secado' && current_user.manicura?
      return render json: { error: 'Solo el cultivador puede mover lotes a secado' }, status: :forbidden
    end

    lote = current_user.club.lotes.find(params.require(:lote_id))

    unless lote.estado == transicion[:desde]
      return render json: {
        error: "El lote debe estar en '#{transicion[:label_desde]}' para ingresar a esta sala (estado actual: #{lote.estado})"
      }, status: :unprocessable_entity
    end

    if @sala.tiene_limite_capacidad? && lote.plants_count.to_i > @sala.capacidad_disponible
      return render json: {
        error: "La sala '#{@sala.nombre}' no tiene capacidad para #{lote.plants_count} plantas (disponible: #{@sala.capacidad_disponible} de #{@sala.capacidad_maxima})"
      }, status: :unprocessable_entity
    end

    lote.update!(sala_id: @sala.id, estado: transicion[:hacia])

    render json: {
      message: "Lote #{lote.codigo} cargado correctamente (#{transicion[:label_desde]} → #{transicion[:label_hacia]})",
      lote: { id: lote.id, codigo: lote.codigo, estado: lote.estado, sala_id: lote.sala_id }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def set_sala
    @sala = current_user.club.salas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def require_salas_role!
    blocked = %w[auditor abogado paciente]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def sala_params
    params.require(:sala).permit(
      :nombre, :state, :kind, :notes, :pots_count, :plants_max, :sede_id
    )
  end

  def serialize_sala(s)
    {
      id:                   s.id,
      club_id:              s.club_id,
      nombre:               s.nombre,
      tipo:                 s.tipo,
      state:                s.state,
      kind:                 s.kind,
      notes:                s.notes,
      pots_count:           s.pots_count,
      plants_max:           s.plants_max,
      plantas_totales:      s.plantas_totales,
      capacidad_disponible: s.tiene_limite_capacidad? ? s.capacidad_disponible : nil,
      porcentaje_ocupacion: s.porcentaje_ocupacion,
      lotes_count:          s.lotes.count,
      sede: s.sede ? { id: s.sede.id, nombre: s.sede.nombre, tipo: s.sede.tipo } : nil,
      created_at:           s.created_at,
      created_by_name:      s.created_by_name,
      lotes_activos:        s.lotes.where(estado: ['vegetativo','floracion']).count,
      updated_at:           s.updated_at,
      cultivadores: s.cultivadores.map { |c| { id: c.id, nombre: c.nombre_completo } },
    }
  end

  def serialize_sala_detail(s)
    serialize_sala(s).merge(
      lotes: s.lotes.order(created_at: :desc).map { |l|
        { id: l.id, codigo: l.codigo, estado: l.estado, plants_count: l.plants_count }
      }
    )
  end
end
