# backend/app/controllers/sedes_controller.rb
class SedesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_sedes_role!
  before_action :set_sede, only: [:show, :update, :destroy]

  def index
    sedes = case current_user.role
            when 'cultivador'
              current_user.sedes_asignadas.activas
            when 'manicura'
              salas_ids = current_user.salas_ids_asignadas
              sede_ids  = Sala.where(id: salas_ids).pluck(:sede_id).compact.uniq
              current_user.club.sedes.activas.where(id: sede_ids)
            when 'supervisor'
              current_user.sedes_asignadas.activas
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

  # GET /sedes/resumen_financiero — rentabilidad del mes + capital inmovilizado por sede.
  # Solo admin/supervisor (visibilidad financiera).
  def resumen_financiero
    unless %w[admin supervisor].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    render json: Sedes::ResumenFinanciero.new(current_user.club).call
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
      # Multi-sede: la sede nueva estrena sus depósitos del sistema (General, y Cultivo/Salón/
      # Dispensario según su tipo). Idempotente.
      Finanzas::SembrarDepositos.new(current_user.club).call
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
    if current_user.club.sedes.count <= 1
      return render json: { error: 'No se puede eliminar la única sede del club' }, status: :unprocessable_entity
    end
    @sede.soft_delete!
    head :no_content
  end

  private

  def set_sede
    @sede = current_user.club.sedes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sede no encontrada' }, status: :not_found
  end

  def require_sedes_role!
    blocked = %w[auditor abogado paciente]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
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
      salas_count:         s.salas.cultivo.count,
      created_at:          s.created_at,
    }

    if current_user.cultivador?
      base.merge!(serialize_ops(s))
    end

    base
  end

  def serialize_ops(s)
    salas       = s.salas.includes(lotes: :plants)
    lotes_vivos = salas.flat_map(&:lotes).select { |l| %w[germinacion vegetativo floracion cosecha curado].include?(l.estado) }
    plantas_count = lotes_vivos.sum { |l| l.plants.count }

    ciclo = lotes_vivos
              .group_by(&:estado)
              .max_by { |_, arr| arr.length }
              &.first

    tareas_pendientes = Tarea.where(
      club_id: current_user.club_id,
      sala_id: salas.map(&:id),
      estado:  %w[pendiente en_progreso]
    ).where('fecha_programada <= ? OR fecha_programada IS NULL', Time.zone.today).count

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
                          # Ciclo objetivo del lote (vege + floración), heredado de la genética al
                          # crear el lote. Fallback ~77d (≈21 vege + 56 flora) si el lote no tiene
                          # objetivos cargados. Restantes = ciclo objetivo − días transcurridos.
                          ciclo_objetivo = proximo_lote.dias_vegetativo_objetivo.to_i + proximo_lote.dias_floracion_objetivo.to_i
                          ciclo_objetivo = 77 if ciclo_objetivo <= 0
                          restantes = ciclo_objetivo - (Date.today - proximo_lote.start_date).to_i
                          restantes.positive? ? restantes : nil
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
          lotes_sala = sala.lotes.select { |l| %w[germinacion vegetativo floracion cosecha curado].include?(l.estado) }
          {
            id:     sala.id,
            nombre: sala.nombre,
            state:  sala.state,
            kind:   sala.kind,
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

end
