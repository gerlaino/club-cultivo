# backend/app/controllers/sedes_controller.rb
class SedesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sede, only: [:show, :update, :destroy]

  def index
    sedes = current_user.club.sedes.activas.includes(:created_by).order(:nombre)
    render json: sedes.map { |s| serialize_sede(s) }
  end

  def show
    render json: serialize_sede_detail(@sede)
  end

  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_sede?
      return render json: {
        error: 'Limite de sedes alcanzado para tu plan',
        upgrade: true
      }, status: :payment_required
    end

    sede = current_user.club.sedes.build(sede_params)
    sede.created_by = current_user

    if sede.save
      render json: serialize_sede(sede), status: :created
    else
      render json: { errors: sede.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @sede.update(sede_params)
      render json: serialize_sede(@sede)
    else
      render json: { errors: @sede.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @sede.salas.where(state: 'activa').any?
      return render json: { error: 'No se puede eliminar una sede con salas activas' },
                    status: :unprocessable_entity
    end
    @sede.destroy
    head :no_content
  end

  def inventario
    items = @sede.inventarios.order(:producto)
    render json: items.map { |i| serialize_inventario(i) }
  end

  def agregar_stock
    item = @sede.inventarios.find_or_initialize_by(
      producto: params[:producto],
      lote_id:  params[:lote_id]
    )
    cantidad       = params[:cantidad].to_f
    stock_anterior = item.stock_gramos.to_f
    item.club       = current_user.club
    item.created_by ||= current_user
    item.stock_gramos = stock_anterior + cantidad

    if item.save
      InventarioMovimiento.create!(
        sede:            @sede,
        club:            current_user.club,
        sede_inventario: item,
        created_by:      current_user,
        tipo:            'ingreso',
        cantidad:        cantidad,
        stock_anterior:  stock_anterior,
        stock_nuevo:     item.stock_gramos,
        motivo:          params[:motivo] || 'Ingreso manual'
      )
      render json: serialize_inventario(item)
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_sede
    @sede = current_user.club.sedes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sede no encontrada' }, status: :not_found
  end

  def sede_params
    params.require(:sede).permit(
      :nombre, :tipo, :direccion, :ciudad, :provincia, :pais,
      :activa, :declarada_reprocann, :notas
    )
  end

  def serialize_sede(s)
    {
      id:                  s.id,
      nombre:              s.nombre,
      tipo:                s.tipo,
      tipo_label:          s.tipo_label,
      direccion:           s.direccion,
      ciudad:              s.ciudad,
      provincia:           s.provincia,
      pais:                s.pais,
      direccion_completa:  [s.direccion, s.ciudad, s.provincia, s.pais].compact.reject(&:empty?).join(', '),
      activa:              s.activa,
      declarada_reprocann: s.declarada_reprocann,
      salas_count:         s.salas.count,
      created_at:          s.created_at,
    }
  end

  def serialize_sede_detail(s)
    serialize_sede(s).merge(
      notas:      s.notas,
      created_by: { id: s.created_by.id, nombre: "#{s.created_by.first_name} #{s.created_by.last_name}".strip },
      salas:      s.salas.map { |sala| { id: sala.id, nombre: sala.nombre, state: sala.state } },
      )
  end

  def serialize_inventario(i)
    {
      id:            i.id,
      producto:      i.producto,
      producto_label: i.producto_label,
      stock_gramos:  i.stock_gramos,
      stock_minimo:  i.stock_minimo,
      stock_bajo:    i.stock_bajo?,
      updated_at:    i.updated_at,
    }
  end
end
