class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_cultivador_o_manicura
  before_action :set_lote, only: [:show, :update, :destroy, :transiciones, :cerrar_curado, :avanzar_fase, :timeline, :aprobar_manicura, :rechazar_manicura]
  before_action :set_sala, only: [:index, :create], if: -> { params[:sala_id].present? }

  # GET /lotes o GET /salas/:sala_id/lotes
  def index
    lotes = current_user.club.lotes.includes(:genetica, :costo_lote, sala: :sede)
    lotes = lotes.where(sala_id: @sala.id) if @sala.present?

    if current_user.cultivador?
      salas_ids = current_user.salas_ids_asignadas
      return render json: [] if salas_ids.empty?
      lotes = lotes.where(sala_id: salas_ids)
    end

    if current_user.manicura?
      manicura_estados = %w[secado manicura_pendiente]
      if params[:estado].present?
        lotes = manicura_estados.include?(params[:estado]) ? lotes.where(estado: params[:estado]) : lotes.none
      else
        lotes = lotes.where(estado: manicura_estados)
      end
    elsif params[:manicura].present?
      lotes = lotes.where(estado: %w[cosecha secado curado])
    else
      lotes = lotes.where(estado: params[:estado]) if params[:estado].present?
    end
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
    pesada_attrs    = (params[:pesada] || {}).to_unsafe_h.symbolize_keys
    pesadas_plantas = (params[:pesadas_plantas] || []).map { |p| p.to_unsafe_h.symbolize_keys }
    pesada_attrs[:registrado_por] = current_user
    manicurado = pesada_attrs.delete(:manicurado).in?([true, 'true', '1'])
    nueva_fase = params[:nueva_fase]

    # Manicura pesa un lote en secado → va a manicura_pendiente, no a curado
    if manicurado && @lote.estado == 'secado' && current_user.manicura?
      ActiveRecord::Base.transaction do
        pesada = @lote.pesadas.create!(
          fase_origen:    'secado',
          fase_destino:   'manicura_pendiente',
          manicurado:     true,
          registrado_por: current_user,
          registrado_at:  Time.current,
          notas:          pesada_attrs[:notas],
          peso_seco_g:    pesada_attrs[:peso_seco_g],
          peso_humedo_g:  pesada_attrs[:peso_humedo_g],
        )
        @lote.update!(estado: 'manicura_pendiente')
        AlertaInterna.create!(
          club:             current_user.club,
          tipo:             'manicura_aprobacion_pendiente',
          mensaje:          "Manicura #{current_user.first_name} completó lote #{@lote.codigo} — pendiente aprobación admin (#{pesada_attrs[:peso_seco_g]}g)",
          severidad:        'info',
          creada_por:       current_user,
          destinada_a_role: 'admin',
          contexto:         { lote_id: @lote.id, lote_codigo: @lote.codigo,
                              peso_seco_g: pesada_attrs[:peso_seco_g], manicura_id: current_user.id }
        )
      end
      return render json: serialize_lote(@lote.reload), status: :created
    end

    @lote.transicionar!(
      nueva_fase,
      pesada_attrs:          pesada_attrs,
      manicurado:            manicurado,
      pesadas_plantas_attrs: pesadas_plantas
    )

    render json: serialize_lote(@lote.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/aprobar_manicura
  def aprobar_manicura
    authorize @lote, :aprobar_manicura?
    @lote.aprobar_manicura!(aprobado_por: current_user, observaciones: params[:observaciones])
    render json: serialize_lote(@lote.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/rechazar_manicura
  def rechazar_manicura
    authorize @lote, :rechazar_manicura?
    @lote.rechazar_manicura!(rechazado_por: current_user, motivo: params.require(:motivo))
    render json: serialize_lote(@lote.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/cerrar_curado
  # Formato nuevo: { pesada: {tipo, cantidad_g, mermas_g}, stocks: [{sede_id, forma_producto, ...}] }
  # Formato legacy: { splitter:, sede_destino_id:, ... }
  def cerrar_curado
    authorize @lote, :cerrar_curado?
    if params[:stocks].present?
      cerrar_curado_con_stocks
    else
      cerrar_curado_legacy
    end
  end

  # POST /lotes/:id/avanzar_fase
  def avanzar_fase
    authorize @lote, :avanzar_fase?
    @lote.avanzar_fase!
    render json: serialize_lote(@lote.reload)
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
    scope = current_user.club.lotes
    scope = scope.where(estado: %w[secado manicura_pendiente]) if current_user.manicura?
    @lote = scope.find(params[:id])
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
      id:               p.id,
      fase_origen:      p.fase_origen,
      fase_destino:     p.fase_destino,
      peso_humedo_g:    p.peso_humedo_g&.to_f,
      peso_seco_g:      p.peso_seco_g&.to_f,
      peso_curado_g:    p.peso_curado_g&.to_f,
      manicurado:       p.manicurado,
      notas:            p.notas,
      registrado_por:   p.registrado_por&.first_name,
      registrado_at:    p.registrado_at,
      merma_porcentual: p.merma_porcentual,
      aprobada_at:      p.aprobada_at,
      aprobada_por:     p.aprobada_por&.first_name,
      rechazada_at:     p.rechazada_at,
      motivo_rechazo:   p.motivo_rechazo,
      pesadas_plantas:  p.pesadas_plantas.map { |pp|
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

  def cerrar_curado_con_stocks
    raise RuntimeError, 'El lote no está en curado' unless @lote.estado == 'curado'

    pesada_data   = params.require(:pesada).permit(:fase_origen, :fase_destino, :peso_curado_g, :notas)
    stocks_params = params[:stocks].map { |s| s.permit(:sede_id, :forma_producto, :cantidad, :unidad, :precio_sugerido_ars) }

    peso_curado_g = pesada_data[:peso_curado_g].to_d
    total_stock   = stocks_params.sum { |s| s[:cantidad].to_d }

    if total_stock > peso_curado_g
      return render json: { error: "Stocks generados (#{total_stock}g) exceden peso curado disponible (#{peso_curado_g}g)" },
                    status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      pesada = @lote.pesadas.create!(
        fase_origen:   pesada_data[:fase_origen]  || 'curado',
        fase_destino:  pesada_data[:fase_destino] || 'finalizado',
        peso_curado_g: peso_curado_g,
        notas:         pesada_data[:notas],
        registrado_por: current_user,
        registrado_at:  Time.current,
      )

      stocks_creados = stocks_params.map do |sp|
        sede = current_user.club.sedes.find(sp[:sede_id])
        Stock.create!(
          sede:               sede,
          lote:               @lote,
          origen:             'lote',
          forma_producto:     sp[:forma_producto],
          cantidad:           sp[:cantidad].to_d,
          unidad:             sp[:unidad] || 'g',
          precio_sugerido_ars: sp[:precio_sugerido_ars],
        )
      end

      @lote.update!(estado: 'finalizado')

      render json: {
        lote:    serialize_lote(@lote.reload),
        pesada:  serialize_pesada(pesada),
        stocks:  stocks_creados.map { |s| serialize_stock_inline(s) },
      }, status: :created
    end
  rescue RuntimeError, ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def cerrar_curado_legacy
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

  def require_admin_cultivador_o_manicura
    unless current_user.admin? || current_user.cultivador? || current_user.manicura?
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
      puede_cerrar_curado:       lote.estado == 'curado',
      puede_aprobar_manicura:    lote.estado == 'manicura_pendiente',
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
      costo_total:       lote.costo_lote&.costo_total&.to_f,
      gramos_producidos: lote.costo_lote&.gramos_producidos&.to_f,
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


