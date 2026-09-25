# El análisis de laboratorio del SUELO de una cama. Va aparte del de la flor
# (`AnalisisLaboratorio`, que es de un lote y mide cannabinoides): acá se mide la tierra, y la
# pregunta es cómo evoluciona la cama ciclo a ciclo. Columnas y no un json, para poder graficar.
# Metales pesados incluidos: el cannabis los acumula y algunas enmiendas los traen.
class AnalisisSuelo < ApplicationRecord
  self.table_name = 'analisis_suelo'
  include Transmite
  transmite_como 'camas'
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :cama
  belongs_to :user
  has_one_attached :archivo

  VALORES = %w[ph ce materia_organica_pct nitrogeno_pct fosforo_ppm potasio_ppm calcio_ppm magnesio_ppm
               cic relacion_cn plomo_ppm cadmio_ppm arsenico_ppm mercurio_ppm].freeze

  validates :fecha, presence: true
  validates :ph, numericality: { greater_than: 0, less_than: 14 }, allow_nil: true
  validates(*(VALORES - %w[ph]).map(&:to_sym), numericality: { greater_than_or_equal_to: 0 }, allow_nil: true)
  validate  :al_menos_un_valor
  validate  :no_futuro

  private

  def al_menos_un_valor
    return if VALORES.any? { |v| self[v].present? } || archivo.attached?
    errors.add(:base, 'Cargá al menos un valor o el PDF del análisis')
  end

  def no_futuro
    errors.add(:fecha, 'no puede ser futura') if fecha && fecha > Time.zone.today
  end
end
