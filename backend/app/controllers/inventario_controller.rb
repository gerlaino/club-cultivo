class InventarioController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_o_agricultor, only: [:pendiente, :aprobar, :rechazar]

  # GET /inventario/pendiente
  # Todos los movimientos pendientes del club para panel admin
  def pendiente
    movs = current_user.club.inventario_movimientos
                       .includes(:sede_inventario, :created_by, :lote, :sede)
                       .where(estado: 'pendiente')
                       .order(created_at: :asc)
    render json: movs.map { |m| serialize_mov(m) }
  end

  # GET /inventario/disponible
  # Stock de sedes social/mixta para dispensación (sin seleccionar sede)
  def disponible
    items = SedeInventario.joins(:sede)
                          .where(club: current_user.club)
                          .where(sedes: { tipo: %w[social mixta], activa: true })
                          .where('sede_inventarios.stock_gramos > 0')
                          .includes(:genetica, :sede)
                          .order('sede_inventarios.producto')
    render json: items.map { |i| serialize_item(i) }
  end

  # POST /inventario/aprobar/:id
  def aprobar
    movimiento = current_user.club.inventario_movimientos
                             .where(estado: 'pendiente')
                             .find(params[:id])
    ActiveRecord::Base.transaction do
      inv = movimiento.sede_inventario
      inv.stock_gramos        += movimiento.cantidad
      movimiento.stock_nuevo   = inv.stock_gramos
      movimiento.estado        = 'aprobado'
      movimiento.aprobado_por  = current_user
      movimiento.aprobado_at   = Time.current
      inv.save!
      movimiento.save!
    end
    render json: { ok: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Movimiento no encontrado' }, status: :not_found
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # POST /inventario/rechazar/:id
  def rechazar
    movimiento = current_user.club.inventario_movimientos
                             .where(estado: 'pendiente')
                             .find(params[:id])
    movimiento.update!(
      estado:       'rechazado',
      aprobado_por: current_user,
      aprobado_at:  Time.current,
      nota_rechazo: params[:motivo].presence || 'Rechazado por administración',
    )
    render json: { ok: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Movimiento no encontrado' }, status: :not_found
  end

  private

  def require_admin_o_agricultor
    unless current_user.admin? || current_user.agricultor?
      render json: { error: 'Sin permiso' }, status: :forbidden
    end
  end

  def serialize_mov(m)
    inv = m.sede_inventario
    {
      id:              m.id,
      cantidad:        m.cantidad.to_f,
      estado:          m.estado,
      motivo:          m.motivo,
      nota_rechazo:    m.nota_rechazo,
      created_at:      m.created_at,
      aprobado_at:     m.aprobado_at,
      aprobado_por:    m.aprobado_por ? { id: m.aprobado_por_id, nombre: m.aprobado_por.nombre_completo } : nil,
      created_by:      { id: m.created_by.id, nombre: m.created_by.nombre_completo },
      lote_codigo:     m.lote&.codigo,
      genetica_nombre: inv&.genetica&.nombre || inv&.producto,
      sede:            { id: m.sede.id, nombre: m.sede.nombre },
    }
  end

  def serialize_item(i)
    {
      id:                i.id,
      producto:          i.producto,
      producto_label:    i.producto_label,
      stock_gramos:      i.stock_gramos.to_f,
      stock_bajo:        i.stock_bajo?,
      precio_por_unidad: i.precio_por_unidad&.to_f,
      unidad_medida:     i.unidad_medida,
      sede:              { id: i.sede.id, nombre: i.sede.nombre },
      genetica: i.genetica ? {
        id:     i.genetica.id,
        nombre: i.genetica.nombre,
        tipo:   i.genetica.tipo,
        thc:    i.genetica.thc&.to_f,
        cbd:    i.genetica.cbd&.to_f,
      } : nil,
    }
  end
end
