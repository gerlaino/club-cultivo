class IndicacionMedica < ApplicationRecord
  belongs_to :socio
  belongs_to :user # médico que emite

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
           .where('fecha_vencimiento >= ?', Date.today)
  }
  scope :vencidas, -> {
    where('fecha_vencimiento IS NOT NULL')
      .where('fecha_vencimiento < ?', Date.today)
  }

  before_validation :set_fecha_emision, on: :create
  before_validation :calculate_fecha_vencimiento, if: :duracion_dias?

  def dias_hasta_vencimiento
    return nil unless fecha_vencimiento
    (fecha_vencimiento - Date.today).to_i
  end

  def vencida?
    fecha_vencimiento && fecha_vencimiento < Date.today
  end

  def por_vencer?
    return false unless fecha_vencimiento
    dias = dias_hasta_vencimiento
    dias && dias > 0 && dias <= 30
  end

  private

  def set_fecha_emision
    self.fecha_emision ||= Date.today
  end

  def calculate_fecha_vencimiento
    self.fecha_vencimiento = fecha_emision + duracion_dias.days if fecha_emision
  end
end
