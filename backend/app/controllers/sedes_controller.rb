# backend/app/controllers/sedes_controller.rb
class SedesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sede, only: [:show, :update, :destroy]

  # GET /sedes
  def index
    sedes = current_user.club.sedes.activas.includes(:created_by).order(:nombre)
    render json: sedes.map { |s| serialize_sede(s) }
  end

  # GET /sedes/:id
  def show
    render json: serialize_sede_detail(@sede)
  end

  # POST /sedes
  def create
    enforcer = PlanEnforcer.para(current_user.club)
    unless enforcer.puede_crear_sede?
      return render json: {
        error:       'Límite de sedes alcanzado para tu plan',
        plan:        current_user.club.plan,
        upgrade_url: '/preferencias#plan'
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

  # PATCH /sedes/:id
  def update
    if @sede.update(sede_params)
      render json: serialize_sede_detail(@sede)
    else
      render json: { errors: @sede.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /sedes/:id  →  soft delete
  def destroy
    @sede.update(activa: false)
    head :no_content
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
      id:                   s.id,
      nombre:               s.nombre,
      tipo:                 s.tipo,
      tipo_label:           s.tipo_label,
      direccion:            s.direccion,
      ciudad:               s.ciudad,
      provincia:            s.provincia,
      pais:                 s.pais,
      activa:               s.activa,
      declarada_reprocann:  s.declarada_reprocann,
      salas_count:          s.salas.count,
      created_at:           s.created_at,
    }
  end

  def serialize_sede_detail(s)
    serialize_sede(s).merge(
      notas:      s.notas,
      created_by: { id: s.created_by.id, nombre: "#{s.created_by.first_name} #{s.created_by.last_name}".strip },
      salas:      s.salas.map { |sala| { id: sala.id, nombre: sala.nombre, state: sala.state } },
      inventario: s.inventario_items.activos.map { |i| { id: i.id, nombre: i.nombre, tipo_producto: i.tipo_producto, stock_gramos: i.stock_gramos } },
      )
  end
end
