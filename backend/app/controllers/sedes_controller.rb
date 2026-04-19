# backend/app/controllers/sedes_controller.rb
class SedesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sede, only: [:show, :update, :destroy, :inventario, :agregar_stock]

  def index
    sedes = case current_user.role
            when 'cultivador'
              salas_ids = current_user.salas_ids_asignadas
              sede_ids  = Sala.where(id: salas_ids).pluck(:sede_id).compact.uniq
              current_user.club.sedes.activas.where(id: sede_ids)
            when 'agricultor'
              asignadas = current_user.sedes_asignadas.activas
              asignadas = current_user.club.sedes.activas.produccion if asignadas.empty?
              asignadas
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
    items = @sede.inventarios.order(:producto)
    render json: items.map { |i| serialize_inventario(i) }
  end

  def agregar_stock
    item = @sede.inventarios.find_or_initialize_by(
      producto: params[:producto],
      lote_id:  params[:lote_id].presence
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
        lote_id:         params[:lote_id].presence,
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
    base = {
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

    if current_user.agricultor?
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

  def serialize_inventario(i)
    lote_data = if i.lote
                  {
                    id:       i.lote.id,
                    codigo:   i.lote.codigo,
                    estado:   i.lote.estado,
                    strain:   i.lote.strain,
                    genetica: i.lote.genetica&.nombre,
                    sala:     i.lote.sala&.nombre,
                  }
                end
    {
      id:             i.id,
      producto:       i.producto,
      producto_label: i.producto_label,
      stock_gramos:   i.stock_gramos,
      stock_minimo:   i.stock_minimo,
      stock_bajo:     i.stock_bajo?,
      updated_at:     i.updated_at,
      lote:           lote_data,
    }
  end
end
