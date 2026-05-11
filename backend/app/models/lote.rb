class Lote < ApplicationRecord
  belongs_to :club
  belongs_to :sala
  belongs_to :genetica, optional: true
  has_many :plants,                dependent: :destroy
  has_one  :costo_lote,            dependent: :destroy
  has_many :movimientos_contables, dependent: :nullify
  has_many :registros_ambientales, class_name: 'RegistroAmbiental', dependent: :destroy
  has_many :lote_eventos,          dependent: :destroy
  has_many :pesadas,               -> { order(registrado_at: :asc) }, dependent: :destroy
  has_many :stocks,                dependent: :nullify
  has_many_attached :fotos
  has_many :notas, as: :noteable, dependent: :destroy

  # manicura_pendiente se inserta entre secado y curado.
  # No forma parte de CICLO_FASES (transición controlada por pesada de manicura).
  ESTADOS       = %w[semilla vegetativo floracion cosecha secado manicura_pendiente curado finalizado].freeze
  CICLO_FASES   = %w[vegetativo floracion cosecha secado curado].freeze
  TIPOS_CULTIVO = %w[sustrato hidroponia aeroponia].freeze
  TIPOS_LUZ     = %w[led hps cmh natural mixta].freeze
  SUSTRATOS     = %w[tierra coco perlita mezcla rockwool fibra_coco].freeze
  FOTOPERIODOS  = %w[20/4 18/6 16/8 12/12 auto].freeze

  validates :codigo,            uniqueness: { scope: :club_id, conditions: -> { where(deleted_at: nil) } }, allow_blank: true
  validates :estado,            inclusion: { in: ESTADOS }, allow_blank: false
  validates :plants_count,      numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :grow_type,         inclusion: { in: TIPOS_CULTIVO }, allow_blank: true
  validates :light_type,        inclusion: { in: TIPOS_LUZ },     allow_blank: true
  validates :tamanio_maceta,    numericality: { greater_than: 0 }, allow_nil: true
  validates :semanas_floracion, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :start_date,        presence: true

  before_create :generar_codigo

  default_scope { where(deleted_at: nil) }

  scope :activos,     -> { where.not(estado: 'finalizado') }
  scope :en_ciclo,    -> { where(estado: CICLO_FASES + ['finalizado']) }
  scope :finalizados, -> { where(estado: 'finalizado') }
  scope :por_sala,    ->(sala_id) { where(sala_id: sala_id) }
  scope :recientes,   -> { order(created_at: :desc) }

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  def dias_desde_inicio
    return 0 unless start_date
    (Date.today - start_date).to_i
  end

  def progreso_ciclo
    case estado
    when 'semilla'             then 0
    when 'vegetativo'          then 20
    when 'floracion'           then 40
    when 'cosecha'             then 60
    when 'secado'              then 72
    when 'manicura_pendiente'  then 82
    when 'curado'              then 90
    when 'finalizado'          then 100
    else 0
    end
  end

  FASE_A_PLANT_STATE = {
    'vegetativo' => 'vegetativo',
    'floracion'  => 'floracion',
    'cosecha'    => 'cosechado',
    'secado'     => 'secado',
  }.freeze

  # Avance rápido sin pesada — usado por el cultivador desde el botón "Avanzar fase".
  # Si sala_id se provee, mueve el lote a esa sala. Si no, intenta auto-detectar:
  # si existe exactamente una sala activa del tipo destino en el club, la elige.
  def avanzar_fase!(sala_id: nil)
    idx = CICLO_FASES.index(estado)
    raise ArgumentError, 'Lote no puede transicionar en este estado' unless idx.present? && idx < CICLO_FASES.length - 1
    nueva_fase = CICLO_FASES[idx + 1]
    ActiveRecord::Base.transaction do
      sala_nueva = if sala_id.present?
        club.salas.activas.find_by(id: sala_id)
      else
        candidatas = club.salas.activas.de_tipo(nueva_fase).to_a
        candidatas.length == 1 ? candidatas.first : nil
      end

      attrs = { estado: nueva_fase }
      attrs[:sala] = sala_nueva if sala_nueva
      update!(attrs)

      plant_state = FASE_A_PLANT_STATE[nueva_fase]
      plants.where.not(state: %w[descartada cosechado]).update_all(state: plant_state) if plant_state
    end
  end

  # Avanza el lote al siguiente paso del ciclo (vegetativo→floracion→secado→curado).
  # Crea la pesada y mueve el lote a la sala destino (creándola si hace falta).
  # pesada_attrs debe incluir: registrado_por (User), y el peso según fase_destino.
  def transicionar!(nueva_fase, pesada_attrs:, manicurado: false, pesadas_plantas_attrs: [])
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
      sala_destino = Sala.find_or_create_proceso!(
        sede:        sala.sede,
        tipo:        nueva_fase,
        created_by:  registrado_por
      )

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

      update!(estado: nueva_fase, sala: sala_destino)
      plant_state = FASE_A_PLANT_STATE[nueva_fase]
      plants.where.not(state: %w[descartada cosechado]).update_all(state: plant_state) if plant_state
    end
  end

  # Aprueba la pesada de manicura, transiciona de manicura_pendiente a curado.
  def aprobar_manicura!(aprobado_por:, observaciones: nil)
    raise "El lote no está en manicura_pendiente" unless estado == 'manicura_pendiente'

    ultima_pesada = pesadas.where(fase_origen: 'secado', manicurado: true).reorder(id: :desc).first
    raise "No hay pesada de manicura para aprobar" unless ultima_pesada

    ActiveRecord::Base.transaction do
      ultima_pesada.update!(aprobada_at: Time.current, aprobada_por_id: aprobado_por.id,
                            rechazada_at: nil, rechazada_por_id: nil, motivo_rechazo: nil)

      sala_curado = Sala.find_or_create_proceso!(sede: sala.sede, tipo: 'curado', created_by: aprobado_por)
      update!(estado: 'curado', sala: sala_curado)

      AlertaInterna.create!(
        club:             club,
        tipo:             'manicura_aprobada',
        mensaje:          "Manicura aprobada para lote #{codigo}",
        severidad:        'info',
        creada_por:       aprobado_por,
        destinada_a_role: 'manicura',
        contexto:         { lote_id: id, lote_codigo: codigo, aprobado_por_id: aprobado_por.id }
      )
    end
  end

  # Rechaza la pesada de manicura, devuelve el lote a secado.
  def rechazar_manicura!(rechazado_por:, motivo:)
    raise "El lote no está en manicura_pendiente" unless estado == 'manicura_pendiente'
    raise ArgumentError, "El motivo es obligatorio" if motivo.blank?

    ultima_pesada = pesadas.where(fase_origen: 'secado', manicurado: true).reorder(id: :desc).first

    ActiveRecord::Base.transaction do
      ultima_pesada&.update!(rechazada_at: Time.current, rechazada_por_id: rechazado_por.id,
                             motivo_rechazo: motivo, aprobada_at: nil, aprobada_por_id: nil)

      sala_secado = Sala.find_or_create_proceso!(sede: sala.sede, tipo: 'secado', created_by: rechazado_por)
      update!(estado: 'secado', sala: sala_secado)

      AlertaInterna.create!(
        club:             club,
        tipo:             'manicura_rechazada',
        mensaje:          "Manicura rechazada para lote #{codigo}: #{motivo}",
        severidad:        'warning',
        creada_por:       rechazado_por,
        destinada_a_role: 'manicura',
        contexto:         { lote_id: id, lote_codigo: codigo, motivo: motivo }
      )
    end
  end

  # Cierra el curado, genera Stock de flor_seca, marca el lote como finalizado.
  # splitter: { flor_seca: Decimal, descarte: Decimal } — debe sumar == peso_curado_g última pesada
  def cerrar_curado!(splitter:, sede_destino_id:, costo_unitario_ars:, precio_sugerido_ars:, registrado_por:, peso_curado_g: nil)
    raise "El lote no está en curado" unless estado == 'curado'

    ultima = pesadas.where(fase_destino: 'curado').reorder(id: :desc).first

    if peso_curado_g.present?
      if ultima
        ultima.update!(peso_curado_g: peso_curado_g) if ultima.peso_curado_g.blank?
      else
        ultima = pesadas.create!(
          fase_origen:    'secado',
          fase_destino:   'curado',
          peso_curado_g:  peso_curado_g,
          registrado_por: registrado_por,
          registrado_at:  Time.current,
          manicurado:     false,
        )
      end
    end

    raise "No hay pesada de curado registrada" unless ultima
    raise "La pesada de curado no tiene peso_curado_g" unless ultima.peso_curado_g.present?

    flor_seca = splitter[:flor_seca].to_d
    descarte  = splitter[:descarte].to_d
    total     = flor_seca + descarte

    unless total.round(2) == ultima.peso_curado_g.to_d.round(2)
      raise "El splitter (#{total}g) no coincide con el peso curado (#{ultima.peso_curado_g}g)"
    end

    sede = Sede.find(sede_destino_id)

    ActiveRecord::Base.transaction do
      # Pesada de cierre
      pesadas.create!(
        fase_origen:    'curado',
        fase_destino:   'finalizado',
        peso_curado_g:  ultima.peso_curado_g,
        manicurado:     false,
        registrado_por: registrado_por,
        registrado_at:  Time.current,
        notas:          "Splitter: #{flor_seca}g flor + #{descarte}g descarte",
      )

      stock = Stock.create!(
        sede:                sede,
        lote:                self,
        pesada:              ultima,
        origen:              'lote',
        forma_producto:      'flor_seca',
        unidad:              'g',
        cantidad:            flor_seca,
        fecha_elaboracion:   Date.today,
        costo_unitario_ars:  costo_unitario_ars,
        precio_sugerido_ars: precio_sugerido_ars,
      )

      update!(estado: 'finalizado')
      stock
    end
  end

  private

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
end
