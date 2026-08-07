class IndicacionMedica < ApplicationRecord
  include Restorable
  belongs_to :paciente
  belongs_to :user # médico que emite

  # Cifrado at-rest de la prescripción (datos de salud — Ley 25.326 art. 9 / Res. 47/2018).
  encrypts :patologia
  encrypts :dosificacion
  encrypts :via_administracion
  encrypts :observaciones

  VIAS_ADMINISTRACION = %w[
    oral
    sublingual
    inhalada
    topica
    vaporizacion
  ].freeze

  validates :patologia, presence: true
  validates :dosificacion, presence: true
  validates :via_administracion, presence: true, inclusion: { in: VIAS_ADMINISTRACION }
  validates :fecha_emision, presence: true

  scope :activas, -> { where(activa: true) }
  scope :por_vencer, -> {
    activas.where('fecha_vencimiento IS NOT NULL')
           .where('fecha_vencimiento <= ?', 30.days.from_now)
           .where('fecha_vencimiento >= ?', Time.zone.today)
  }
  scope :vencidas, -> {
    where('fecha_vencimiento IS NOT NULL')
      .where('fecha_vencimiento < ?', Time.zone.today)
  }

  before_validation :set_fecha_emision, on: :create
  before_validation :derivar_fecha_vencimiento

  # ¿El vencimiento sale del cálculo o lo escribió el médico? Se deriva comparando en vez de
  # guardarlo en una columna: el dato ya está, y así no hay un flag que pueda quedar mintiendo.
  def vencimiento_calculado?
    return false if fecha_vencimiento.blank? || duracion_dias.blank? || fecha_emision.blank?

    fecha_vencimiento == fecha_emision + duracion_dias.days
  end

  def dias_hasta_vencimiento
    return nil unless fecha_vencimiento
    (fecha_vencimiento - Time.zone.today).to_i
  end

  def vencida?
    fecha_vencimiento && fecha_vencimiento < Time.zone.today
  end

  def por_vencer?
    return false unless fecha_vencimiento
    dias = dias_hasta_vencimiento
    dias && dias > 0 && dias <= 30
  end

  private

  def set_fecha_emision
    self.fecha_emision ||= Time.zone.today
  end

  # La duración del tratamiento y la validez de la indicación son cosas distintas: un tratamiento
  # de 90 días puede vivir dentro de una indicación que vale hasta que venza el REPROCANN. En la
  # práctica coinciden casi siempre, así que la duración **propone** el vencimiento — pero si el
  # médico escribe una fecha a mano, gana la fecha. Antes el cálculo pisaba siempre y en silencio.
  def derivar_fecha_vencimiento
    return if duracion_dias.blank? || fecha_emision.blank?
    return if fecha_vencimiento_changed?                          # lo escrito a mano manda
    return if fecha_vencimiento.present? && !duracion_dias_changed? # ya hay fecha y nadie tocó la duración

    self.fecha_vencimiento = fecha_emision + duracion_dias.days
  end
end
