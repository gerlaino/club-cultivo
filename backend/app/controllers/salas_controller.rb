# backend/app/controllers/salas_controller.rb
class SalasController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :require_salas_role!
  before_action :set_sala, only: [:show, :update, :destroy, :cargar_lote, :cambiar_fase, :registrar_sala, :registrar_enraizado]

  # Las salas son solo de cultivo (vegetativo/floración). Post-cosecha el lote no usa
  # sala (se ve por estado en Cosecha/Manicura), así que ya no hay transiciones por kind.
  TRANSICIONES_KIND = {}.freeze

  # Salas de proceso (cosecha/curado): se autocrean para conservar la sede del
  # lote post-cosecha, pero NO son salas que el usuario gestione. No se listan en el ABM
  # (los lotes cosechados/en proceso se ven desde Cosecha / Manicura, no como salas).
  KINDS_PROCESO = Sala::KINDS_PROCESO

  def index
    salas = current_user.club.salas
                        .cultivo
                        .includes(:sede, :lotes, :created_by)
                        .order(:nombre)

    if current_user.cultivador? || current_user.manicura?
      salas = salas.where(id: current_user.salas_ids_asignadas)
    elsif current_user.supervisor?
      salas = salas.where(sede_id: current_user.sedes_ids_asignadas)
    end

    render json: salas.map { |s| serialize_sala(s) }
  end

  def show
    render json: serialize_sala_detail(@sala)
  end

  def create
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Solo admins y supervisores pueden crear salas' }, status: :forbidden
    end

    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_sala?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('salas', info[:limites][:salas], plan: info[:label]), status: :payment_required
    end

    if (msg = kind_no_creable(sala_params[:kind]))
      return render json: { error: msg }, status: :unprocessable_entity
    end

    sala = current_user.club.salas.build(sala_params)
    sala.created_by = current_user

    if sala.save
      render json: serialize_sala(sala), status: :created
    else
      render json: { errors: sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    kind_antes = @sala.kind
    kind_nuevo = sala_params[:kind]

    # Tampoco por edición: una sala de vegetativo no se "convierte" en sala de manicura. Se
    # permite guardar una que YA sea de proceso (quedan de la época en que se auto-creaban):
    # si no, no se le podría ni corregir el nombre.
    if kind_nuevo.present? && kind_nuevo != kind_antes && (msg = kind_no_creable(kind_nuevo))
      return render json: { error: msg }, status: :unprocessable_entity
    end

    # Cambiar la fase de la sala ARRASTRA a sus lotes: pasar una sala de floración a vegetativo
    # revegeta todo lo que esté florando adentro y les reinicia el contador de días de fase.
    # Mover lotes a otra sala ya pedía confirmación lote por lote; esta puerta no pedía nada.
    # Sin `confirmar_cambio_fase` no se guarda: devuelve qué lotes se verían afectados.
    # Misma protección que la acción "Cambiar fase": en 12/12 un esqueje sin raíz no prende.
    # Editando el `kind` se podía saltear esa guarda por la puerta de atrás.
    if kind_nuevo == 'floracion' && kind_antes != 'floracion'
      enraizando = @sala.lotes.enraizando
      if enraizando.exists?
        return render json: {
          error: "Esta sala tiene lotes enraizando (#{enraizando.limit(5).pluck(:codigo).join(', ')}). " \
                 'En floración (12/12) los esquejes no prenden: movelos a otra sala antes.',
        }, status: :unprocessable_entity
      end
    end

    afectados = lotes_afectados_por_cambio_de_fase(kind_antes, kind_nuevo)
    if afectados.any? && params[:confirmar_cambio_fase].blank?
      return render json: {
        error: "Cambiar la sala a #{kind_nuevo} cambia de fase a #{afectados.size} lote(s) que están adentro.",
        requiere_confirmacion: true,
        lotes_afectados: afectados.map { |l| serialize_lote_afectado(l, kind_nuevo) },
      }, status: :unprocessable_entity
    end

    if @sala.update(sala_params)
      cascade_kind_a_lotes(kind_antes) if kind_cambio_veg_flo?(kind_antes)
      render json: serialize_sala_detail(@sala.reload)
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @sala.soft_delete!
    head :no_content
  end

  # POST /salas/:id/cargar_lote
  def cargar_lote
    unless current_user.admin? || current_user.cultivador? || current_user.manicura?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    transicion = TRANSICIONES_KIND[@sala.kind]
    unless transicion
      return render json: { error: "Esta sala (#{@sala.kind}) no acepta carga de lotes" }, status: :unprocessable_entity
    end

    lote = current_user.club.lotes.find(params.require(:lote_id))

    unless lote.estado == transicion[:desde]
      return render json: {
        error: "El lote debe estar en '#{transicion[:label_desde]}' para ingresar a esta sala (estado actual: #{lote.estado})"
      }, status: :unprocessable_entity
    end

    lote.update!(sala_id: @sala.id, estado: transicion[:hacia])

    render json: {
      message: "Lote #{lote.codigo} cargado correctamente (#{transicion[:label_desde]} → #{transicion[:label_hacia]})",
      lote: { id: lote.id, codigo: lote.codigo, estado: lote.estado, sala_id: lote.sala_id }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # POST /salas/:id/registrar_sala
  # Crea un RegistroAmbiental en todos los lotes activos de la sala.
  def registrar_sala
    unless %w[admin supervisor cultivador].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    # TODO lo que está físicamente en la sala respira el mismo aire, así que recibe el registro.
    # La lista estaba escrita a mano y se olvidaba de `esqueje` y `germinacion` — justo las fases
    # donde el ambiente más importa, porque un esqueje sin raíz depende del aire para no
    # deshidratarse. `CULTIVO_ESTADOS` es la fuente única: son exactamente los estados para los que
    # el modelo EXIGE sala (ver la validación de sala_id en Lote).
    # ...MENOS los que están ENRAIZANDO: viven en un propagador con su propio microclima (la sala
    # marca 60% de humedad y adentro hay 90%) y su registro entra por `registrar_enraizado`. Sin
    # esta exclusión el lote enraizando acumula dos lecturas contradictorias del mismo momento y
    # las alertas y la analítica promedian un ambiente que no existió.
    lotes_activos = @sala.lotes.where(estado: Lote::CULTIVO_ESTADOS).where.not(estado: 'enraizado')

    if lotes_activos.empty?
      # Si los únicos lotes de la sala están enraizando, decirlo: "no hay lotes activos" haría
      # pensar que la sala está vacía cuando en realidad su registro entra por la otra puerta.
      msg = if @sala.lotes.enraizando.exists?
              'Los lotes de esta sala están enraizando: registrá su ambiente con "Registrar enraizado".'
            else
              'No hay lotes activos en esta sala'
            end
      return render json: { error: msg }, status: :unprocessable_entity
    end

    count = 0
    ActiveRecord::Base.transaction do
      lotes_activos.each do |lote|
        registro = lote.registros_ambientales.build(sala_registro_params)
        registro.user          = current_user
        registro.club          = current_user.club
        registro.registrado_en = Time.current
        registro.save!
        count += 1
      end
    end

    render json: { lotes_afectados: count }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /salas/:id/registrar_enraizado
  # El clima del PROPAGADOR, para todos los lotes que están enraizando en esta sala. Va aparte del
  # registro de la sala porque adentro del domo hay otro ambiente: el cuarto marca 60% de humedad y
  # adentro hay 90%. Sin esto se les grababa el clima del cuarto, que no es el suyo.
  #
  # Es UN registro para todos los que enraízan en la sala: la app no modela cada domo como espacio
  # físico (ver la migración `EliminarClonadores`), así que se asume que todos comparten condiciones.
  def registrar_enraizado
    unless %w[admin supervisor cultivador].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    lotes = @sala.lotes.enraizando
    if lotes.empty?
      return render json: { error: 'No hay lotes enraizando en esta sala' }, status: :unprocessable_entity
    end

    count = 0
    ActiveRecord::Base.transaction do
      lotes.each do |lote|
        r = lote.registros_ambientales.build(enraizado_registro_params)
        r.user          = current_user
        r.club          = current_user.club
        r.registrado_en = Time.current
        r.fuente        = 'manual'
        # El punto de medición ('incubadora') lo pone el modelo a partir del estado del lote:
        # todos estos están enraizando. Ver RegistroAmbiental#punto_segun_estado_del_lote.
        r.save!
        count += 1
      end
    end

    render json: { lotes_afectados: count }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /salas/:id/cambiar_fase
  # Cambia toda la sala de vegetativo ↔ floración. Afecta lotes y plantas activas.
  # Accesible a admin, supervisor y cultivador.
  def cambiar_fase
    unless %w[admin supervisor cultivador].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    unless %w[vegetativo floracion].include?(@sala.kind)
      return render json: { error: 'Solo las salas en vegetativo o floración pueden cambiar de fase' }, status: :unprocessable_entity
    end

    nueva_fase        = @sala.kind == 'vegetativo' ? 'floracion' : 'vegetativo'

    # La sala no se da vuelta con lotes enraizando adentro: 12/12 le daría 12 horas de oscuridad a
    # esquejes que necesitan luz casi continua. La regla protege A LA PLANTA, así que mira el estado
    # del lote y no el equipamiento —un esqueje sin domo corre el mismo riesgo—.
    if nueva_fase == 'floracion'
      enraizando = @sala.lotes.enraizando
      if enraizando.exists?
        codigos = enraizando.limit(5).pluck(:codigo).join(', ')
        return render json: {
          error: "Esta sala tiene lotes enraizando (#{codigos}). En floración (12/12) los esquejes " \
                 'no prenden: movelos a otra sala antes de cambiar la fase.'
        }, status: :unprocessable_entity
      end
    end
    plant_state_orig  = @sala.kind   # 'vegetativo' | 'floracion'
    plant_state_dest  = nueva_fase

    lotes_a_cambiar = @sala.lotes.where(estado: @sala.kind)

    if lotes_a_cambiar.empty?
      return render json: {
        error: "No hay lotes en #{@sala.kind} en esta sala para cambiar de fase"
      }, status: :unprocessable_entity
    end

    lotes_count   = 0
    plantas_count = 0

    ActiveRecord::Base.transaction do
      # La SALA se da vuelta primero: es ella la que arrastra a los lotes. Al revés, cada lote
      # pasaba a floración mientras su sala todavía figuraba en vegetativo, un estado
      # intermedio que no existe en la realidad (y que la validación sala↔estado rechaza).
      @sala.update!(kind: nueva_fase)

      lotes_a_cambiar.each do |lote|
        estado_anterior = lote.estado
        plantas = lote.plants.where(state: plant_state_orig)
        plantas_count += plantas.count
        plantas.update_all(state: plant_state_dest)

        lote.update!(estado: nueva_fase)

        lote.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: estado_anterior,
          estado_nuevo:    nueva_fase,
          descripcion:     "Cambio de fase grupal desde sala #{@sala.nombre}: #{estado_anterior} → #{nueva_fase}",
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
        )

        lotes_count += 1
      end
    end

    render json: {
      sala:              serialize_sala_detail(@sala.reload),
      nueva_fase:        nueva_fase,
      lotes_afectados:   lotes_count,
      plantas_afectadas: plantas_count,
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  # Las salas son SOLO de cultivo. Manicura y cosecha son etapas por las que pasa el LOTE
  # (`en_manicura`, `cosecha`), no lugares que alguien tenga que dar de alta: `asignar_manicurador!`
  # no crea ninguna sala. Quedaron salas así de cuando se auto-creaban ("Cosecha · Sede"), por eso
  # el kind sigue siendo válido para las existentes — lo que se cierra es la puerta de crear una nueva.
  # La pantalla ya no las ofrece; esto es para que tampoco entren por la API.
  ETAPAS_NO_SALA = { 'manicura' => 'La manicura', 'cosecha' => 'La cosecha', 'curado' => 'El curado' }.freeze

  def kind_no_creable(kind)
    return nil if kind.blank?

    etapa = ETAPAS_NO_SALA[kind.to_s]
    return nil unless etapa

    "#{etapa} es una etapa del lote, no una sala: no hace falta crearla. " \
      'Las salas son de vegetativo o floración.'
  end

  def set_sala
    scope = current_user.club.salas
    if current_user.cultivador? || current_user.manicura?
      scope = scope.where(id: current_user.salas_ids_asignadas)
    elsif current_user.supervisor?
      scope = scope.where(sede_id: current_user.sedes_ids_asignadas)
    end
    @sala = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def require_salas_role!
    blocked = %w[auditor abogado paciente]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  KINDS_VEG_FLO = %w[vegetativo floracion].freeze

  def kind_cambio_veg_flo?(kind_antes)
    KINDS_VEG_FLO.include?(kind_antes) && KINDS_VEG_FLO.include?(@sala.kind) && kind_antes != @sala.kind
  end

  # Los lotes que el cascade tocaría: los que están en la fase vieja de esta sala.
  def lotes_afectados_por_cambio_de_fase(kind_antes, kind_nuevo)
    return Lote.none if kind_nuevo.blank? || kind_antes == kind_nuevo
    return Lote.none unless KINDS_VEG_FLO.include?(kind_antes) && KINDS_VEG_FLO.include?(kind_nuevo)

    @sala.lotes.where(estado: kind_antes)
  end

  # Cuántos días lleva el lote en la fase que está por perder. Sale del último cambio de estado,
  # igual que `dias_en_estado` del serializer — el cascade crea un evento nuevo y lo reinicia.
  def serialize_lote_afectado(lote, kind_nuevo)
    desde = lote.lote_eventos
                .where(tipo: 'cambio_estado', estado_nuevo: lote.estado)
                .order(registrado_en: :desc).first&.registrado_en&.to_date

    {
      id:              lote.id,
      codigo:          lote.codigo,
      estado_actual:   lote.estado,
      estado_nuevo:    kind_nuevo,
      plantas:         lote.plants.where.not(state: %w[descartada cosechado]).count,
      dias_en_fase:    desde ? (Date.current - desde).to_i : nil,
    }
  end

  def cascade_kind_a_lotes(kind_antes)
    nueva_fase = @sala.kind
    lotes = @sala.lotes.where(estado: kind_antes)
    return if lotes.empty?

    ActiveRecord::Base.transaction do
      lotes.each do |lote|
        lote.plants.where(state: kind_antes).update_all(state: nueva_fase)
        lote.update!(estado: nueva_fase)
        lote.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: kind_antes,
          estado_nuevo:    nueva_fase,
          descripcion:     "Cambio de fase por edición de sala #{@sala.nombre}: #{kind_antes} → #{nueva_fase}",
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
        )
      end
    end
  end

  # Solo lo que existe en un propagador: aire, sustrato y el producto usado para enraizar. No hay
  # riego, ni EC, ni pH — un esqueje sin raíz no absorbe, y pedirlo sería inventar el dato.
  def enraizado_registro_params
    params.require(:registro_ambiental)
          .permit(:temperatura, :humedad, :temperatura_sustrato, :producto_enraizante, :notas)
  end

  def sala_registro_params
    params.require(:registro_ambiental).permit(
      :temperatura, :humedad, :co2, :ph, :ec,
      :temperatura_sustrato, :ph_runoff, :ec_runoff, :ppfd,
      :horas_luz, :espectro_luz, :fase_nutricional,
      :ml_nutrientes_litro, :notas_nutricion,
      :fertilizacion, :notas_fertilizacion,
      :estado_general, :plagas_observadas,
      :observaciones, :fuente,
      tareas_realizadas: []
    )
  end

  def sala_params
    params.require(:sala).permit(
      :nombre, :state, :kind, :notes, :pots_count, :sede_id,
      :camera_stream_url, :camera_snapshot_url, :responsable_id,
      # Cuánto más fría está la hoja que el aire: define el VPD que se muestra.
      :leaf_temp_offset
    )
  end

  def serialize_sala(s)
    {
      id:                   s.id,
      club_id:              s.club_id,
      nombre:               s.nombre,
      tipo:                 s.tipo,
      state:                s.state,
      kind:                 s.kind,
      notes:                s.notes,
      pots_count:           s.pots_count,   # posiciones físicas para el Layout (no es capacidad)
      leaf_temp_offset:     s.leaf_temp_offset&.to_f,
      # Conteo LIVE (no el denormalizado plants_count/plantas_totales que driftea): plantas
      # vivas en los lotes de la sala.
      plantas_totales:      Plant.joins(:lote).where(lotes: { sala_id: s.id })
                                 .where.not(plants: { state: %w[cosechado descartada] }).count,
      lotes_count:          s.lotes.count,
      sede_id:              s.sede_id,
      sede: s.sede ? { id: s.sede.id, nombre: s.sede.nombre, tipo: s.sede.tipo } : nil,
      created_at:           s.created_at,
      created_by_name:      s.created_by_name,
      lotes_activos:        s.lotes.where(estado: ['vegetativo','floracion']).count,
      lotes_activos_count:  s.lotes.where.not(estado: ['finalizado','curado']).count,
      updated_at:           s.updated_at,
      responsable_id:      s.responsable_id,
      responsable_nombre:  s.responsable&.nombre_completo,
      cultivadores:        s.cultivadores.map { |c| { id: c.id, nombre: c.nombre_completo } },
      camera_stream_url:   s.camera_stream_url,
      camera_snapshot_url: s.camera_snapshot_url,
    }
  end

  def serialize_sala_detail(s)
    lotes_all = s.lotes.includes(:genetica, fotos_attachments: :blob).order(start_date: :desc, created_at: :desc)
    lote_ids  = lotes_all.map(&:id)

    # Conteo VIVO de plantas por lote (excluye descartadas; el default scope ya excluye
    # las eliminadas). Es la verdad, no el campo plants_count denormalizado que puede driftear.
    plantas_vivas_por_lote = Plant.where(lote_id: lote_ids).where.not(state: 'descartada').group(:lote_id).count
    plantas_vivas = ->(id) { plantas_vivas_por_lote[id] || 0 }

    fecha_cosecha_por_lote =
      lote_ids.any? ?
        Plant.where(lote_id: lote_ids)
             .where.not(fecha_cosecha: nil)
             .group(:lote_id)
             .maximum(:fecha_cosecha)
      : {}

    # Cuándo entró cada lote a su estado ACTUAL, en una sola query (nada de N+1). Es lo que permite
    # que la columna de días diga algo en los lotes en curso: `duracion` solo existe cuando ya
    # cosecharon, y hasta entonces la tabla mostraba "—" en todo.
    ultimo_cambio = LoteEvento.where(lote_id: lote_ids, tipo: 'cambio_estado')
                              .group(:lote_id, :estado_nuevo).maximum(:registrado_en)

    lotes_historial = lotes_all.map do |l|
      fecha_cosecha = fecha_cosecha_por_lote[l.id]
      duracion = l.start_date && fecha_cosecha ? (fecha_cosecha.to_date - l.start_date).to_i : nil
      # Fallback a start_date: un lote que nunca cambió de estado lleva en él desde que arrancó.
      desde_estado   = ultimo_cambio[[l.id, l.estado]]&.to_date || l.start_date
      dias_en_estado = desde_estado ? (Date.current - desde_estado).to_i : nil
      {
        id:                 l.id,
        codigo:             l.codigo,
        estado:             l.estado,
        start_date:         l.start_date,
        plants_count:       plantas_vivas.(l.id),
        genetica_nombre:    l.genetica&.nombre,
        rendimiento_real_g: l.rendimiento_real_g&.to_f,
        fecha_cosecha:      fecha_cosecha,
        # `duracion_dias` es el ciclo CERRADO (solo si cosechó) y es lo único comparable entre
        # cultivos. `dias_transcurridos` corre siempre, y `dias_en_estado` dice hace cuánto que el
        # lote no se mueve —que en un enraizado estancado es la señal a mirar—.
        duracion_dias:      duracion,
        dias_transcurridos: l.start_date ? (Date.current - l.start_date).to_i : nil,
        dias_en_estado:     dias_en_estado,
        # Foto de portada del lote para el slot del layout (portada marcada → última subida).
        foto_url:           (att = l.foto_portada_attachment) ? url_for(att) : nil,
      }
    end

    vals_rend      = lotes_historial.filter_map { |l| l[:rendimiento_real_g] }
    ciclos_fin     = lotes_historial.count { |l| l[:estado] == 'finalizado' }
    duraciones     = lotes_historial.filter_map { |l| l[:duracion_dias] }

    historial_kpis = {
      total_ciclos:           lotes_historial.size,
      ciclos_finalizados:     ciclos_fin,
      duracion_promedio_dias: duraciones.any? ? (duraciones.sum.to_f / duraciones.size).round(0).to_i : nil,
      rendimiento_promedio_g: vals_rend.any? ? (vals_rend.sum / vals_rend.size).round(1) : nil,
    }

    serialize_sala(s).merge(
      lotes: lotes_all.map { |l|
        { id: l.id, codigo: l.codigo, estado: l.estado, plants_count: plantas_vivas.(l.id) }
      },
      lotes_historial:,
      historial_kpis:,
      ambiente_actual: ambiente_actual(s),
      # El clima del propagador va aparte, nunca mezclado con el del cuarto: son dos aires
      # distintos con dos objetivos distintos. Es nil cuando la sala no tiene nada enraizando.
      ambiente_incubadora: ambiente_actual(s, punto: 'incubadora'),
    )
  end

  # Último ambiente conocido DE ESTA SALA.
  #
  # Va siempre con `registrado_en` y de qué lote salió: sin sensores conectados este dato puede ser
  # de hace una semana, y mostrarlo pelado te haría creer que es de ahora. Un dato ambiental viejo
  # sin fecha es peor que no tener dato.
  # `punto`: 'sala' (el aire del cuarto, lo que el KPI llama ambiente) o 'incubadora' (el
  # propagador de los lotes enraizando, que tiene su propio clima). Sin separarlos, el KPI de la
  # sala mostraba los 28 °C / 90 % de adentro de la bandeja como si fueran los del cuarto.
  def ambiente_actual(sala, punto: 'sala')
    # FUENTE PRIMARIA: `LecturaAmbiental`, que guarda `sala_id` AL MOMENTO de medir. `RegistroAmbiental`
    # cuelga del lote y no sabe dónde se midió: al mover un lote de cuarto, sus registros viejos se le
    # atribuían a la sala NUEVA. Una sala sin actividad terminaba mostrando el aire de otra.
    ult = LecturaAmbiental.where(sala_id: sala.id, punto_medicion: punto, tipo: %w[temperatura humedad])
                          .order(medido_at: :desc).first

    if ult
      # Los valores del MISMO momento: una temperatura de hoy con una humedad de anteayer no
      # describen el mismo aire, y el VPD que sale de mezclarlas es inventado.
      hermanas = LecturaAmbiental.where(sala_id: sala.id, punto_medicion: punto, medido_at: ult.medido_at)
      temp = hermanas.find { |l| l.tipo == 'temperatura' }&.valor&.to_f
      hum  = hermanas.find { |l| l.tipo == 'humedad' }&.valor&.to_f
      return {
        temperatura:   temp,
        humedad:       hum,
        vpd:           vpd_kpa(temp, hum),
        co2:           hermanas.find { |l| l.tipo == 'co2' }&.valor&.to_f,
        registrado_en: ult.medido_at,
        lote_codigo:   Lote.find_by(id: ult.lote_id)&.codigo,
        fuente:        ult.fuente,
        punto:         punto,
      }
    end

    # Sin lecturas no hay dato ATRIBUIBLE a esta sala. Antes se caía al último RegistroAmbiental de
    # cualquier lote de la sala, y como el registro no sabe dónde se midió, eso era adivinar: es
    # justo lo que hacía que una sala mostrara el aire de otra. Mejor "sin datos" que un dato de
    # otro cuarto.
    nil
  end

  # VPD (déficit de presión de vapor) en kPa, con la temperatura de HOJA estimada 2 °C por debajo
  # de la del aire —la hoja transpira y se enfría—. Es la métrica que de verdad dice si el cuarto
  # está bien: 25 °C con 40% y 25 °C con 70% son dos mundos distintos y el promedio de temperatura
  # solo no los distingue. Fórmula de Tetens para la presión de vapor de saturación.
  def vpd_kpa(temp_aire, humedad)
    return nil if temp_aire.nil? || humedad.nil?

    t_hoja = temp_aire - 2.0
    svp_hoja = 0.61078 * Math.exp((17.27 * t_hoja) / (t_hoja + 237.3))
    svp_aire = 0.61078 * Math.exp((17.27 * temp_aire) / (temp_aire + 237.3))
    avp = svp_aire * (humedad / 100.0)
    [(svp_hoja - avp).round(2), 0.0].max
  end
end
