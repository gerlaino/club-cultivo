class Lote < ApplicationRecord
  include RestorableInterface
  include Auditable
  no_auditar :plants_count # contador de cache: cambia solo al agregar/quitar plantas (ruido)
  belongs_to :deleted_by, class_name: "User", optional: true
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :sala, optional: true
  belongs_to :sede, optional: true
  # De qué lote se desprendió, si nació separándose de otro (ver `Lotes::Desprender`).
  belongs_to :lote_origen, class_name: 'Lote', optional: true
  has_many   :desprendidos, class_name: 'Lote', foreign_key: :lote_origen_id, dependent: :nullify
  # La sala es solo de cultivo. Post-cosecha el lote no tiene sala (se ve por estado),
  # pero conserva su sede. Exigimos sala solo en estados de cultivo.
  CULTIVO_ESTADOS = %w[enraizado vegetativo floracion].freeze
  validates :sala_id, presence: true, if: -> { CULTIVO_ESTADOS.include?(estado) }
  belongs_to :genetica,    optional: true
  belongs_to :manicurador,   class_name: 'User',  optional: true
  belongs_to :planta_madre,  class_name: 'Plant', optional: true
  has_many :plants,                dependent: :destroy
  has_one  :costo_lote,            dependent: :destroy
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :nullify
  has_many :registros_ambientales, class_name: 'RegistroAmbiental', dependent: :destroy
  has_many :lote_eventos,          dependent: :destroy
  has_many :pesadas,               -> { order(registrado_at: :asc) }, dependent: :destroy
  has_many :stocks,                dependent: :nullify
  # class_name explícito: Rails inferiría "PesajesManicura" (clase inexistente)
  has_many :pesajes_manicura,      class_name: 'PesajeManicura', dependent: :destroy
  has_many_attached :fotos
  has_many :notas,      as: :noteable,              dependent: :destroy
  has_many :analisis_ia, class_name: 'AnalisisIa', dependent: :destroy
  # class_name explícito: el nombre ya es "singular", Rails no lo inferiría bien.
  has_many :analisis_laboratorio, class_name: 'AnalisisLaboratorio', dependent: :destroy

  # Secuencia: enraizado → vegetativo → floración → cosecha → en_manicura
  # (admin asigna manicura) → curado (se confirma el pesaje + se crea el stock; acá
  # empieza el curado) → finalizado (cuando se agota el stock del lote).
  # ENRAIZADO es una sola etapa —la planta todavía no tiene raíz funcional— y venga de semilla o
  # de esqueje es la misma fisiología. De dónde viene se guarda aparte, en `origen`: son dos ejes
  # independientes, y mezclarlos obligaba a duplicar setpoints y reglas para algo idéntico.
  # La aprobación del pesaje vive en PesajeManicura (estado enviado→confirmado), no en
  # un estado del lote: el lote sigue 'en_manicura' hasta que se confirma y pasa a 'curado'.
  # 'secado' YA NO es un estado: es una métrica (días de cosecha→stock). Ver dias_secado.
  ESTADOS       = %w[enraizado vegetativo floracion cosecha en_manicura curado finalizado].freeze
  ORIGENES      = %w[semilla esqueje].freeze # de dónde viene la planta (NO es una fase)
  # Secuencia de avance con sala (el botón "avanzar fase" va al siguiente): germinación →
  # enraizado → vegetativo → floración → cosecha. El enraizado avanza sin pesada.
  AVANCE        = %w[enraizado vegetativo floracion cosecha].freeze
  # Camino de cultivo con pesada/avance (con sala). Post-cosecha (en_manicura/curado)
  # se maneja por el flujo de manicura, no por avanzar_fase!.
  CICLO_FASES   = %w[vegetativo floracion cosecha].freeze
  # Estados post-cosecha: el lote NO tiene sala (se ve por estado en Cosecha/Manicura).
  POST_COSECHA  = %w[cosecha en_manicura curado finalizado].freeze
  TIPOS_CULTIVO = %w[sustrato hidroponia].freeze
  TIPOS_LUZ     = %w[led hps cmh natural mixta].freeze
  SUSTRATOS     = %w[tierra coco perlita mezcla rockwool fibra_coco].freeze
  FOTOPERIODOS  = %w[20/4 18/6 16/8 12/12 auto].freeze

  validates :codigo,            uniqueness: { scope: :club_id, conditions: -> { where(deleted_at: nil) } }, allow_blank: true
  validates :estado,            inclusion: { in: ESTADOS }, allow_blank: false
  validates :plants_count,      numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :grow_type,         inclusion: { in: TIPOS_CULTIVO }, allow_blank: true
  validates :light_type,        inclusion: { in: TIPOS_LUZ },     allow_blank: true
  validates :tamanio_maceta,    numericality: { greater_than: 0 }, allow_nil: true
  validates :semanas_floracion, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true # deprecado
  validates :dias_vegetativo_objetivo, :dias_floracion_objetivo, :dias_cosecha_objetivo,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :start_date,        presence: true
  # Al prender, el esqueje va a maceta: sin ese dato el lote entra a vegetativo sin saber en qué
  # volumen crece, que es lo que gobierna riego, frecuencia y cuándo toca trasplante.
  validate :maceta_al_prender, if: -> { estado_changed? && estado_was == 'enraizado' && estado == 'vegetativo' }

  before_create :generar_codigo
  before_create :generar_codigo_qr
  after_commit  :dispatch_webhook_avance,  on: [:create, :update]

  # Todo lote de cultivo arranca ENRAIZANDO, venga de semilla o de esqueje. Solo aplica al
  # crear un lote nuevo sin estado explícito (las plantas siguen el estado del lote vía
  # sincronizar_estado_plantas!, no un guard rígido — un lote de semilla SÍ puede avanzar a esqueje).
  def estado_inicial_para_origen
    'enraizado'
  end

  default_scope { where(deleted_at: nil) }

  # Los que están enraizando: viven en un propagador con su propio clima (la sala marca 60% de
  # humedad y adentro hay 90%), así que el registro de la sala no les corresponde.
  scope :enraizando, -> { where(estado: 'enraizado') }
  scope :activos,     -> { where.not(estado: 'finalizado') }
  scope :en_ciclo,    -> { where(estado: CICLO_FASES + ['finalizado']) }
  scope :finalizados, -> { where(estado: 'finalizado') }
  scope :por_sala,    ->(sala_id) { where(sala_id: sala_id) }
  scope :recientes,   -> { order(created_at: :desc) }

  def soft_delete!
    transaction do
      # OJO: update_column saltea callbacks Y los `dependent:` de las asociaciones. Los hijos
      # que se consultan A TRAVÉS del lote (plants, pesadas, lote_eventos, y también los stocks
      # via `stock.lote`) quedan ocultos junto con él y vuelven si se restaura — reversible.
      # El caso problemático son las jornadas de manicura PENDIENTES (borrador/enviado): se
      # consultan independientes del lote (board del admin) y sin lote no se pueden confirmar,
      # así que quedaban huérfanas apuntando a un lote inexistente → 500 al gestionarlas.
      # Se limpian acá (no es reversible, pero una manicura sin lote no tiene sentido).
      pesajes_manicura.where(estado: %w[borrador enviado]).destroy_all
      update_column(:deleted_at, Time.current)
    end
  end

  def dias_desde_inicio
    return 0 unless start_date
    (Date.today - start_date).to_i
  end

  # ── Los tres relojes del lote ──────────────────────────────────────────────
  # El ciclo se cuenta DESDE QUE ENTRA A VEGETATIVO, no desde el esqueje. En el domo la planta no
  # crece: gasta reservas en emitir raíz y ni siquiera come (por eso su registro no tiene EC ni pH).
  # Contar el enraizado como vegetativo hace que un lote que tardó 20 días en prender aparente 20
  # días más de vege sin haber hecho un nudo más, y ahí se pierde toda comparación entre lotes.
  # El enraizado se informa aparte —"45 días de ciclo + 12 enraizando"— para no perder el panorama.

  # Fallback a start_date: los lotes viejos y los heredados no tienen el evento de vegetativo, y sin
  # esto sus métricas históricas se vaciarían de golpe.
  def fecha_inicio_vegetativo
    ev = lote_eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'vegetativo' }
                     .min_by(&:registrado_en)
    ev&.registrado_en&.to_date || (estado == 'enraizado' ? nil : start_date)
  end

  def fecha_inicio_floracion
    lote_eventos.select { |e| e.tipo == 'cambio_estado' && e.estado_nuevo == 'floracion' }
                .min_by(&:registrado_en)&.registrado_en&.to_date
  end

  # Cuánto tardó en prender. Si todavía enraíza, va corriendo: es lo que delata un propagador
  # con problemas (manta térmica muerta, humedad baja) antes de que caiga el prendimiento.
  def dias_enraizado
    return nil unless start_date
    hasta = fecha_inicio_vegetativo || Date.current
    [(hasta - start_date).to_i, 0].max
  end

  # El ciclo productivo. nil mientras enraíza: todavía no arrancó.
  def dias_ciclo
    f = fecha_inicio_vegetativo
    f ? (Date.current - f).to_i : nil
  end

  # Foto de portada del lote (para el slot del layout de la sala): la marcada como portada si
  # sigue adjunta, o la última subida si no hay marcada. nil si el lote no tiene fotos.
  def foto_portada_attachment
    return nil unless fotos.attached?
    atts = fotos.attachments.to_a
    (foto_portada_blob_id && atts.find { |a| a.blob_id == foto_portada_blob_id }) ||
      atts.max_by { |a| [a.created_at, a.id] }
  end

  def progreso_ciclo
    case estado
    when 'enraizado'           then 0
    when 'vegetativo'          then 20
    when 'floracion'           then 40
    when 'cosecha'             then 60
    when 'en_manicura'         then 72
    when 'curado'              then 92
    when 'finalizado'          then 100
    else 0
    end
  end

  FASE_A_PLANT_STATE = {
    'enraizado'   => 'enraizado',
    'vegetativo'  => 'vegetativo',
    'floracion'   => 'floracion',
    'cosecha'     => 'cosechado',
  }.freeze

  # Avance rápido sin pesada — usado por el cultivador desde el botón "Avanzar fase".
  # Si sala_id se provee, mueve el lote a esa sala. Si no, intenta auto-detectar:
  # si existe exactamente una sala activa del tipo destino en el club, la elige.
  def avanzar_fase!(sala_id: nil, usuario: nil, tamanio_maceta: nil)
    idx = AVANCE.index(estado)
    raise ArgumentError, 'Lote no puede transicionar en este estado' unless idx.present? && idx < AVANCE.length - 1
    nueva_fase = AVANCE[idx + 1] # enraizado→vegetativo→floración→cosecha
    ActiveRecord::Base.transaction do
      attrs = { estado: nueva_fase }
      # La maceta del trasplante al prender. Si es la primera que tiene, también queda como la
      # INICIAL: es la que después deja reconstruir el historial de trasplantes.
      if tamanio_maceta.present?
        attrs[:tamanio_maceta] = tamanio_maceta
        attrs[:tamanio_maceta_inicial] = tamanio_maceta if tamanio_maceta_inicial.blank?
      end
      if POST_COSECHA.include?(nueva_fase)
        # Cosecha: el lote sale de la sala de cultivo (libera el slot) y conserva la sede.
        attrs[:sede]    = sede || sala&.sede
        attrs[:sala_id] = nil
      else
        sala_nueva = if sala_id.present?
          club.salas.activas.find_by(id: sala_id)
        else
          candidatas = club.salas.activas.de_tipo(nueva_fase).to_a
          candidatas.length == 1 ? candidatas.first : nil
        end
        attrs[:sala] = sala_nueva if sala_nueva
      end
      update!(attrs)

      plant_state = FASE_A_PLANT_STATE[nueva_fase]
      plants.where.not(state: %w[descartada cosechado]).update_all(state: plant_state) if plant_state
    end
  end

  # Avanza el lote al siguiente paso del ciclo (vegetativo→floracion→secado→curado).
  # Crea la pesada y mueve el lote a la sala destino (creándola si hace falta).
  # pesada_attrs debe incluir: registrado_por (User), y el peso según fase_destino.
  def transicionar!(nueva_fase, pesada_attrs:, manicurado: false, pesadas_plantas_attrs: [], sala_id: nil)
    raise ArgumentError, "Fase inválida: #{nueva_fase}" unless CICLO_FASES.include?(nueva_fase)
    raise "El lote ya está finalizado" if estado == 'finalizado'

    idx_actual = CICLO_FASES.index(estado)
    idx_nueva  = CICLO_FASES.index(nueva_fase)

    raise "El lote (estado '#{estado}') no está en el ciclo de transición" if idx_actual.nil?
    raise "Solo se puede avanzar al paso siguiente (esperado: #{CICLO_FASES[idx_actual + 1]})" \
      unless idx_nueva == idx_actual + 1

    registrado_por = pesada_attrs[:registrado_por] || pesada_attrs['registrado_por']
    raise ArgumentError, "registrado_por es obligatorio" unless registrado_por

    ActiveRecord::Base.transaction do
      pesada = pesadas.create!(
        fase_origen:    estado,
        fase_destino:   nueva_fase,
        manicurado:     manicurado,
        registrado_por: registrado_por,
        registrado_at:  Time.current,
        notas:          pesada_attrs[:notas],
        peso_humedo_g:  pesada_attrs[:peso_humedo_g],
        peso_seco_g:    pesada_attrs[:peso_seco_g],
        peso_curado_g:  pesada_attrs[:peso_curado_g],
      )

      pesadas_plantas_attrs.each do |pp|
        pesada.pesadas_plantas.create!(
          plant_id:    pp[:plant_id] || pp['plant_id'],
          peso_humedo_g: pp[:peso_humedo_g] || pp['peso_humedo_g'],
          peso_seco_g:   pp[:peso_seco_g]   || pp['peso_seco_g'],
        )
      end

      # Cosecha (única fase post-cosecha alcanzable por transicionar!): sale de la sala
      # de cultivo y conserva la sede. El resto (vegetativo/floración) usa su sala.
      attrs = { estado: nueva_fase }
      if POST_COSECHA.include?(nueva_fase)
        attrs[:sede]    = sede || sala&.sede
        attrs[:sala_id] = nil
      elsif sala_id.present?
        sala_nueva = club.salas.activas.find_by(id: sala_id)
        attrs[:sala] = sala_nueva if sala_nueva
      end
      update!(attrs)

      plant_state = FASE_A_PLANT_STATE[nueva_fase]
      plants.where.not(state: %w[descartada cosechado]).update_all(state: plant_state) if plant_state
    end
  end

  # Admin asigna un manicurador → cosecha → en_manicura (nuevo flujo).
  ROLES_MANICURA = %w[manicura admin supervisor].freeze

  def asignar_manicurador!(manicurador:, asignado_por:, sala_id: nil)
    raise ArgumentError, "El lote no está en cosecha" unless estado == 'cosecha'
    raise ArgumentError, "El usuario no tiene rol válido para manicura" unless ROLES_MANICURA.include?(manicurador.role)

    # Post-cosecha no usa sala (se ve en la sección Manicura por estado).
    ActiveRecord::Base.transaction do
      update!(estado: 'en_manicura', manicurador: manicurador)
      lote_eventos.create!(
        tipo:            'cambio_estado',
        estado_anterior: 'cosecha',
        estado_nuevo:    'en_manicura',
        descripcion:     "Asignado a manicura: #{manicurador.first_name || manicurador.email}",
        user:            asignado_por,
        club:            club,
        registrado_en:   Time.current,
      )
      AlertaInterna.create!(
        club:             club,
        tipo:             'manicura_asignada',
        mensaje:          "Lote #{codigo} asignado para manicura — #{plants_count_cosechadas || plants_count} plantas",
        severidad:        'info',
        creada_por:       asignado_por,
        destinada_a_role: manicurador.role,
        contexto:         { lote_id: id, lote_codigo: codigo, manicurador_id: manicurador.id }
      )
    end
  end

  # Camino inverso: el manicura (o admin/sup) devuelve el lote a cosecha porque no está
  # listo para manicurar (típico: la flor sigue húmeda y necesita más secado). Solo es
  # válido si todavía no hay pesaje confirmado — un confirmado ya generó stock de flor
  # seca, así que volver atrás rompería la trazabilidad. Desasigna el manicurador: el lote
  # vuelve a la cola de cosecha y el admin lo reasigna cuando esté pronto.
  def devolver_a_cosecha!(devuelto_por:, motivo:)
    raise ArgumentError, "El lote no está en manicura" unless estado == 'en_manicura'
    motivo = motivo.to_s.strip
    raise ArgumentError, "Contanos por qué no se puede manicurar (motivo obligatorio)" if motivo.blank?
    if pesajes_manicura.where(estado: 'confirmado').exists?
      raise "El lote ya tiene un pesaje confirmado: no se puede devolver a cosecha"
    end

    quien = devuelto_por.first_name.presence || devuelto_por.email
    manicurador_previo = manicurador
    ActiveRecord::Base.transaction do
      # Limpiar jornadas sin confirmar (borrador/enviado): una manicura sin lote no tiene sentido.
      pesajes_manicura.where(estado: %w[borrador enviado]).destroy_all
      # Y el peso_seco denormalizado que quedó del intento abortado (las pesadas se van con los
      # pesajes, pero el peso en la planta persiste) → el re-manicurado arranca limpio. No se
      # toca peso_humedo (es el peso bruto al corte, dato de la cosecha).
      plants.where.not(peso_seco: nil).update_all(peso_seco: nil)
      update!(estado: 'cosecha', manicurador: nil)
      lote_eventos.create!(
        tipo:            'cambio_estado',
        estado_anterior: 'en_manicura',
        estado_nuevo:    'cosecha',
        descripcion:     "Devuelto a cosecha por #{quien}: #{motivo}",
        user:            devuelto_por,
        club:            club,
        registrado_en:   Time.current,
      )
      AlertaInterna.create!(
        club:             club,
        tipo:             'manicura_devuelta',
        mensaje:          "Lote #{codigo} devuelto a cosecha por #{quien} — #{motivo}",
        severidad:        'warning',
        creada_por:       devuelto_por,
        destinada_a_role: 'admin',
        lote:             self,
        contexto:         { lote_id: id, lote_codigo: codigo, motivo: motivo, manicurador_previo_id: manicurador_previo&.id }
      )
    end
  end

  # Llamado tras cada confirmación de PesajeManicura.
  # Cuando todas las plantas están procesadas, el lote pasa a 'curado' (el stock de
  # flor_seca ya lo creó PesajeManicura#confirmar — acá empieza el curado). El lote
  # llega a 'finalizado' recién cuando se agota su stock (ver finalizar_si_stock_agotado!).
  def check_and_finalize_manicura!(finalizador: nil)
    return unless estado == 'en_manicura'

    # Las descartadas no se procesan nunca (no van a tener pesada); si contaran en el total,
    # total_procesadas >= total_plantas jamás se cumpliría y el lote quedaría pegado en_manicura.
    total_plantas = plants.where.not(state: 'descartada').count
    if total_plantas == 0
      # Se descartaron TODAS las plantas: el lote no produjo nada (no hay stock que curar).
      # Se finaliza directo (no pasa por curado).
      update!(estado: 'finalizado', rendimiento_real_g: 0, manicurador: nil, sala_id: nil)
      lote_eventos.create!(
        tipo:            'cambio_estado',
        estado_anterior: 'en_manicura',
        estado_nuevo:    'finalizado',
        descripcion:     'Todas las plantas fueron descartadas — lote finalizado sin producción.',
        user:            finalizador,
        club:            club,
        registrado_en:   Time.current,
      )
      return
    end

    plantas_confirmadas = PesadaPlanta
      .joins(:pesaje_manicura)
      .where(pesajes_manicura: { lote_id: id, estado: 'confirmado' })
      .select(:plant_id)
      .distinct
      .count

    # Total procesado = suma de plantas_count de todos los pesajes confirmados. Como los
    # pesajes por QR también llevan plantas_count (= sus pesadas individuales), se resta
    # plantas_confirmadas para no contarlas dos veces; los batch (carga manual de las
    # plantas restantes) quedan sumados. Resultado neto: sum(plantas_count).
    batch_count = pesajes_manicura
      .where(estado: 'confirmado')
      .where.not(plantas_count: nil)
      .sum(:plantas_count) - plantas_confirmadas

    total_procesadas = plantas_confirmadas + [batch_count, 0].max
    return unless total_procesadas >= total_plantas

    peso_total = pesajes_manicura.where(estado: 'confirmado').sum(:peso_confirmado_g).to_d

    update!(
      estado:             'curado',
      rendimiento_real_g: peso_total,
      manicurador:        nil,
      sala_id:            nil,
    )

    lote_eventos.create!(
      tipo:            'cambio_estado',
      estado_anterior: 'en_manicura',
      estado_nuevo:    'curado',
      descripcion:     "Manicura completada — #{total_plantas} plantas · #{peso_total.round(1)}g acumulados en #{pesajes_manicura.confirmados.count} pesajes. En curado.",
      user:            finalizador,
      club:            club,
      registrado_en:   Time.current,
    )
  end

  # El lote pasa a 'finalizado' cuando se agota todo su stock (lo llama Stock al quedar
  # en 0). Solo aplica desde 'curado' (ya tuvo stock); requiere que exista al menos un
  # stock y que todos estén agotados.
  def finalizar_si_stock_agotado!(usuario: nil)
    return unless estado == 'curado'
    activos = stocks.where.not(estado: 'agotado')
    return if activos.exists? || stocks.empty?

    update!(estado: 'finalizado')
    lote_eventos.create!(
      tipo: 'cambio_estado', estado_anterior: 'curado', estado_nuevo: 'finalizado',
      descripcion: 'Stock agotado — lote finalizado.', user: usuario, club: club,
      registrado_en: Time.current,
    )
  end

  private

  def maceta_al_prender
    return if tamanio_maceta.present?
    errors.add(:tamanio_maceta, 'es obligatorio al pasar a vegetativo: el esqueje que prendió va a maceta')
  end

  def generar_codigo_qr
    self.codigo_qr = "L-#{club_id}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end

  def generar_codigo
    return if codigo.present?
    base  = "L"
    anio  = Date.today.strftime("%y")
    count = club.lotes.count + 1
    self.codigo = "#{base}-#{anio}-#{count.to_s.rjust(3, '0')}"
    while club.lotes.exists?(codigo: self.codigo)
      count += 1
      self.codigo = "#{base}-#{anio}-#{count.to_s.rjust(3, '0')}"
    end
  end

  def dispatch_webhook_avance
    return unless saved_change_to_estado?

    estado_anterior, estado_nuevo = saved_change_to_estado

    event = estado_nuevo == 'finalizado' ? 'cosecha.completada' : 'lote.avanzado'

    WebhookDispatcher.dispatch(club, event, {
      id:              id,
      codigo:          codigo,
      estado_anterior: estado_anterior,
      estado_nuevo:    estado_nuevo,
      genetica:        genetica&.nombre,
      sala:            sala&.nombre,
      plants_count:    plants_count,
    })
  end
end
