class Lote < ApplicationRecord
  include RestorableInterface
  belongs_to :deleted_by, class_name: "User", optional: true
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :sala, optional: true
  belongs_to :sede, optional: true
  # La sala es solo de cultivo. Post-cosecha el lote no tiene sala (se ve por estado),
  # pero conserva su sede. Exigimos sala solo en estados de cultivo.
  CULTIVO_ESTADOS = %w[semilla esqueje vegetativo floracion].freeze
  validates :sala_id, presence: true, if: -> { CULTIVO_ESTADOS.include?(estado) }
  belongs_to :genetica,    optional: true
  belongs_to :manicurador,   class_name: 'User',  optional: true
  belongs_to :planta_madre,  class_name: 'Plant', optional: true
  has_many :plants,                dependent: :destroy
  has_one  :costo_lote,            dependent: :destroy
  has_many :movimientos_contables, dependent: :nullify
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

  # Secuencia: semilla/esqueje → vegetativo → floración → cosecha → en_manicura
  # (admin asigna manicura) → curado (se confirma el pesaje + se crea el stock; acá
  # empieza el curado) → finalizado (cuando se agota el stock del lote).
  # La aprobación del pesaje vive en PesajeManicura (estado enviado→confirmado), no en
  # un estado del lote: el lote sigue 'en_manicura' hasta que se confirma y pasa a 'curado'.
  # 'secado' YA NO es un estado: es una métrica (días de cosecha→stock). Ver dias_secado.
  ESTADOS       = %w[semilla esqueje vegetativo floracion cosecha en_manicura curado finalizado].freeze
  ORIGENES      = %w[semilla esqueje].freeze
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

  before_create :generar_codigo
  before_create :generar_codigo_qr
  after_commit  :dispatch_webhook_avance,  on: [:create, :update]

  default_scope { where(deleted_at: nil) }

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

  def progreso_ciclo
    case estado
    when 'semilla', 'esqueje'  then 0
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
    'vegetativo' => 'vegetativo',
    'floracion'  => 'floracion',
    'cosecha'    => 'cosechado',
  }.freeze

  # Avance rápido sin pesada — usado por el cultivador desde el botón "Avanzar fase".
  # Si sala_id se provee, mueve el lote a esa sala. Si no, intenta auto-detectar:
  # si existe exactamente una sala activa del tipo destino en el club, la elige.
  def avanzar_fase!(sala_id: nil, usuario: nil)
    nueva_fase = if %w[semilla esqueje].include?(estado)
      'vegetativo'
    else
      idx = CICLO_FASES.index(estado)
      raise ArgumentError, 'Lote no puede transicionar en este estado' unless idx.present? && idx < CICLO_FASES.length - 1
      CICLO_FASES[idx + 1]
    end
    ActiveRecord::Base.transaction do
      attrs = { estado: nueva_fase }
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

  # Llamado tras cada confirmación de PesajeManicura.
  # Cuando todas las plantas están procesadas, el lote pasa a 'curado' (el stock de
  # flor_seca ya lo creó PesajeManicura#confirmar — acá empieza el curado). El lote
  # llega a 'finalizado' recién cuando se agota su stock (ver finalizar_si_stock_agotado!).
  def check_and_finalize_manicura!(finalizador: nil)
    return unless estado == 'en_manicura'

    total_plantas = plants.count
    return if total_plantas == 0

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
