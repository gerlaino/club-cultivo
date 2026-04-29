# backend/app/controllers/sedes_controller.rb
class SedesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sede, only: [:show, :update, :destroy, :inventario, :agregar_stock, :stock_pendiente, :aprobar_stock, :rechazar_stock]

  def index
    sedes = case current_user.role
            when 'cultivador', 'manicura'
              salas_ids = current_user.salas_ids_asignadas
              sede_ids  = Sala.where(id: salas_ids).pluck(:sede_id).compact.uniq
              current_user.club.sedes.activas.where(id: sede_ids)
            when 'dispensador'
              asignadas = current_user.sedes_asignadas.activas
              asignadas.any? ? asignadas : current_user.club.sedes.activas.where(tipo: %w[social mixta])
            else
              current_user.club.sedes.activas
            end

    render json: sedes.order(:nombre).map { |s| serialize_sede(s) }
  end

  def show
    render json: serialize_sede_detail(@sede)
  end

  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_sede?
      return render json: { error: 'Limite de sedes alcanzado para tu plan', upgrade: true },
                    status: :payment_required
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
    items = @sede.inventarios.includes(:genetica).order(:producto)
    render json: items.map { |i| serialize_inventario(i) }
  end

  def agregar_stock
    genetica_id = params[:genetica_id].presence
    item = if genetica_id
             @sede.inventarios.find_or_initialize_by(genetica_id: genetica_id)
           else
             @sede.inventarios.find_or_initialize_by(producto: params[:producto])
           end

    cantidad       = params[:cantidad].to_f
    stock_anterior = item.stock_gramos.to_f

    item.club              = current_user.club
    item.created_by      ||= current_user
    item.producto          = params[:producto].presence || (genetica_id ? 'flores' : item.producto)
    item.precio_por_unidad = params[:precio_por_unidad].presence&.to_d || item.precio_por_unidad
    item.stock_gramos      = stock_anterior + cantidad

    es_manicurador = current_user.manicura?

    ActiveRecord::Base.transaction do
      item.save!

      if es_manicurador
        # Stock NO se modifica hasta aprobación admin
        InventarioMovimiento.create!(
          sede:            @sede,
          club:            current_user.club,
          sede_inventario: item,
          created_by:      current_user,
          lote_id:         params[:lote_id].presence,
          tipo:            'ingreso',
          cantidad:        cantidad,
          stock_anterior:  stock_anterior,
          stock_nuevo:     stock_anterior,
          estado:          'pendiente',
          motivo:          params[:motivo] || 'Ingreso manicura — pendiente de aprobación'
        )
        item.stock_gramos = stock_anterior
        item.save!
      else
        InventarioMovimiento.create!(
          sede:            @sede,
          club:            current_user.club,
          sede_inventario: item,
          created_by:      current_user,
          lote_id:         params[:lote_id].presence,
          tipo:            'ingreso',
          cantidad:        cantidad,
          stock_anterior:  stock_anterior,
          stock_nuevo:     item.stock_gramos,
          estado:          'aprobado',
          motivo:          params[:motivo] || 'Ingreso manual'
        )
      end
    end

    render json: serialize_inventario(item).merge(pendiente_aprobacion: es_manicurador)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def stock_pendiente
    movimientos = @sede.club.inventario_movimientos
                       .includes(:sede_inventario, :created_by, :lote)
                       .where(estado: 'pendiente', sede_id: @sede.id)
                       .order(created_at: :desc)
    render json: movimientos.map { |m| serialize_movimiento_pendiente(m) }
  end

  def aprobar_stock
    movimiento = @sede.club.inventario_movimientos
                      .where(estado: 'pendiente').find(params[:movimiento_id])

    ActiveRecord::Base.transaction do
      inv = movimiento.sede_inventario
      inv.stock_gramos += movimiento.cantidad
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

  def rechazar_stock
    movimiento = @sede.club.inventario_movimientos
                      .where(estado: 'pendiente').find(params[:movimiento_id])

    movimiento.update!(
      estado:       'rechazado',
      aprobado_por: current_user,
      aprobado_at:  Time.current,
      nota_rechazo: params[:motivo].presence || 'Rechazado por administración'
    )

    render json: { ok: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Movimiento no encontrado' }, status: :not_found
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
    base = {
      id:                  s.id,
      club_id:             s.club_id,
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

    if current_user.cultivador?
      base.merge!(serialize_ops(s))
    end

    base
  end

  def serialize_ops(s)
    salas       = s.salas.includes(lotes: :plants)
    lotes_vivos = salas.flat_map(&:lotes).select { |l| %w[semilla vegetativo floracion cosecha curado].include?(l.estado) }
    plantas_count = lotes_vivos.sum { |l| l.plants.count }

    ciclo = lotes_vivos
              .group_by(&:estado)
              .max_by { |_, arr| arr.length }
              &.first

    tareas_pendientes = Tarea.where(
      club_id: current_user.club_id,
      sala_id: salas.map(&:id),
      estado:  %w[pendiente en_progreso]
    ).count

    tareas_urgentes = Tarea.where(
      club_id:  current_user.club_id,
      sala_id:  salas.map(&:id),
      estado:   %w[pendiente en_progreso],
      prioridad: 'alta'
    ).count

    # Próxima cosecha: lote en floracion con más días acumulados
    proximo_lote = lotes_vivos
                     .select { |l| l.estado == 'floracion' }
                     .min_by { |l| l.start_date }

    dias_para_cosecha = if proximo_lote&.start_date
                          # Floracion típica cannabis: 56 días. Días transcurridos desde start_date del lote.
                          # En producción real esto vendría de genetica.dias_floracion
                          transcurridos = (Date.today - proximo_lote.start_date).to_i
                          restantes = [56 - transcurridos, 0].max
                          restantes > 0 ? restantes : nil
                        end

    {
      ops: {
        plantas_activas:   plantas_count,
        lotes_activos:     lotes_vivos.count,
        ciclo_predominante: ciclo,
        tareas_pendientes: tareas_pendientes,
        tareas_urgentes:   tareas_urgentes,
        dias_para_cosecha: dias_para_cosecha,
        salas:             salas.map { |sala|
          lotes_sala = sala.lotes.select { |l| %w[semilla vegetativo floracion cosecha curado].include?(l.estado) }
          {
            id:     sala.id,
            nombre: sala.nombre,
            state:  sala.state,
            kind:   sala.kind,
            plants_max:    sala.plants_max,
            plantas_count: lotes_sala.sum { |l| l.plants.count },
            lotes_count:   lotes_sala.count,
            lotes:         lotes_sala.map { |l|
              {
                id:         l.id,
                codigo:     l.codigo,
                estado:     l.estado,
                strain:     l.strain,
                start_date: l.start_date,
                plants_count: l.plants.count,
              }
            }
          }
        }
      }
    }
  end

  def serialize_sede_detail(s)
    serialize_sede(s).merge(
      notas:      s.notas,
      created_by: { id: s.created_by.id, nombre: s.created_by.nombre_completo },
      salas:      s.salas.map { |sala| { id: sala.id, nombre: sala.nombre, state: sala.state } }
    )
  end

  def serialize_movimiento_pendiente(m)
    {
      id:             m.id,
      tipo:           m.tipo,
      cantidad:       m.cantidad.to_f,
      motivo:         m.motivo,
      created_at:     m.created_at,
      creado_por: {
        id:     m.created_by.id,
        nombre: m.created_by.nombre_completo,
      },
      sede_inventario: {
        id:             m.sede_inventario.id,
        producto_label: m.sede_inventario.producto_label,
        unidad_medida:  m.sede_inventario.unidad_medida,
      },
      lote: m.lote ? { id: m.lote.id, codigo: m.lote.codigo } : nil,
    }
  end

  def serialize_inventario(i)
    {
      id:                i.id,
      producto:          i.producto_efectivo,
      producto_label:    i.producto_label,
      unidad_medida:     i.unidad_medida,
      stock_gramos:      i.stock_gramos.to_f.round(2),
      stock_minimo:      i.stock_minimo&.to_f,
      stock_bajo:        i.stock_bajo?,
      precio_por_unidad: i.precio_por_unidad&.to_f,
      updated_at:        i.updated_at,
      genetica: i.genetica ? {
        id:     i.genetica.id,
        nombre: i.genetica.nombre,
        tipo:   i.genetica.tipo,
        thc:    i.genetica.thc,
        cbd:    i.genetica.cbd,
      } : nil,
    }
  end
end
