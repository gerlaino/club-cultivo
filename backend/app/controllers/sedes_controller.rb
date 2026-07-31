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

  # Estados de LOTE que cuentan como "vivo" en la sede: los de cultivo más los post-cosecha que
  # todavía tienen material. El enraizado cuenta — es la fase más frágil, no la que hay que ocultar.
  LOTE_ESTADOS_VIVOS = (Lote::CULTIVO_ESTADOS + %w[cosecha curado]).freeze

  def serialize_ops(s)
    salas       = s.salas.includes(lotes: :plants)
    lotes_vivos = salas.flat_map(&:lotes).select { |l| LOTE_ESTADOS_VIVOS.include?(l.estado) }
    plantas_count = lotes_vivos.sum { |l| l.plants.count }

    # Desglose de plantas POR FASE. Un total de plantas no dice nada: 800 plantas es un número muy
    # distinto si son 700 esquejes que si son 700 en floración —cambia el consumo, el riego, el
    # espacio y lo que vas a cosechar—. Se cuenta por el estado de la PLANTA, no del lote, porque
    # dentro de un lote conviven plantas en distinto estado (cosecha parcial, descartes).
    plantas_por_fase = Plant.where(lote_id: lotes_vivos.map(&:id))
                            .where.not(state: 'descartada')
                            .group(:state).count
    fases = {
      enraizado:   plantas_por_fase['enraizado'].to_i,
      vegetativo:  plantas_por_fase['vegetativo'].to_i,
      floracion:   plantas_por_fase['floracion'].to_i,
      cosechadas:  plantas_por_fase['cosechado'].to_i + plantas_por_fase['secado'].to_i,
    }

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
                     # El más avanzado del ciclo, que arranca en vegetativo (un lote que tardó en
                     # enraizar tiene start_date viejo pero ciclo corto).
                     .min_by { |l| l.fecha_inicio_vegetativo || l.start_date || Date.current }

    # El ciclo objetivo es vege + floración, así que se cuenta desde que ENTRÓ A VEGETATIVO. Medido
    # desde start_date se le sumaban los días de enraizado, que no son parte del ciclo.
    inicio_ciclo = proximo_lote&.fecha_inicio_vegetativo
    dias_para_cosecha = if inicio_ciclo
                          # Ciclo objetivo del lote (vege + floración), heredado de la genética al
                          # crear el lote. Fallback ~77d (≈21 vege + 56 flora) si el lote no tiene
                          # objetivos cargados. Restantes = ciclo objetivo − días transcurridos.
                          ciclo_objetivo = proximo_lote.dias_vegetativo_objetivo.to_i + proximo_lote.dias_floracion_objetivo.to_i
                          ciclo_objetivo = 77 if ciclo_objetivo <= 0
                          restantes = ciclo_objetivo - (Date.today - inicio_ciclo).to_i
                          restantes.positive? ? restantes : nil
                        end

    {
      ops: {
        plantas_activas:   plantas_count,
        plantas_por_fase:  fases,
        lotes_activos:     lotes_vivos.count,
        ciclo_predominante: ciclo,
        tareas_pendientes: tareas_pendientes,
        tareas_urgentes:   tareas_urgentes,
        dias_para_cosecha: dias_para_cosecha,
        salas:             salas.map { |sala|
          lotes_sala = sala.lotes.select { |l| LOTE_ESTADOS_VIVOS.include?(l.estado) }
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
