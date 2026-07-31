class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_cultivador_o_manicura
  before_action :set_lote, only: [:show, :update, :completar_datos, :destroy, :transiciones, :avanzar_fase, :cosechar_plantas, :timeline, :historial, :asignar_manicurador, :devolver_manicura, :reevaluar_manicura, :registrar_trasplante]
  before_action :require_export_role!, only: [:export_csv]
  before_action :set_sala, only: [:index, :create], if: -> { params[:sala_id].present? }

  # GET /lotes o GET /salas/:sala_id/lotes
  def index
    lotes = current_user.club.lotes.includes(:costo_lote, :pesadas, :lote_eventos, :manicurador, sala: :sede, genetica: { fotos_attachments: :blob })
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
                     .where(estado: Lote::CULTIVO_ESTADOS)
      end
    elsif current_user.supervisor?
      salas_ids = current_user.salas_ids_en_sedes_asignadas
      lotes = lotes.where(sala_id: salas_ids)
    end

    if current_user.manicura?
      # El manicura ve los lotes en manicura que el admin le asignó. La "espera de
      # aprobación" no es un estado del lote: es un PesajeManicura ya enviado (ver abajo).
      lotes = lotes.where(lotes: { estado: 'en_manicura', manicurador_id: current_user.id })
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
      lotes = lotes.where(estado: %w[cosecha en_manicura curado])
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

    # Lote cosechado: no usa sala de cultivo. Viene con sede_id y se trackea por estado
    # (sala_id = nil, sede propia). Para lotes de cultivo, la sala viene en @sala.
    sede_directa = nil
    if @sala.nil?
      return render json: { errors: ['Falta la sala o la sede'] }, status: :unprocessable_entity if params[:sede_id].blank?
      sede_directa = current_user.club.sedes.find_by(id: params[:sede_id])
      return render json: { errors: ['Sede no encontrada'] }, status: :unprocessable_entity unless sede_directa
    end

    @lote = (@sala ? @sala.lotes : current_user.club.lotes).build(lote_params)
    @lote.club = current_user.club
    @lote.sede = sede_directa || @sala&.sede
    # Legacy: planta_madre_id (single) = la primera del array de madres, para compatibilidad.
    @lote.planta_madre_id ||= @lote.planta_madre_ids&.first

    # Herencia: si la genética define días objetivo por fase, el lote los toma como default
    # (se pueden sobrescribir desde el form). Floración = tiempo_floracion (ya en días).
    if @lote.genetica
      @lote.dias_vegetativo_objetivo ||= @lote.genetica.dias_vegetativo_objetivo
      @lote.dias_floracion_objetivo  ||= @lote.genetica.tiempo_floracion
      @lote.dias_cosecha_objetivo    ||= @lote.genetica.dias_cosecha_objetivo
    end

    # Estados creables: ciclo previo a stock + cosechado. secado/curado/finalizado
    # y los de manicura son post-stock o de proceso y no se cargan a mano.
    estados_no_creables = %w[en_manicura curado finalizado]
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
                     when 'enraizado' then dias_semilla
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
        # La planta hereda la fecha de la fase de entrada = start_date del lote (no la de
        # creación digital). Si no, un lote heredado (creado hoy pero real de hace un mes)
        # deja las plantas con fecha de hoy → "días de fase" arranca en 0.
        fecha_field = state_a_fecha_field(state_inicial)
        plantas_iniciales.times do |i|
          numero = (i + 1).to_s.rjust(3, '0')
          attrs = { nombre: "#{@lote.codigo}-P#{numero}", state: state_inicial }
          attrs[fecha_field] = @lote.start_date if fecha_field
          @lote.plants.create!(attrs)
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

    # Guarda de máquina de estados: se permite corregir el estado a mano DENTRO del
    # cultivo (semilla/esqueje/vegetativo/floracion/cosecha), pero NO saltar a estados
    # post-manicura por PATCH — en_manicura/curado/finalizado implican asignación,
    # pesaje confirmado y stock de flor_seca. Pasar a esos estados sin ese flujo dejaría
    # el lote "curado" sin stock y rompería la trazabilidad/dispensación.
    nuevo_estado = lote_update_params[:estado]
    if nuevo_estado.present? && nuevo_estado != @lote.estado && (Lote::POST_COSECHA - %w[cosecha]).include?(nuevo_estado)
      return render json: { error: "No se puede pasar a '#{nuevo_estado}' editando el lote. Usá el flujo de manicura y curado." }, status: :unprocessable_entity
    end

    # Las fechas de fase deben ser correlativas (inicio ≤ vegetativo ≤ floración ≤ cosecha).
    if (msg = validar_orden_fechas(@lote))
      return render json: { errors: [msg] }, status: :unprocessable_entity
    end

    estado_anterior = @lote.estado
    # Reconciliar plantas cuando cambia plants_count (solo en cultivo pre-cosecha: ahí las
    # plantas son "vivas" y sin pesadas). En vez de escribir el número suelto, creamos o
    # quitamos plantas reales para que coincida. Fuera de cultivo, plants_count se escribe directo.
    target_pc   = lote_update_params[:plants_count]&.to_i
    reconciliar = target_pc.present? && Lote::CULTIVO_ESTADOS.include?(@lote.estado)
    begin
      ActiveRecord::Base.transaction do
        @lote.update!(reconciliar ? lote_update_params.except(:plants_count) : lote_update_params)
        reconciliar_plantas!(@lote, target_pc) if reconciliar
      end
    rescue ReconciliarError => e
      return render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      return render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    # Si la edición cambió el estado del lote (corrección manual), propagamos el estado
    # a las plantas igual que la máquina de estados — para que el listado no quede viejo.
    sincronizar_estado_plantas!(@lote) if @lote.estado != estado_anterior
    # Corrección de historia: reconciliar las fechas de inicio de cada fase con sus
    # eventos de cambio de estado (fuente de verdad de la analítica de días por fase).
    reconciliar_fechas_fase(@lote, params[:fechas_fase]) if params[:fechas_fase].present?
    reconciliar_evento_inicio!(@lote) if params.dig(:lote, :start_date).present?
    render json: LoteSerializer.serialize(@lote.reload)
  end

  ReconciliarError = Class.new(StandardError)
  # Movimiento imposible por una regla de cultivo (típico: el domo no puede entrar a una sala de
  # floración). Se rescata en `mover` para responder el motivo, no un 500.
  MoverError = Class.new(StandardError)

  # Ajusta las Plant reales del lote para que sean `target`. Crea nuevas (patrón del alta) si
  # sube; si baja, quita plantas "vacías" (sin pesadas ni peso), priorizando las más nuevas, y
  # frena si no hay suficientes vacías (nunca borra una planta con datos por bajar un número).
  def reconciliar_plantas!(lote, target)
    return if target.nil? || target < 1
    actual = lote.plants.count
    delta  = target - actual
    return if delta.zero?

    if delta.positive?
      state       = estado_a_state(lote.estado)
      fecha_field = state_a_fecha_field(state)
      delta.times do
        numero = (lote.plants.count + 1).to_s.rjust(3, '0')
        attrs  = { nombre: "#{lote.codigo}-P#{numero}", state: state }
        attrs[fecha_field] = lote.start_date if fecha_field
        lote.plants.create!(attrs)
      end
    else
      quitar     = -delta
      candidatas = lote.plants.where.not(state: 'descartada')
                       .where(peso_seco: nil)
                       .where.missing(:pesadas_plantas)
                       .order(created_at: :desc).limit(quitar).to_a
      if candidatas.size < quitar
        raise ReconciliarError, "No se pueden quitar #{quitar} plantas: solo hay #{candidatas.size} sin pesadas ni peso. Descartá o eliminá a mano las que tengan datos."
      end
      candidatas.each(&:soft_delete!)
    end
    lote.update_column(:plants_count, lote.plants.count)
  end

  # Ajusta el registrado_en del evento 'cambio_estado' de cada fase (o lo crea si falta),
  # para reflejar las fechas reales de un lote cargado/corregido a mano.
  # Propaga el estado del lote a sus plantas (mismo criterio que avanzar_fase!/transicionar!):
  # solo las fases con plant_state definido, sin tocar plantas descartadas o ya cosechadas.
  def sincronizar_estado_plantas!(lote)
    plant_state = Lote::FASE_A_PLANT_STATE[lote.estado]
    return unless plant_state
    lote.plants.where.not(state: %w[descartada cosechado]).update_all(state: plant_state)
  end

  # POST /lotes/mover  { lote_ids: [], sala_id: }
  #
  # Mueve uno o varios lotes a otra sala, INCLUSO de otra sede. Hasta ahora la única forma de que un
  # lote cambiara de sala era avanzando de fase, así que rebalancear salas, vaciar una para limpieza
  # o corregir un alta obligaba a fingir un avance y ensuciaba la historia del lote.
  #
  # REGLA CENTRAL: lo que la sala impone es el **FOTOPERÍODO**, no la etapa. Una sala en floración
  # está dando 12/12: la planta que entra ahí va a florecer le guste a quien le guste, así que el
  # estado la sigue (y las plantas con él, igual que en `salas#cambiar_fase`).
  #
  # PERO el ENRAIZADO no se toca. Enraizado y vegetativo comparten fotoperíodo —los dos son 18/6—,
  # así que meter un clonador en una sala de vegetativo no le cambia nada: recibe la misma luz. Lo
  # que lo tiene enraizando es que TODAVÍA NO TIENE RAÍZ, un estado de la planta y no algo que el
  # cuarto le haga. Por eso el clonador puede convivir en la sala de vegetativo, y por eso de
  # enraizado se sale cuando prende, no cuando lo cambiás de cuarto.
  #
  # La sede va con la sala: al mover a otra sede, el lote cambia de sede, y eso arrastra a dónde
  # imputan sus costos.
  def mover
    unless %w[admin supervisor cultivador].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    destino = current_user.club.salas.activas.find_by(id: params[:sala_id])
    return render json: { error: 'Sala destino no encontrada o inactiva' }, status: :not_found unless destino

    ids = Array(params[:lote_ids]).map(&:to_i).uniq
    return render json: { error: 'Elegí al menos un lote' }, status: :unprocessable_entity if ids.empty?

    lotes = current_user.club.lotes.where(id: ids, estado: Lote::CULTIVO_ESTADOS).includes(:sala, :plants)
    if lotes.empty?
      return render json: { error: 'Ninguno de los lotes elegidos está en una sala de cultivo' },
                    status: :unprocessable_entity
    end

    # Solo las salas de fase definida imponen fase. Una sala mixta/madre/clon no reescribe nada:
    # ahí conviven fases distintas a propósito.
    fase_destino = destino.kind if %w[vegetativo floracion].include?(destino.kind)

    movidos, cambiaron_fase, plantas = 0, [], 0
    clonadores_mudados = []

    ActiveRecord::Base.transaction do
      lotes.each do |lote|
        sala_anterior   = lote.sala
        estado_anterior = lote.estado
        next if sala_anterior&.id == destino.id   # ya está ahí: no ensuciamos la historia

        attrs = { sala_id: destino.id, sede_id: destino.sede_id }
        # Si estaba en un domo, mudarlo de cuarto lo saca: el clonador no viaja con el lote. Se
        # limpia (y no queda como historia) porque ese domo no llegó a hacerlo prender.
        # EL DOMO VIAJA CON EL LOTE. Un esqueje sin raíz no puede vivir fuera del domo, así que
        # mudarlo de cuarto no lo saca: lo que se muda es el clonador entero (que aloja un solo
        # lote). Del domo se sale al prender, no al cambiar de sala.
        clonador_mudado = nil
        if lote.en_clonador? && lote.clonador.sala_id != destino.id
          clonador_mudado = lote.clonador
          clonador_mudado.sala = destino
          unless clonador_mudado.save
            raise MoverError, "#{lote.codigo}: no se puede llevar su clonador " \
                              "#{clonador_mudado.nombre} a #{destino.nombre} — " \
                              "#{clonador_mudado.errors.full_messages.join(', ')}"
          end
          clonadores_mudados << clonador_mudado.nombre
        end
        enraizando = Plant::ESTADOS_ENRAIZANDO.include?(estado_anterior)
        cambia = fase_destino.present? && fase_destino != estado_anterior && !enraizando
        attrs[:estado] = fase_destino if cambia
        lote.update!(attrs)

        if cambia
          plant_state = Lote::FASE_A_PLANT_STATE[fase_destino]
          if plant_state
            plantas += lote.plants.where.not(state: %w[descartada cosechado]).update_all(state: plant_state)
          end
          cambiaron_fase << { codigo: lote.codigo, de: estado_anterior, a: fase_destino }
        end

        lote.lote_eventos.create!(
          tipo:            cambia ? 'cambio_estado' : 'actividad',
          # Una actividad DEBE declarar categoría (lo valida el modelo). No hay una de "mudanza",
          # así que va 'otro'; lo que cuenta la historia son sala_origen/sala_destino, que existen
          # en el modelo justo para esto.
          categoria:       cambia ? nil : 'otro',
          sala_origen:     sala_anterior,
          sala_destino:    destino,
          estado_anterior: cambia ? estado_anterior : nil,
          estado_nuevo:    cambia ? fase_destino : nil,
          descripcion:     [
            "Movido de #{sala_anterior&.nombre || 'sin sala'} a #{destino.nombre}",
            (sala_anterior&.sede_id != destino.sede_id ? "(cambio de sede)" : nil),
            (clonador_mudado ? "· con su clonador #{clonador_mudado.nombre}" : nil),
            (cambia ? "· #{estado_anterior} → #{fase_destino}" : nil),
          ].compact.join(' '),
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
        )
        movidos += 1
      end
    end

    render json: {
      movidos:            movidos,
      sala_destino:       { id: destino.id, nombre: destino.nombre, kind: destino.kind },
      cambios_de_fase:    cambiaron_fase,
      plantas_afectadas:  plantas,
      clonadores_mudados: clonadores_mudados,
    }
  rescue MoverError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /lotes/:id/registrar_trasplante  { fecha, maceta_origen_l, maceta_destino_l }
  # Registra un trasplante del lote (se puede backdatear): crea un PlantActivity
  # 'transplant' por planta activa con la maceta origen→destino (lo que muestra la
  # timeline) y actualiza el tamaño de maceta actual del lote.
  def registrar_trasplante
    res = Lotes::RegistrarTrasplante.call(
      lote: @lote, usuario: current_user,
      destino: params[:maceta_destino_l], origen: params[:maceta_origen_l], fecha: params[:fecha])
    if res.ok?
      render json: { ok: true, tamanio_maceta: @lote.reload.tamanio_maceta&.to_f }
    else
      render json: { error: res.error }, status: :unprocessable_entity
    end
  end

  # Refleja en la timeline/historial la fecha de inicio (esqueje/semilla): crea o mueve
  # un evento de la fase de origen a la start_date del lote.
  def reconciliar_evento_inicio!(lote)
    return unless lote.start_date
    fase = 'enraizado'
    ts   = lote.start_date.in_time_zone.change(hour: 12)
    ev   = lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: fase).order(:registrado_en).first
    if ev
      ev.update!(registrado_en: ts)
    else
      lote.lote_eventos.create!(
        tipo: 'cambio_estado', estado_nuevo: fase, estado_anterior: nil,
        descripcion: "Inicio (#{fase})", registrado_en: ts,
        user: current_user, club: lote.club,
      )
    end
  end

  # Valida que las fechas de fase queden en orden cronológico. Usa los valores que
  # vienen en el request (start_date + fechas_fase) y, para los que no se tocan, las
  # fechas ya registradas. Devuelve un mensaje de error si algo queda fuera de orden,
  # o nil si está OK. Solo corre si la edición toca fechas.
  def validar_orden_fechas(lote)
    return nil if params[:fechas_fase].blank? && params.dig(:lote, :start_date).blank?

    inicio = parse_fecha(params.dig(:lote, :start_date)) || lote.start_date&.to_date
    veg    = parse_fecha(params.dig(:fechas_fase, :vegetativo)) || fecha_evento(lote, 'vegetativo')
    flo    = parse_fecha(params.dig(:fechas_fase, :floracion))  || fecha_evento(lote, 'floracion')
    cos    = parse_fecha(params.dig(:fechas_fase, :cosecha))    || fecha_evento(lote, 'cosecha')

    secuencia = [['inicio', inicio], ['vegetativo', veg], ['floración', flo], ['cosecha', cos]].select { |_, d| d }
    secuencia.each_cons(2) do |(label_a, fecha_a), (label_b, fecha_b)|
      if fecha_b < fecha_a
        return "La fecha de #{label_b} (#{fecha_b.strftime('%d/%m/%Y')}) no puede ser anterior a la de #{label_a} (#{fecha_a.strftime('%d/%m/%Y')})."
      end
    end
    nil
  end

  def parse_fecha(valor)
    return nil if valor.blank?
    Date.parse(valor.to_s) rescue nil
  end

  def fecha_evento(lote, fase)
    lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: fase).order(:registrado_en).first&.registrado_en&.to_date
  end

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
        @lote.avanzar_fase!(sala_id: params[:sala_id], usuario: current_user)
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

    # La carga de manicura (por QR o manual) ya no pasa por acá: vive en su flujo único
    # (pesajes_manicura#create / plants#registrar_peso). transiciones queda solo para el
    # ciclo de cultivo (vegetativo → floración → cosecha → secado → curado).
    if manicurado
      return render json: { error: 'La manicura se carga desde el flujo de pesajes, no por transiciones' }, status: :unprocessable_entity
    end

    estado_anterior  = @lote.estado
    sala_anterior_id = @lote.sala_id

    # semilla/esqueje → vegetativo: no generan pesada, usan avanzar_fase!
    if @lote.estado == 'enraizado'
      @lote.avanzar_fase!(sala_id: params[:sala_id], usuario: current_user,
                          tamanio_maceta: params[:tamanio_maceta])
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


  # POST /lotes/:id/devolver_manicura
  # El manicura (o admin/sup) devuelve el lote a cosecha porque no está listo para
  # manicurar (p. ej. sigue húmedo). Requiere motivo; desasigna y avisa al admin.
  def devolver_manicura
    authorize @lote, :devolver_manicura?
    @lote.devolver_a_cosecha!(devuelto_por: current_user, motivo: params[:motivo])
    render json: LoteSerializer.serialize(@lote.reload)
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end


  # POST /lotes/:id/reevaluar_manicura
  # Re-evalúa la finalización de un lote en manicura (red de seguridad para lotes que quedaron
  # atascados, o para forzar el chequeo tras cambios). No-op si ya no hay nada que procesar.
  def reevaluar_manicura
    authorize @lote, :devolver_manicura?
    unless @lote.estado == 'en_manicura'
      return render json: { error: 'El lote no está en manicura.' }, status: :unprocessable_entity
    end
    @lote.check_and_finalize_manicura!(finalizador: current_user)
    lote = @lote.reload
    cerrado = %w[curado finalizado].include?(lote.estado)
    render json: {
      estado:  lote.estado,
      mensaje: cerrado ? "Lote cerrado — pasó a #{lote.estado}." : 'Todavía hay plantas pendientes de pesar o descartar.',
      lote:    LoteSerializer.serialize(lote),
    }
  rescue ArgumentError, RuntimeError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
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


  # GET /lotes/:id/preview_plan?plan_trabajo_id=X
  def preview_plan
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end
    plan = current_user.club.plan_trabajos.publicados.find(params[:plan_trabajo_id])
    tareas = AplicarPlanLoteService.new(lote: @lote, plan: plan, ejecutado_por: current_user, fecha_inicio: params[:fecha_inicio]).preview
    render json: {
      plan:   { id: plan.id, titulo: plan.titulo, duracion_dias: plan.duracion_dias },
      tareas: tareas,
      total:  tareas.size,
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  rescue Date::Error, ArgumentError
    render json: { error: 'Fecha de inicio inválida' }, status: :unprocessable_entity
  end

  # POST /lotes/:id/aplicar_plan
  def aplicar_plan
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end
    plan = current_user.club.plan_trabajos.publicados.find(params[:plan_trabajo_id])
    creadas = AplicarPlanLoteService.new(lote: @lote, plan: plan, ejecutado_por: current_user, fecha_inicio: params[:fecha_inicio]).aplicar!
    render json: { tareas_creadas: creadas.size }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  rescue Date::Error
    render json: { error: 'Fecha de inicio inválida' }, status: :unprocessable_entity
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
    # tamanio_maceta: obligatorio al prender (enraizado → vegetativo). Lo valida el modelo.
    @lote.avanzar_fase!(sala_id: params[:sala_id], usuario: current_user,
                        tamanio_maceta: params[:tamanio_maceta])
    @lote.lote_eventos.create!(
      tipo:            'cambio_estado',
      estado_anterior: estado_anterior,
      estado_nuevo:    @lote.estado,
      descripcion:     "Avance de fase: #{estado_anterior} → #{@lote.estado}" +
                       (estado_anterior == 'enraizado' && @lote.tamanio_maceta ? " · a maceta de #{@lote.tamanio_maceta.to_f.round(1)}L" : ''),
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
      # Mantener plants_count_cosechadas al día (idempotente = conteo real de cosechadas).
      # Antes solo se seteaba por PATCH manual → analytics caía siempre al fallback.
      @lote.update_column(:plants_count_cosechadas, @lote.plants.where(state: 'cosechado').count)

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
        @lote.avanzar_fase!(sala_id: params[:sala_id], usuario: current_user)
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
          plantas: acts.size, notas: acts.map(&:description).compact.uniq.first }
      end

    actividades = @lote.lote_eventos.actividades.includes(:user).order(registrado_en: :asc).map do |e|
      meta = LoteEvento::CATEGORIA_META[e.categoria] || {}
      {
        id:          e.id,
        categoria:   e.categoria,
        label:       meta['label'] || e.categoria,
        emoji:       meta['emoji'] || '•',
        descripcion: e.descripcion,
        metadata:    e.metadata || {},
        fecha:       e.registrado_en,
        usuario:     e.user&.first_name,
      }
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
      actividades:,
    }
  end

  FASE_LABELS = {
    'semilla' => 'Enraizado', 'esqueje' => 'Enraizado', 'germinacion' => 'Enraizado',
    'vegetativo' => 'Vegetativo', 'floracion' => 'Floración', 'cosecha' => 'Cosecha',
    'secado' => 'Secado', 'curado' => 'Curado', 'finalizado' => 'Finalizado',
    'en_manicura' => 'En manicura',
  }.freeze

  # GET /lotes/:id/historial
  # Bitácora UNIFICADA del lote: normaliza todo (fases, actividades, registros,
  # tareas completadas, pesadas, stocks, dispensaciones) en una lista plana y
  # ordenada por fecha. Es la fuente única del historial (reemplaza al timeline) y
  # la base de los informes scopeables. `editable`/`deletable` indican qué se puede
  # gestionar desde el historial (solo eventos manuales de lote).
  def historial
    items = []

    @lote.lote_eventos.includes(:user).find_each do |e|
      if e.tipo == 'cambio_estado'
        # Un cambio de fase se puede borrar solo si NO es la fase actual del lote (para
        # limpiar una transición accidental sin romper la fase vigente). Solo admin.
        borrable_fase = current_user.admin? && e.estado_nuevo != @lote.estado
        items << evento_item(e, kind: 'fase', emoji: '🔄',
          titulo: "#{fase_label(e.estado_anterior)} → #{fase_label(e.estado_nuevo)}",
          detalle: e.descripcion, editable: false, deletable: borrable_fase)
      elsif e.tipo == 'actividad'
        meta = LoteEvento::CATEGORIA_META[e.categoria] || {}
        # El trasplante está denormalizado (PlantActivity por planta + maceta del lote):
        # editarlo inline desincronizaría → no editable (se corrige borrando y recargando).
        items << evento_item(e, kind: 'actividad', emoji: meta['emoji'] || '•',
          titulo: meta['label'] || e.categoria, detalle: e.descripcion,
          categoria: e.categoria, metadata: e.metadata || {},
          editable: e.categoria != 'trasplante')
      else # nota / alerta (legacy)
        items << evento_item(e, kind: e.tipo, emoji: (e.tipo == 'alerta' ? '⚠️' : '📝'),
          titulo: e.descripcion, metadata: e.metadata || {})
      end
    end

    @lote.registros_ambientales.includes(:user).find_each do |r|
      chips = []
      chips << "#{r.temperatura}°C" if r.temperatura
      chips << "#{r.humedad}%"      if r.humedad
      chips << "pH #{r.ph}"         if r.ph
      chips << "EC #{r.ec}"         if r.ec
      chips << 'fertilización'      if r.fertilizacion
      items << {
        kind: 'registro', source: 'registro_ambiental', id: r.id, fecha: r.registrado_en,
        emoji: '📋', titulo: 'Registro del lote',
        detalle: [chips.join(' · '), r.observaciones].reject(&:blank?).join(' — ').presence,
        categoria: nil, metadata: {}, usuario: r.user&.nombre_completo,
        editable: false, deletable: true,
      }
    end

    Tarea.where(lote_id: @lote.id, estado: 'completada').includes(:asignada_a).find_each do |t|
      items << {
        kind: 'tarea', source: 'tarea', id: t.id, fecha: t.fecha_completada || t.updated_at,
        emoji: '✅', titulo: t.titulo, detalle: t.notas_completado, categoria: t.tipo,
        metadata: {}, usuario: t.asignada_a&.nombre_completo, editable: false, deletable: true,
      }
    end

    @lote.pesadas.includes(:registrado_por).find_each do |p|
      pesos = []
      pesos << "húmedo #{p.peso_humedo_g}g" if p.peso_humedo_g
      pesos << "seco #{p.peso_seco_g}g"     if p.peso_seco_g
      pesos << "curado #{p.peso_curado_g}g" if p.peso_curado_g
      items << {
        kind: 'pesada', source: 'pesada', id: p.id, fecha: p.registrado_at, emoji: '🏋️',
        titulo: "Pesada (#{fase_label(p.fase_origen)} → #{fase_label(p.fase_destino)})",
        detalle: pesos.join(' · ').presence, categoria: nil, metadata: {},
        usuario: p.registrado_por&.nombre_completo, editable: false, deletable: false,
      }
    end

    @lote.stocks.find_each do |s|
      items << {
        kind: 'stock', source: 'stock', id: s.id, fecha: s.created_at, emoji: '🛒',
        titulo: "Stock generado · #{s.forma_producto}", detalle: "#{s.cantidad.to_f} #{s.unidad}",
        categoria: nil, metadata: {}, usuario: nil, editable: false, deletable: false,
      }
    end

    Dispensacion.joins(:stock).where(stocks: { lote_id: @lote.id }).includes(:paciente, :stock).find_each do |d|
      items << {
        kind: 'dispensacion', source: 'dispensacion', id: d.id, fecha: d.fecha_dispensacion,
        emoji: '🧑‍⚕️', titulo: "Dispensación · #{d.paciente&.nombre} #{d.paciente&.apellido}".strip,
        detalle: "#{d.cantidad.to_f} #{d.stock&.unidad}", categoria: nil, metadata: {},
        usuario: nil, editable: false, deletable: false,
      }
    end

    items.sort_by! { |i| i[:fecha].respond_to?(:to_time) ? i[:fecha].to_time : Time.at(0) }
    render json: { historial: items.reverse }
  end

  # GET /lotes/:id/pl
  def pl
    lote = current_user.club.lotes.includes(:costo_lote, :stocks).find(params[:id])
    render json: calcular_pl(lote)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  private

  def fase_label(estado) = FASE_LABELS[estado] || estado

  # Normaliza un LoteEvento a un item del historial unificado.
  def evento_item(e, kind:, emoji:, titulo:, detalle: nil, categoria: nil, metadata: {}, editable: true, deletable: true)
    {
      kind: kind, source: 'lote_evento', id: e.id, fecha: e.registrado_en,
      emoji: emoji, titulo: titulo, detalle: detalle, categoria: categoria,
      metadata: metadata, usuario: e.user&.nombre_completo,
      editable: editable, deletable: deletable,
    }
  end

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
      'enraizado'  => 'enraizado',
      'vegetativo' => 'vegetativo',
      'floracion'  => 'floracion',
      'cosecha'    => 'cosechado',
      'curado'     => 'cosechado',
      'finalizado' => 'cosechado',
    }[estado] || 'vegetativo'
  end

  # Campo de fecha de la Plant que corresponde a cada state de entrada (para heredar
  # start_date del lote). 'esqueje' no tiene campo propio (dias_en_fase cae a created_at).
  def state_a_fecha_field(state)
    {
      'enraizado'   => :fecha_germinacion,
      'vegetativo'  => :fecha_vegetativo,
      'floracion'   => :fecha_floracion,
      'cosechado'   => :fecha_cosecha,
    }[state]
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
      scope = scope.where(lotes: { estado: 'en_manicura', manicurador_id: current_user.id })
    end
    @lote = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def lote_params
    params.require(:lote).permit(
      # El lote puede nacer YA metido en un domo (nace enraizando, que es cuando corresponde).
      :clonador_id,
      :start_date, :estado, :origen, :planta_madre_id, :plants_count, :strain, :notes,
      :grow_type, :light_type, :genetica_id, :semanas_floracion, :dias_vegetativo_objetivo, :dias_floracion_objetivo, :dias_cosecha_objetivo, :tamanio_maceta,
      :plants_count_objetivo, :rendimiento_objetivo_g, :fecha_cosecha_estimada,
      :rendimiento_real_g, :plants_count_cosechadas,
      :fotoperiodo, :fotoperiodo_vegetativo,
      :tamanio_maceta_inicial, :fecha_trasplante,
      :ph_riego, :fertilizacion_descripcion, :sistema_hidro, :sustrato_especifico,
      planta_madre_ids: []
    )
  end

  def lote_update_params
    params.require(:lote).permit(
      # clonador_id: para sacar un lote del domo a mano (nil) o corregir en cuál está. Que sea de
      # la misma sala y esté enraizando lo valida el modelo, no acá.
      :clonador_id,
      :estado, :start_date, :origen, :planta_madre_id, :plants_count, :strain, :notes,
      :grow_type, :light_type, :genetica_id, :semanas_floracion, :dias_vegetativo_objetivo, :dias_floracion_objetivo, :dias_cosecha_objetivo, :tamanio_maceta,
      :plants_count_objetivo, :rendimiento_objetivo_g, :fecha_cosecha_estimada,
      :rendimiento_real_g, :plants_count_cosechadas,
      :fotoperiodo, :fotoperiodo_vegetativo,
      :tamanio_maceta_inicial, :fecha_trasplante,
      :ph_riego, :fertilizacion_descripcion, :sistema_hidro, :sustrato_especifico,
      planta_madre_ids: []
    )
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
                 when 'enraizado' then dias_semilla
                 when 'vegetativo'         then dias_semilla + dias_vege
                 when 'floracion'          then dias_semilla + dias_vege + dias_flora
                 when 'cosecha'            then dias_semilla + dias_vege + dias_flora + dias_cos
                 else 0
                 end

    return if total_dias <= 0

    fecha_inicio = total_dias.days.ago.to_date
    lote.update_column(:start_date, fecha_inicio)

    estado_inicial = 'enraizado'

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


