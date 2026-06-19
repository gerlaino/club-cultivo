class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_cultivador_o_manicura
  before_action :set_lote, only: [:show, :update, :completar_datos, :destroy, :transiciones, :cerrar_curado, :avanzar_fase, :cosechar_plantas, :timeline, :aprobar_manicura, :rechazar_manicura, :asignar_manicurador, :completar_manicura, :finalizar_pesaje_manicura]
  before_action :require_export_role!, only: [:export_csv]
  before_action :set_sala, only: [:index, :create], if: -> { params[:sala_id].present? }

  # GET /lotes o GET /salas/:sala_id/lotes
  def index
    lotes = current_user.club.lotes.includes(:costo_lote, :pesadas, :lote_eventos, sala: :sede, genetica: { fotos_attachments: :blob })
    lotes = lotes.where(sala_id: @sala.id) if @sala.present?

    if current_user.cultivador?
      salas_ids = current_user.salas_ids_asignadas
      salas_ids = current_user.club.salas.where(kind: %w[vegetativo floracion]).ids if salas_ids.empty?
      if params[:cosechados].present?
        mis_lotes_cosechados = LoteEvento.where(
          club_id:      current_user.club_id,
          user_id:      current_user.id,
          estado_nuevo: 'cosecha'
        ).select(:lote_id)
        lotes = lotes.where(sala_id: salas_ids).or(lotes.where(id: mis_lotes_cosechados))
      else
        # El cultivador ve solo lotes EN CULTIVO. Aunque por datos viejos un lote en
        # manicura conserve una sala de veg/flor, se filtra por estado para no colarse.
        lotes = lotes.where(sala_id: salas_ids)
                     .where(estado: %w[semilla esqueje vegetativo floracion])
      end
    elsif current_user.supervisor?
      salas_ids = current_user.salas_ids_en_sedes_asignadas
      lotes = lotes.where(sala_id: salas_ids)
    end

    if current_user.manicura?
      # Nuevo flujo: lotes asignados (en_manicura o manicura_pendiente con manicurador_id)
      # Legacy: lotes en secado/manicura_pendiente sin manicurador_id
      lotes = lotes.where(
        lotes: { estado: 'en_manicura', manicurador_id: current_user.id }
      ).or(lotes.where(
        lotes: { estado: 'manicura_pendiente', manicurador_id: current_user.id }
      )).or(lotes.where(
        lotes: { estado: %w[secado manicura_pendiente], manicurador_id: nil }
      ))
      # Flujo nuevo: "en espera de aprobación" = lotes con un pesaje ya enviado por
      # este manicura (el lote sigue en_manicura, lo que espera es el PesajeManicura).
      if ActiveModel::Type::Boolean.new.cast(params[:pesaje_enviado])
        lote_ids = current_user.club.pesajes_manicura
                               .enviados.where(manicurador_id: current_user.id)
                               .select(:lote_id)
        lotes = lotes.where(id: lote_ids)
      elsif params[:estado].present?
        lotes = lotes.where(estado: params[:estado])
      end
    elsif params[:manicura].present?
      lotes = lotes.where(estado: %w[cosecha secado curado])
    else
      lotes = lotes.where(estado: params[:estado]) if params[:estado].present?
    end
    lotes = lotes.order(created_at: :desc)
    render json: lotes.map { |l|
      s = LoteSerializer.serialize(l)
      if s[:genetica] && l.genetica&.fotos&.attached?
        s[:genetica][:foto_url] = url_for(l.genetica.fotos.first) rescue nil
      end
      s
    }
  end

  # GET /lotes/:id
  def show
    render json: LoteSerializer.serialize(@lote, include_plants: true, include_cycle_data: true)
  end

  # GET /lotes/por_qr/:codigo_qr
  def por_qr
    lote = current_user.club.lotes.find_by(codigo_qr: params[:codigo_qr])
    return render json: { error: 'Lote no encontrado' }, status: :not_found unless lote

    render json: {
      id:        lote.id,
      codigo:    lote.codigo,
      estado:    lote.estado,
      genetica:  lote.genetica&.nombre,
      sala:      lote.sala&.nombre,
    }
  end

  # POST /salas/:sala_id/lotes
  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_lote?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('lotes', info[:limites][:lotes]), status: :payment_required
    end

    # Lote cosechado sin sala de cultivo: viene con sede_id y lo ubicamos en la
    # sala de proceso "Cosecha · sede" (igual que al avanzar floración → cosecha),
    # así conserva la sede para el flujo de manicura y se ve en /cosechado.
    if @sala.nil? && params[:sede_id].present?
      sede = current_user.club.sedes.find_by(id: params[:sede_id])
      return render json: { errors: ['Sede no encontrada'] }, status: :unprocessable_entity unless sede
      @sala = Sala.find_or_create_proceso!(sede: sede, tipo: 'cosecha', created_by: current_user)
    end
    return render json: { errors: ['Falta la sala o la sede'] }, status: :unprocessable_entity if @sala.nil?

    @lote = @sala.lotes.build(lote_params)
    @lote.club = current_user.club

    # Estados creables: ciclo previo a stock + cosechado. secado/curado/finalizado
    # y los de manicura son post-stock o de proceso y no se cargan a mano.
    estados_no_creables = %w[secado curado en_manicura manicura_pendiente finalizado]
    if estados_no_creables.include?(@lote.estado.to_s)
      return render json: { errors: ["No se puede crear un lote en estado '#{@lote.estado}'"] }, status: :unprocessable_entity
    end

    # Un lote es un batch de plantas: exigimos al menos 1 al crear.
    if lote_params[:plants_count].to_i < 1
      return render json: { errors: ['La cantidad de plantas debe ser al menos 1'] }, status: :unprocessable_entity
    end

    # En el path heredado el frontend no envía start_date (lo calcula crear_lote_heredado).
    # Calculamos aquí también para que la validación de presencia no rechace el save!.
    if params[:heredado].in?([true, 'true', '1']) && @lote.start_date.blank?
      estado       = @lote.estado.to_s
      dias_semilla = params[:dias_semilla_esqueje].to_i
      dias_vege    = params[:dias_vegetativo].to_i
      dias_flora   = params[:dias_floracion].to_i
      dias_cos     = params[:dias_cosecha].to_i
      total_dias   = case estado
                     when 'semilla', 'esqueje' then dias_semilla
                     when 'vegetativo'         then dias_semilla + dias_vege
                     when 'floracion'          then dias_semilla + dias_vege + dias_flora
                     when 'cosecha'            then dias_semilla + dias_vege + dias_flora + dias_cos
                     else 0
                     end
      @lote.start_date = total_dias > 0 ? total_dias.days.ago.to_date : Date.today
    end

    plantas_iniciales = lote_params[:plants_count].to_i

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

    ActiveRecord::Base.transaction do
      @lote.save!
      crear_lote_heredado(@lote, params) if params[:heredado].in?([true, 'true', '1'])
      if plantas_iniciales > 0
        state_inicial = estado_a_state(@lote.estado)
        plantas_iniciales.times do |i|
          numero = (i + 1).to_s.rjust(3, '0')
          @lote.plants.create!(
            nombre: "#{@lote.codigo}-P#{numero}",
            state:  state_inicial,
          )
        end
      end
    end

    render json: LoteSerializer.serialize(@lote, include_plants: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH/PUT /lotes/:id
  def update
    if @lote.estado == 'finalizado'
      return render json: { error: 'Los lotes finalizados son inmutables. Para correcciones de datos contactá al soporte.' }, status: :forbidden
    end

    if @lote.update(lote_update_params)
      # Corrección de historia: reconciliar las fechas de inicio de cada fase con sus
      # eventos de cambio de estado (fuente de verdad de la analítica de días por fase).
      reconciliar_fechas_fase(@lote, params[:fechas_fase]) if params[:fechas_fase].present?
      render json: LoteSerializer.serialize(@lote.reload)
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Ajusta el registrado_en del evento 'cambio_estado' de cada fase (o lo crea si falta),
  # para reflejar las fechas reales de un lote cargado/corregido a mano.
  def reconciliar_fechas_fase(lote, fechas)
    %w[vegetativo floracion cosecha].each do |fase|
      valor = fechas[fase].presence
      next unless valor
      ts = Date.parse(valor).in_time_zone.change(hour: 12) rescue nil
      next unless ts
      ev = lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: fase).order(:registrado_en).first
      if ev
        ev.update!(registrado_en: ts)
      else
        lote.lote_eventos.create!(
          tipo: 'cambio_estado', estado_nuevo: fase, estado_anterior: nil,
          descripcion: "Corrección de fecha: inicio #{fase}", registrado_en: ts,
          user: current_user, club: lote.club,
        )
      end
    end
  end

  # GET /lotes/export_csv
  def export_csv
    scope = current_user.club.lotes
                        .includes(:genetica, sala: :sede)
                        .order(created_at: :desc)

    scope = scope.where(estado: params[:estado]) if params[:estado].present?

    if params[:desde].present?
      desde = Date.parse(params[:desde]) rescue nil
      scope = scope.where('lotes.created_at >= ?', desde.beginning_of_day) if desde
    end
    if params[:hasta].present?
      hasta = Date.parse(params[:hasta]) rescue nil
      scope = scope.where('lotes.created_at <= ?', hasta.end_of_day) if hasta
    end

    require "csv"
    csv_data = CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
      csv << [
        "Código", "Estado", "Genética", "Sala", "Sede",
        "Plantas", "Plantas obj.", "Plantas cosechadas",
        "Rendimiento obj. (g)", "Rendimiento real (g)", "Desviación (%)",
        "Costo total", "Costo/gramo",
        "Inicio", "Creado"
      ]
      scope.each do |l|
        desv = if l.rendimiento_real_g.present? && l.rendimiento_objetivo_g.present? && l.rendimiento_objetivo_g > 0
                 ((l.rendimiento_real_g.to_f - l.rendimiento_objetivo_g.to_f) / l.rendimiento_objetivo_g.to_f * 100).round(1)
               end
        csv << [
          l.codigo,
          l.estado,
          l.genetica&.nombre,
          l.sala&.nombre,
          l.sala&.sede&.nombre,
          l.plants_count,
          l.plants_count_objetivo,
          l.plants_count_cosechadas,
          l.rendimiento_objetivo_g&.to_f,
          l.rendimiento_real_g&.to_f,
          desv,
          l.costo_lote&.costo_total&.to_f,
          l.costo_lote&.costo_por_gramo&.to_f,
          l.start_date&.strftime("%d/%m/%Y"),
          l.created_at.strftime("%d/%m/%Y"),
        ]
      end
    end

    send_data "\xEF\xBB\xBF#{csv_data}",
              filename:    "lotes_#{Date.today}.csv",
              type:        "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  # GET /lotes/proximo_codigo
  def proximo_codigo
    club      = current_user.club
    anio      = Date.today.strftime("%y")
    count     = club.lotes.count + 1
    candidate = "L-#{anio}-#{count.to_s.rjust(3, '0')}"
    while Lote.exists?(club: club, codigo: candidate)
      count    += 1
      candidate = "L-#{anio}-#{count.to_s.rjust(3, '0')}"
    end
    render json: { codigo: candidate }
  end

  # DELETE /lotes/:id
  def destroy
    @lote.soft_delete!
    head :no_content
  end

  # POST /lotes/:id/transiciones
  def transiciones
    raw_pesada      = params[:pesada] || {}
    pesada_attrs    = raw_pesada.respond_to?(:to_unsafe_h) ? raw_pesada.to_unsafe_h.symbolize_keys : raw_pesada.to_h.symbolize_keys
    raw_pesadas     = params[:pesadas_plantas] || []
    pesadas_plantas = raw_pesadas.map { |p| p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h.symbolize_keys : p.to_h.symbolize_keys }
    pesada_attrs[:registrado_por] = current_user
    manicurado = pesada_attrs.delete(:manicurado).in?([true, 'true', '1'])
    nueva_fase = params[:nueva_fase]

    # Cultivador avanza floración → cosecha registrando plantas cosechadas
    if current_user.cultivador? && @lote.estado == 'floracion' && nueva_fase == 'cosecha'
      estado_anterior  = @lote.estado
      sala_anterior_id = @lote.sala_id
      ActiveRecord::Base.transaction do
        @lote.pesadas.create!(
          fase_origen:        'floracion',
          fase_destino:       'cosecha',
          plantas_cosechadas: pesada_attrs[:plantas_cosechadas]&.to_i,
          registrado_por:     current_user,
          registrado_at:      Time.current,
          notas:              pesada_attrs[:notas],
        )
        @lote.avanzar_fase!(sala_id: params[:sala_id])
        @lote.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: estado_anterior,
          estado_nuevo:    @lote.estado,
          descripcion:     "Cosecha registrada: #{pesada_attrs[:plantas_cosechadas]} plantas",
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
          sala_origen_id:  sala_anterior_id != @lote.sala_id ? sala_anterior_id : nil,
          sala_destino_id: sala_anterior_id != @lote.sala_id ? @lote.sala_id   : nil,
        )
        TareasAutoService.new(lote: @lote, estado_nuevo: @lote.estado, user: current_user, club: current_user.club).call
      end
      return render json: LoteSerializer.serialize(@lote.reload, include_plants: true), status: :created
    end

    # Manicura pesa un lote (en_manicura o secado) → crea un PesajeManicura
    # "enviado" que cae en la cola única de confirmación del admin (Manicura).
    # El lote NO pasa más por manicura_pendiente: al confirmar el pesaje se
    # genera el stock y, cubiertas todas las plantas, el lote se finaliza solo.
    if manicurado && %w[en_manicura secado].include?(@lote.estado) && current_user.manicura?
      peso = pesada_attrs[:peso_seco_g].to_d
      if peso <= 0
        return render json: { error: 'El peso seco debe ser mayor a 0' }, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        # Lotes que venían del camino viejo (secado, sin manicurador asignado)
        # entran al flujo nuevo acá mismo
        if @lote.estado == 'secado'
          @lote.update!(estado: 'en_manicura', manicurador_id: @lote.manicurador_id || current_user.id)
          @lote.lote_eventos.create!(
            tipo:            'cambio_estado',
            estado_anterior: 'secado',
            estado_nuevo:    'en_manicura',
            descripcion:     'Inicio de manicura (pesaje directo desde secado)',
            user:            current_user,
            club:            current_user.club,
            registrado_en:   Time.current,
          )
        end

        @lote.pesajes_manicura.create!(
          club:          current_user.club,
          manicurador:   current_user,
          fecha_pesaje:  Date.today,
          estado:        'enviado',
          enviado_at:    Time.current,
          peso_total_g:  peso,
          plantas_count: pesada_attrs[:plantas_manicuradas],
          notas:         pesada_attrs[:notas],
        )

        AlertaInterna.create!(
          club:             current_user.club,
          tipo:             'manicura_aprobacion_pendiente',
          mensaje:          "Manicura #{current_user.first_name} envió pesaje del lote #{@lote.codigo} — #{pesada_attrs[:plantas_manicuradas]} plantas · #{peso}g — pendiente de confirmación",
          severidad:        'info',
          creada_por:       current_user,
          destinada_a_role: 'admin',
          contexto:         { lote_id: @lote.id, lote_codigo: @lote.codigo,
                              peso_seco_g: peso, manicura_id: current_user.id }
        )
      end
      return render json: LoteSerializer.serialize(@lote.reload), status: :created
    end

    estado_anterior  = @lote.estado
    sala_anterior_id = @lote.sala_id

    # semilla/esqueje → vegetativo: no generan pesada, usan avanzar_fase!
    if %w[semilla esqueje].include?(@lote.estado)
      @lote.avanzar_fase!(sala_id: params[:sala_id])
    else
      @lote.transicionar!(
        nueva_fase,
        pesada_attrs:          pesada_attrs,
        manicurado:            manicurado,
        pesadas_plantas_attrs: pesadas_plantas,
        sala_id:               params[:sala_id]
      )
    end

    @lote.lote_eventos.create!(
      tipo:            'cambio_estado',
      estado_anterior: estado_anterior,
      estado_nuevo:    @lote.estado,
      descripcion:     "Transición: #{estado_anterior} → #{@lote.estado}",
      user:            current_user,
      club:            current_user.club,
      registrado_en:   Time.current,
      sala_origen_id:  sala_anterior_id != @lote.sala_id ? sala_anterior_id : nil,
      sala_destino_id: sala_anterior_id != @lote.sala_id ? @lote.sala_id   : nil,
    )

    render json: LoteSerializer.serialize(@lote.reload, include_plants: true)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/aprobar_manicura
  def aprobar_manicura
    authorize @lote, :aprobar_manicura?
    if @lote.manicurador_id.present?
      # Nuevo flujo: aprobar + generar stock pendiente_asignacion + finalizar
      @lote.aprobar_y_finalizar!(
        aprobado_por:        current_user,
        peso_seco_g:         params[:peso_seco_g],
        sede_id:             params[:sede_id],
        precio_sugerido_ars: params[:precio_sugerido_ars],
      )
    else
      # Flujo legacy: aprobar → curado
      @lote.aprobar_manicura!(aprobado_por: current_user, observaciones: params[:observaciones])
    end
    render json: LoteSerializer.serialize(@lote.reload)
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta parámetro requerido: #{e.param}" }, status: :unprocessable_entity
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/asignar_manicurador
  def asignar_manicurador
    authorize @lote, :asignar_manicurador?
    manicurador = current_user.club.users.where(role: Lote::ROLES_MANICURA).find(params[:manicurador_id])
    @lote.asignar_manicurador!(manicurador: manicurador, asignado_por: current_user, sala_id: params[:sala_id])
    render json: LoteSerializer.serialize(@lote.reload)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Manicurador no encontrado' }, status: :not_found
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/completar_manicura
  def completar_manicura
    authorize @lote, :completar_manicura?
    @lote.completar_manicura_directa!(
      registrado_por: current_user,
      peso_seco_g:    params.require(:peso_seco_g),
      sede_id:        params.require(:sede_id),
      notas:          params[:notas],
      forma_producto: params[:forma_producto].presence || 'flor_seca',
    )
    render json: LoteSerializer.serialize(@lote.reload)
  rescue ActionController::ParameterMissing => e
    render json: { error: "Falta parámetro requerido: #{e.param}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sede no encontrada' }, status: :not_found
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/finalizar_pesaje_manicura
  # Funciona con QR flow (borrador pesada existente) y con batch flow (compute from plant.peso_seco)
  def finalizar_pesaje_manicura
    unless %w[en_manicura secado].include?(@lote.estado)
      return render json: { error: 'Estado inválido para finalizar pesaje' }, status: :unprocessable_entity
    end

    authorized = current_user.admin? || current_user.supervisor? ||
                 (current_user.manicura? && @lote.manicurador_id == current_user.id) ||
                 (current_user.manicura? && @lote.manicurador_id.nil?)
    return render json: { error: 'No estás asignado a este lote' }, status: :forbidden unless authorized

    # Flujo unificado: el cierre del pesaje crea un PesajeManicura "enviado"
    # que cae en la cola de confirmación del admin. El lote no pasa más por
    # manicura_pendiente: el stock y la finalización ocurren al confirmar.
    pesaje = nil
    ActiveRecord::Base.transaction do
      pesada_borrador = @lote.pesadas.find_by(borrador: true, manicurado: true)

      if pesada_borrador
        # QR flow: peso_seco_g vive en pesadas_plantas, se agrega
        total = pesada_borrador.pesadas_plantas.sum(:peso_seco_g).to_d
        count = pesada_borrador.pesadas_plantas.count
        total = pesada_borrador.peso_seco_g.to_d        if total <= 0
        count = pesada_borrador.plantas_manicuradas.to_i if count.zero?
      else
        # Batch flow: totales desde el peso_seco por planta
        plantas_pesadas = @lote.plants.where('peso_seco > 0')
        total = plantas_pesadas.sum(:peso_seco).to_d
        count = plantas_pesadas.count
      end

      if total <= 0 || count.zero?
        return render json: { error: 'No hay plantas con peso registrado en este lote' }, status: :unprocessable_entity
      end

      if @lote.estado == 'secado'
        @lote.update!(estado: 'en_manicura', manicurador_id: @lote.manicurador_id || current_user.id)
      end

      pesaje = @lote.pesajes_manicura.create!(
        club:          current_user.club,
        manicurador:   current_user,
        fecha_pesaje:  Date.today,
        estado:        'enviado',
        enviado_at:    Time.current,
        peso_total_g:  total,
        plantas_count: count,
      )

      if pesada_borrador
        # Vincular las plantas pesadas al pesaje para que la finalización
        # automática del lote cuente por planta, y cerrar el borrador legacy
        pesada_borrador.pesadas_plantas.update_all(pesaje_manicura_id: pesaje.id)
        pesada_borrador.update!(borrador: false)
      end

      @lote.lote_eventos.create!(
        tipo:            'nota',
        descripcion:     "Pesaje completado: #{count} plantas · #{total.round(1)}g — enviado para confirmación",
        user:            current_user,
        club:            current_user.club,
        registrado_en:   Time.current,
      )

      AlertaInterna.create!(
        club:             current_user.club,
        tipo:             'manicura_aprobacion_pendiente',
        mensaje:          "Manicura #{current_user.first_name} completó #{@lote.codigo} — #{count} plantas · #{total.round(1)}g — pendiente de confirmación",
        severidad:        'info',
        creada_por:       current_user,
        destinada_a_role: 'admin',
        contexto:         { lote_id: @lote.id, lote_codigo: @lote.codigo,
                            peso_seco_g: total, manicura_id: current_user.id,
                            pesaje_manicura_id: pesaje.id },
      )
    end

    render json: { ok: true, lote: LoteSerializer.serialize(@lote.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/rechazar_manicura
  def rechazar_manicura
    authorize @lote, :rechazar_manicura?
    @lote.rechazar_manicura!(rechazado_por: current_user, motivo: params.require(:motivo))
    render json: LoteSerializer.serialize(@lote.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /lotes/:id/completar_datos
  # Exclusivamente para completar campos críticos en lotes ya finalizados.
  # Solo acepta los campos del checklist post-finalización — no permite cambiar estado ni datos contables.
  def completar_datos
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end
    unless @lote.estado == 'finalizado'
      return render json: { error: 'Este endpoint solo aplica a lotes finalizados' }, status: :unprocessable_entity
    end

    permitidos = params.require(:lote).permit(
      :genetica_id, :fotoperiodo, :fotoperiodo_vegetativo,
      :semanas_floracion, :tamanio_maceta
    ).reject { |_, v| v.blank? }

    if @lote.update(permitidos)
      render json: LoteSerializer.serialize(@lote.reload)
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
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

  # GET /lotes/:id/preview_plan?plan_trabajo_id=X
  def preview_plan
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end
    plan = current_user.club.plan_trabajos.publicados.find(params[:plan_trabajo_id])
    tareas = AplicarPlanLoteService.new(lote: @lote, plan: plan, ejecutado_por: current_user).preview
    render json: {
      plan:   { id: plan.id, titulo: plan.titulo, duracion_dias: plan.duracion_dias },
      tareas: tareas,
      total:  tareas.size,
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  end

  # POST /lotes/:id/aplicar_plan
  def aplicar_plan
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end
    plan = current_user.club.plan_trabajos.publicados.find(params[:plan_trabajo_id])
    creadas = AplicarPlanLoteService.new(lote: @lote, plan: plan, ejecutado_por: current_user).aplicar!
    render json: { tareas_creadas: creadas.size }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /lotes/:id/avanzar_fase
  def avanzar_fase
    authorize @lote, :avanzar_fase?
    if @lote.estado == 'floracion'
      return render json: { error: 'La cosecha debe registrarse con datos de pesada. Usá el formulario de cosecha.' }, status: :unprocessable_entity
    end
    estado_anterior  = @lote.estado
    sala_anterior_id = @lote.sala_id
    @lote.avanzar_fase!(sala_id: params[:sala_id])
    @lote.lote_eventos.create!(
      tipo:            'cambio_estado',
      estado_anterior: estado_anterior,
      estado_nuevo:    @lote.estado,
      descripcion:     "Avance de fase: #{estado_anterior} → #{@lote.estado}",
      user:            current_user,
      club:            current_user.club,
      registrado_en:   Time.current,
      sala_origen_id:  sala_anterior_id != @lote.sala_id ? sala_anterior_id : nil,
      sala_destino_id: sala_anterior_id != @lote.sala_id ? @lote.sala_id   : nil,
    )
    TareasAutoService.new(lote: @lote, estado_nuevo: @lote.estado, user: current_user, club: current_user.club).call
    render json: LoteSerializer.serialize(@lote.reload, include_plants: true)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/cosechar_plantas
  # Marca plantas individuales como cosechadas sin avanzar la fase del lote.
  # Body: { plantas_ids: [1,2,3], peso_total_g: 150.0, pasada: "A" }
  def cosechar_plantas
    authorize @lote, :avanzar_fase?
    raise ArgumentError, 'El lote no está en floración' unless @lote.estado == 'floracion'
    raise ArgumentError, 'Función no disponible — ejecutá las migraciones pendientes' unless Plant.column_names.include?('pasada_cosecha')

    plantas_ids  = Array(params[:plantas_ids]).map(&:to_i)
    peso_total_g = params[:peso_total_g].presence&.to_f
    pasada       = params[:pasada].presence || siguiente_pasada(@lote)

    raise ArgumentError, 'Seleccioná al menos una planta' if plantas_ids.empty?

    plantas = @lote.plants.where(id: plantas_ids, state: 'floracion')
    raise ArgumentError, "No se encontraron plantas en floración con esos IDs" if plantas.empty?

    plantas_count = plantas.count

    ActiveRecord::Base.transaction do
      plantas.update_all(
        state:          'cosechado',
        pasada_cosecha: pasada,
        fecha_cosecha:  Date.today,
      )

      @lote.pesadas.create!(
        fase_origen:        'floracion',
        fase_destino:       'cosecha',
        plantas_cosechadas: plantas_count,
        peso_humedo_g:      peso_total_g,
        registrado_por:     current_user,
        registrado_at:      Time.current,
        notas:              "Cosecha #{pasada} — #{plantas_count} plantas",
      )

      @lote.lote_eventos.create!(
        tipo:          'nota',
        estado_nuevo:  'cosecha',
        descripcion:   "Cosecha #{pasada}: #{plantas_count} plantas cosechadas#{peso_total_g ? " · #{peso_total_g}g húmedo" : ''}",
        user:          current_user,
        club:          current_user.club,
        registrado_en: Time.current,
      )

      # Si todas las plantas del lote están cosechadas, avanzar la fase automáticamente
      if @lote.plants.where.not(state: %w[cosechado descartada]).none?
        estado_anterior  = @lote.estado
        sala_anterior_id = @lote.sala_id
        @lote.avanzar_fase!(sala_id: params[:sala_id])
        @lote.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: estado_anterior,
          estado_nuevo:    @lote.estado,
          descripcion:     "Todas las plantas cosechadas — lote avanza a #{@lote.estado}",
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
          sala_origen_id:  sala_anterior_id != @lote.sala_id ? sala_anterior_id : nil,
          sala_destino_id: sala_anterior_id != @lote.sala_id ? @lote.sala_id   : nil,
        )
      end
    end

    render json: LoteSerializer.serialize(@lote.reload, include_plants: true), status: :created
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
    transplantes_raw = PlantActivity
      .joins(:plant, :user)
      .where(plants: { lote_id: @lote.id }, activity_type: 'transplant')
      .includes(:user)
      .order(occurred_at: :asc)

    transplantes = transplantes_raw
      .group_by { |a| [a.occurred_at.to_date, a.metadata&.dig('maceta_origen_l'), a.metadata&.dig('maceta_destino_l')] }
      .map do |(fecha, origen, destino), acts|
        { fecha: fecha, usuario: acts.first.user&.first_name,
          maceta_origen: origen, maceta_destino: destino,
          plantas: acts.size, notas: acts.map(&:notes).compact.uniq.first }
      end

    render json: {
      lote:          LoteSerializer.serialize(@lote, include_cycle_data: true),
      pesadas:       pesadas.map { |p| PesadaSerializer.serialize(p) },
      stocks:        stocks.map  { |s| StockSerializer.serialize_inline(s) },
      dispensaciones: dispensaciones.map { |d|
        { id: d.id, socio: "#{d.paciente.nombre} #{d.paciente.apellido}", fecha: d.fecha_dispensacion,
          cantidad: d.cantidad.to_f, unidad: d.stock&.unidad, forma_producto: d.stock&.forma_producto }
      },
      transplantes:,
    }
  end

  # GET /lotes/:id/pl
  def pl
    lote = current_user.club.lotes.includes(:costo_lote, :stocks).find(params[:id])
    render json: calcular_pl(lote)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  private

  def calcular_pl(lote)
    stock_ids = lote.stocks.map(&:id)
    disps     = Dispensacion.no_canceladas.where(stock_id: stock_ids)

    ingresos           = disps.sum('cantidad * COALESCE(precio_unitario_ars, 0)').to_f.round(2)
    gramos_dispensados = disps.sum(:cantidad).to_f.round(3)

    costos      = lote.costo_lote
    costo_total = costos&.costo_total.to_f

    margen     = (ingresos - costo_total).round(2)
    margen_pct = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil

    gramos_producidos = costos&.gramos_producidos&.to_f || lote.rendimiento_real_g&.to_f
    gramos_en_stock   = lote.stocks.sum(:cantidad).to_f.round(3)
    ingreso_por_gramo = gramos_dispensados > 0 ? (ingresos / gramos_dispensados).round(2) : nil

    {
      lote_id:            lote.id,
      lote_codigo:        lote.codigo,
      costo_total:        costo_total,
      costo_insumos:      costos&.costo_insumos.to_f,
      costo_energia:      costos&.costo_energia.to_f,
      costo_mano_obra:    costos&.costo_mano_obra.to_f,
      costo_prorrateado:  costos&.costo_prorrateado.to_f,
      costo_por_gramo:    costos&.costo_por_gramo&.to_f,
      notas_costo:        costos&.notas,
      ingresos:           ingresos,
      gramos_dispensados: gramos_dispensados,
      ingreso_por_gramo:  ingreso_por_gramo,
      margen:             margen,
      margen_pct:         margen_pct,
      gramos_producidos:  gramos_producidos,
      gramos_en_stock:    gramos_en_stock,
      tiene_costos:       costos.present?,
      tiene_ingresos:     ingresos > 0,
    }
  end

  def estado_a_state(estado)
    {
      'semilla'    => 'germinacion',
      'esqueje'    => 'esqueje',
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
    if current_user.cultivador?
      salas_ids = current_user.salas_ids_asignadas
      salas_ids = current_user.club.salas.where(kind: %w[vegetativo floracion]).ids if salas_ids.empty?
      mis_cosechados = LoteEvento.where(
        club_id:      current_user.club_id,
        user_id:      current_user.id,
        estado_nuevo: 'cosecha'
      ).select(:lote_id)
      scope = scope.where(sala_id: salas_ids).or(scope.where(id: mis_cosechados))
    elsif current_user.supervisor?
      salas_ids = current_user.salas_ids_en_sedes_asignadas
      scope = scope.where(sala_id: salas_ids)
    elsif current_user.manicura?
      scope = scope.where(
        lotes: { estado: 'en_manicura', manicurador_id: current_user.id }
      ).or(scope.where(
        lotes: { estado: 'manicura_pendiente', manicurador_id: current_user.id }
      )).or(scope.where(
        lotes: { estado: %w[secado manicura_pendiente], manicurador_id: nil }
      ))
    end
    @lote = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def lote_params
    params.require(:lote).permit(
      :start_date, :estado, :origen, :planta_madre_id, :plants_count, :strain, :notes,
      :grow_type, :light_type, :genetica_id, :semanas_floracion, :tamanio_maceta,
      :plants_count_objetivo, :rendimiento_objetivo_g, :fecha_cosecha_estimada,
      :rendimiento_real_g, :plants_count_cosechadas,
      :fotoperiodo, :fotoperiodo_vegetativo,
      :tamanio_maceta_inicial, :fecha_trasplante,
      :ph_riego, :fertilizacion_descripcion, :sistema_hidro, :sustrato_especifico
    )
  end

  def lote_update_params
    params.require(:lote).permit(
      :estado, :start_date, :origen, :planta_madre_id, :plants_count, :strain, :notes,
      :grow_type, :light_type, :genetica_id, :semanas_floracion, :tamanio_maceta,
      :plants_count_objetivo, :rendimiento_objetivo_g, :fecha_cosecha_estimada,
      :rendimiento_real_g, :plants_count_cosechadas,
      :fotoperiodo, :fotoperiodo_vegetativo,
      :tamanio_maceta_inicial, :fecha_trasplante,
      :ph_riego, :fertilizacion_descripcion, :sistema_hidro, :sustrato_especifico
    )
  end

  def cerrar_curado_con_stocks
    raise RuntimeError, 'El lote no está en curado' unless @lote.estado == 'curado'

    pesada_data   = params.require(:pesada).permit(:fase_origen, :fase_destino, :peso_curado_g, :notas)
    stocks_params = params[:stocks].map { |s| s.permit(:forma_producto, :cantidad, :unidad, :precio_sugerido_ars) }

    peso_curado_g = pesada_data[:peso_curado_g].to_d
    total_stock   = stocks_params.sum { |s| s[:cantidad].to_d }

    if total_stock > peso_curado_g
      return render json: { error: "Stocks generados (#{total_stock}g) exceden peso curado disponible (#{peso_curado_g}g)" },
                    status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      pesada = @lote.pesadas.create!(
        fase_origen:    pesada_data[:fase_origen]  || 'curado',
        fase_destino:   pesada_data[:fase_destino] || 'finalizado',
        peso_curado_g:  peso_curado_g,
        notas:          pesada_data[:notas],
        registrado_por: current_user,
        registrado_at:  Time.current,
      )

      # Stocks nacen sin sede asignada — el admin decide destino en el siguiente paso
      stocks_creados = stocks_params.map do |sp|
        stock = Stock.create!(
          sede:               nil,
          lote:               @lote,
          origen:             'lote',
          estado:             'pendiente_asignacion',
          forma_producto:     sp[:forma_producto],
          cantidad:           sp[:cantidad].to_d,
          unidad:             sp[:unidad] || 'g',
          precio_sugerido_ars: sp[:precio_sugerido_ars],
        )
        stock.stock_movimientos.create!(
          tipo:    'produccion',
          gramos:  stock.cantidad,
          usuario: current_user,
        )
        stock
      end

      @lote.update!(estado: 'finalizado')

      lote_final = @lote.reload
      render json: {
        lote:               LoteSerializer.serialize(lote_final),
        pesada:             PesadaSerializer.serialize(pesada),
        stocks:             stocks_creados.map { |s| StockSerializer.serialize_inline(s) },
        campos_incompletos: campos_incompletos_lote(lote_final),
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
    lote_final = @lote.reload
    render json: {
      lote:               LoteSerializer.serialize(lote_final),
      stock:              StockSerializer.serialize_inline(stock),
      campos_incompletos: campos_incompletos_lote(lote_final),
    }, status: :created
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  CAMPOS_CRITICOS = {
    genetica_id:            'Genética / variedad',
    fotoperiodo:            'Fotoperiodo floración',
    fotoperiodo_vegetativo: 'Fotoperiodo vegetativo',
    semanas_floracion:      'Semanas en floración',
    tamanio_maceta:         'Tamaño de maceta final',
  }.freeze

  def campos_incompletos_lote(lote)
    CAMPOS_CRITICOS.filter_map do |campo, label|
      { campo: campo, label: label } if lote.send(campo).blank?
    end
  end

  def siguiente_pasada(lote)
    usadas = lote.plants.where.not(pasada_cosecha: nil).distinct.pluck(:pasada_cosecha)
    letra  = ('A'..'Z').find { |l| usadas.exclude?(l) }
    letra || "#{usadas.length + 1}"
  end

  def crear_lote_heredado(lote, params)
    estado         = lote.estado
    origen         = lote.origen || 'semilla'
    dias_semilla   = params[:dias_semilla_esqueje].to_i
    dias_vege      = params[:dias_vegetativo].to_i
    dias_flora     = params[:dias_floracion].to_i
    dias_cos       = params[:dias_cosecha].to_i

    total_dias = case estado
                 when 'semilla', 'esqueje' then dias_semilla
                 when 'vegetativo'         then dias_semilla + dias_vege
                 when 'floracion'          then dias_semilla + dias_vege + dias_flora
                 when 'cosecha'            then dias_semilla + dias_vege + dias_flora + dias_cos
                 else 0
                 end

    return if total_dias <= 0

    fecha_inicio = total_dias.days.ago.to_date
    lote.update_column(:start_date, fecha_inicio)

    estado_inicial = origen == 'esqueje' ? 'esqueje' : 'semilla'

    if %w[vegetativo floracion cosecha].include?(estado)
      fecha_vege = fecha_inicio + dias_semilla
      lote.lote_eventos.create!(
        tipo:            'cambio_estado',
        estado_anterior: estado_inicial,
        estado_nuevo:    'vegetativo',
        descripcion:     "#{estado_inicial.capitalize} → Vegetativo (carga heredada)",
        user:            current_user,
        club:            current_user.club,
        registrado_en:   fecha_vege.to_time,
      )
    end

    if %w[floracion cosecha].include?(estado)
      fecha_flora = fecha_inicio + dias_semilla + dias_vege
      lote.lote_eventos.create!(
        tipo:            'cambio_estado',
        estado_anterior: 'vegetativo',
        estado_nuevo:    'floracion',
        descripcion:     "Vegetativo → Floración (carga heredada)",
        user:            current_user,
        club:            current_user.club,
        registrado_en:   fecha_flora.to_time,
      )
    end

    if estado == 'cosecha'
      fecha_cosecha = fecha_inicio + dias_semilla + dias_vege + dias_flora
      lote.lote_eventos.create!(
        tipo:            'cambio_estado',
        estado_anterior: 'floracion',
        estado_nuevo:    'cosecha',
        descripcion:     "Floración → Cosecha (carga heredada)",
        user:            current_user,
        club:            current_user.club,
        registrado_en:   fecha_cosecha.to_time,
      )
    end
  end

  def require_admin_cultivador_o_manicura
    unless current_user.admin? || current_user.cultivador? || current_user.manicura? || current_user.supervisor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_export_role!
    unless current_user.admin? || current_user.role == 'auditor' || current_user.supervisor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

end


