class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_cultivador_o_manicura
  before_action :set_lote, only: [:show, :update, :destroy, :transiciones, :cerrar_curado, :timeline]
  before_action :set_sala, only: [:index, :create], if: -> { params[:sala_id].present? }

  # GET /lotes o GET /salas/:sala_id/lotes
  def index
    lotes = current_user.club.lotes.includes(:genetica, sala: :sede)
    lotes = lotes.where(sala_id: @sala.id) if @sala.present?

    if current_user.cultivador?
      salas_ids = current_user.salas_ids_asignadas
      return render json: [] if salas_ids.empty?
      lotes = lotes.where(sala_id: salas_ids)
    end

    if current_user.manicura?
      salas_ids = current_user.salas_ids_asignadas
      return render json: [] if salas_ids.empty?
      lotes = lotes.where(sala_id: salas_ids, estado: %w[cosecha curado])
    elsif params[:manicura].present?
      lotes = lotes.where(estado: %w[cosecha curado])
    end

    lotes = lotes.where(estado: params[:estado]) if params[:estado].present?
    lotes = lotes.order(created_at: :desc)
    render json: lotes.map { |l| serialize_lote(l) }
  end

  # GET /lotes/:id
  def show
    render json: serialize_lote(@lote, include_plants: true, include_cycle_data: true)
  end

  # POST /salas/:sala_id/lotes
  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_lote?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('lotes', info[:limites][:lotes]), status: :payment_required
    end

    @lote = @sala.lotes.build(lote_params)
    @lote.club = current_user.club

    plantas_iniciales = lote_params[:plants_count].to_i
    if plantas_iniciales > 0 && @sala.tiene_limite_capacidad?
      disponible = @sala.capacidad_disponible
      if plantas_iniciales > disponible
        return render json: {
          errors: ["La sala '#{@sala.nombre}' solo tiene capacidad para #{disponible} plantas más (máx: #{@sala.capacidad_maxima})"]
        }, status: :unprocessable_entity
      end
    end

    if plantas_iniciales > 0
      enforcer2 = PlanEnforcer.new(current_user.club)
      unless enforcer2.puede_crear_planta_bulk?(plantas_iniciales)
        info = enforcer2.info
        restantes = (info[:limites][:plantas] || 0) - info[:uso][:plantas]
        return render json: {
          error: 'limite_plan',
          mensaje: "Tu plan solo permite #{restantes} plantas más (límite: #{info[:limites][:plantas]})",
          upgrade: true,
        }, status: :payment_required
      end
    end

    if @lote.save
      # Crear registros de plantas automáticamente
      if plantas_iniciales > 0
        state_inicial = estado_a_state(@lote.estado)
        plantas_iniciales.times do |i|
          numero = (i + 1).to_s.rjust(3, '0')
          @lote.plants.create!(
            nombre:    "#{@lote.codigo}-P#{numero}",
            state:     state_inicial,
            genetica:  @lote.genetica,
            )
        end
      end

      render json: serialize_lote(@lote, include_plants: true), status: :created
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /lotes/:id
  def update
    if lote_params[:plants_count].present?
      nuevas   = lote_params[:plants_count].to_i
      actuales = @lote.plants_count.to_i
      delta    = nuevas - actuales
      if delta > 0 && @lote.sala.tiene_limite_capacidad?
        disponible = @lote.sala.capacidad_disponible
        if delta > disponible
          return render json: {
            errors: ["La sala '#{@lote.sala.nombre}' solo tiene capacidad para #{disponible} plantas más (máx: #{@lote.sala.capacidad_maxima})"]
          }, status: :unprocessable_entity
        end
      end
    end
    if @lote.update(lote_params)
      render json: serialize_lote(@lote)
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /lotes/:id
  def destroy
    @lote.destroy
    head :no_content
  end

  # POST /lotes/:id/transiciones
  def transiciones
    pesada_attrs   = (params[:pesada] || {}).to_unsafe_h.symbolize_keys
    pesadas_plantas = (params[:pesadas_plantas] || []).map { |p| p.to_unsafe_h.symbolize_keys }
    pesada_attrs[:registrado_por] = current_user

    @lote.transicionar!(
      params[:nueva_fase],
      pesada_attrs:          pesada_attrs,
      manicurado:            pesada_attrs.delete(:manicurado).in?([true, 'true', '1']),
      pesadas_plantas_attrs: pesadas_plantas
    )

    render json: serialize_lote(@lote.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/cerrar_curado
  def cerrar_curado
    splitter = params[:splitter]&.to_unsafe_h&.symbolize_keys || {}

    stock = @lote.cerrar_curado!(
      splitter:            splitter,
      sede_destino_id:     params[:sede_destino_id],
      costo_unitario_ars:  params[:costo_unitario_ars],
      precio_sugerido_ars: params[:precio_sugerido_ars],
      registrado_por:      current_user,
      peso_curado_g:       params[:peso_curado_g],
    )

    render json: { lote: serialize_lote(@lote.reload), stock: serialize_stock_inline(stock) }, status: :created
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # GET /lotes/:id/timeline
  def timeline
    pesadas = @lote.pesadas.includes(:registrado_por, pesadas_plantas: :plant).order(registrado_at: :asc)
    stocks  = @lote.stocks.includes(:sede).order(created_at: :asc)
    dispensaciones = Dispensacion.joins(:stock).where(stocks: { lote_id: @lote.id }).includes(:paciente, :stock).recientes

    render json: {
      lote:          serialize_lote(@lote, include_cycle_data: true),
      pesadas:       pesadas.map { |p| serialize_pesada(p) },
      stocks:        stocks.map  { |s| serialize_stock_inline(s) },
      dispensaciones: dispensaciones.map { |d|
        { id: d.id, socio: "#{d.socio.nombre} #{d.socio.apellido}", fecha: d.fecha_dispensacion,
          cantidad: d.cantidad.to_f, unidad: d.stock&.unidad, forma_producto: d.stock&.forma_producto }
      },
    }
  end

  private

  def estado_a_state(estado)
    {
      'semilla'    => 'germinacion',
      'vegetativo' => 'vegetativo',
      'floracion'  => 'floracion',
      'cosecha'    => 'cosechado',
      'curado'     => 'cosechado',
      'finalizado' => 'cosechado',
    }[estado] || 'vegetativo'
  end

  def set_sala
    @sala = current_user.club.salas.find(params[:sala_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def set_lote
    @lote = current_user.club.lotes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def lote_params
    params.require(:lote).permit(
      :codigo, :start_date, :estado, :plants_count, :strain, :notes,
      :grow_type, :light_type, :genetica_id
    )
  end

  def serialize_pesada(p)
    {
      id:           p.id,
      fase_origen:  p.fase_origen,
      fase_destino: p.fase_destino,
      peso_humedo_g: p.peso_humedo_g&.to_f,
      peso_seco_g:   p.peso_seco_g&.to_f,
      peso_curado_g: p.peso_curado_g&.to_f,
      manicurado:    p.manicurado,
      notas:         p.notas,
      registrado_por: p.registrado_por&.first_name,
      registrado_at:  p.registrado_at,
      merma_porcentual: p.merma_porcentual,
      pesadas_plantas: p.pesadas_plantas.map { |pp|
        { plant_id: pp.plant_id, nombre: pp.plant.nombre,
          peso_humedo_g: pp.peso_humedo_g&.to_f, peso_seco_g: pp.peso_seco_g&.to_f }
      },
    }
  end

  def serialize_stock_inline(s)
    { id: s.id, origen: s.origen, forma_producto: s.forma_producto,
      unidad: s.unidad, cantidad: s.cantidad.to_f,
      precio_sugerido_ars: s.precio_sugerido_ars&.to_f, sede_id: s.sede_id }
  end

  def require_admin_cultivador_o_manicura
    unless current_user.admin? || current_user.cultivador? || current_user.manicura? || current_user.auditor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def serialize_lote(lote, include_plants: false, include_cycle_data: false)
    idx_ciclo        = Lote::CICLO_FASES.index(lote.estado)
    proxima_fase     = idx_ciclo ? Lote::CICLO_FASES[idx_ciclo + 1] : nil
    puede_transicion = idx_ciclo.present? && idx_ciclo < Lote::CICLO_FASES.length - 1

    result = {
      id:                   lote.id,
      club_id:              lote.club_id,
      sala_id:              lote.sala_id,
      codigo:               lote.codigo,
      estado:               lote.estado,
      fase:                 lote.estado,
      proxima_fase_posible: proxima_fase,
      puede_transicionar:   puede_transicion,
      puede_cerrar_curado:  lote.estado == 'curado',
      start_date:           lote.start_date,
      plants_count:         lote.plants_count,
      plantas_seleccion_count: lote.plants.where(es_seleccion: true).count,
      strain:            lote.strain,
      notes:             lote.notes,
      grow_type:         lote.grow_type,
      light_type:        lote.light_type,
      genetica_id:       lote.genetica_id,
      genetica:          lote.genetica ? { id: lote.genetica.id, nombre: lote.genetica.nombre, registrada_inase: lote.genetica.registrada_inase } : nil,
      dias_desde_inicio: lote.dias_desde_inicio,
      progreso_ciclo:    lote.progreso_ciclo,
      costo_por_gramo:   lote.costo_lote&.costo_por_gramo&.to_f,
      tiene_costo:       lote.costo_lote.present?,
      sala: {
        id:     lote.sala.id,
        nombre: lote.sala.nombre,
        tipo:   lote.sala.tipo,
        sede:   { id: lote.sala.sede_id, nombre: lote.sala.sede.nombre },
      },
      created_at: lote.created_at,
      updated_at: lote.updated_at,
    }

    if include_cycle_data
      result[:pesadas] = lote.pesadas.includes(:registrado_por, pesadas_plantas: :plant).map { |p| serialize_pesada(p) }
      result[:stocks]  = lote.stocks.includes(:sede).map { |s| serialize_stock_inline(s) }
    end

    if include_plants
      result[:plants] = lote.plants.order(:nombre).map { |p|
        { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, state: p.state, es_seleccion: p.es_seleccion }
      }
    end

    result
  end
end


