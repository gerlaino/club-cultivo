# Lo que se le hace AL SUELO de una cama, haya o no lotes adentro: armarla, alimentarla (top
# dress), un té al suelo, sembrar cobertura, poner mulch, inocular, regarla mientras descansa,
# medirla, anotar algo.
#
# Lo que va a la PLANTA o al aire (riego con lotes, foliar, poda, plagas, ambiente) sigue siendo del
# lote (`RegistroAmbiental`, `PlantActivity`): acá va sólo lo que vive en la tierra. Un riego con
# lotes adentro es del lote —así el lote sabe cuándo lo regaron—; el riego de una cama que
# descansa (la cobertura también toma agua) no tiene lote a quien cargárselo y viene acá.
#
# Si usa insumos, `Nutricion::Aplicar` descuenta, cuesta y deja la COPIA en `nutricion` (editar la
# receta después no cambia la historia). Nunca bloquea por stock. El costo va a los lotes en
# cultivo de la cama en ese momento; sin lotes, queda en la cama (inversión: Germán, 25-sep).
class CamaRegistro < ApplicationRecord
  self.table_name = 'cama_registros'
  include Transmite
  transmite_como 'camas'
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :cama
  belongs_to :cama_ciclo, optional: true
  belongs_to :user
  belongs_to :receta, optional: true
  has_many   :insumo_consumos, dependent: :nullify
  # Lo descontado vuelve al depósito si se borra el registro. `prepend`: antes del nullify.
  before_destroy :revertir_insumos, prepend: true

  TIPOS = %w[armado top_dress te cobertura mulch inoculacion riego medicion nota].freeze
  TIPO_LABELS = {
    'armado' => 'Armado', 'top_dress' => 'Top dress', 'te' => 'Té al suelo', 'cobertura' => 'Cobertura',
    'mulch' => 'Mulch', 'inoculacion' => 'Inoculación', 'riego' => 'Riego', 'medicion' => 'Medición',
    'nota' => 'Nota',
  }.freeze
  # Los que pueden descontar insumos del depósito.
  CON_INSUMOS = %w[armado top_dress te cobertura mulch inoculacion riego].freeze
  AGUAS = %w[red declorada lluvia osmosis pozo].freeze

  validates :tipo, inclusion: { in: TIPOS }
  validates :registrado_en, presence: true
  validates :agua, inclusion: { in: AGUAS }, allow_blank: true
  validates :litros, :cantidad, numericality: { greater_than: 0 }, allow_nil: true
  validates :humedad_suelo, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :temperatura_suelo, numericality: { greater_than: -20, less_than: 60 }, allow_nil: true
  validate  :no_futuro
  validate  :riego_sin_lotes, on: :create
  validate  :recarga_es_top_dress

  before_validation :asignar_ciclo, on: :create

  scope :del_ciclo, ->(ciclo_id) { where(cama_ciclo_id: ciclo_id) }

  def costo_ars = nutricion.to_h['costo_ars'].to_f

  private

  # El ciclo es el que estaba abierto ESE día: un top dress cargado hoy con fecha de la semana
  # pasada, cuando la cama descansaba, no es del ciclo que abrió ayer.
  def asignar_ciclo
    return if cama.nil? || registrado_en.nil? || cama_ciclo_id.present?
    dia = registrado_en.to_date
    self.cama_ciclo = cama.ciclos.where('desde <= ?', dia).where('hasta IS NULL OR hasta >= ?', dia).order(:numero).last
  end

  def no_futuro
    errors.add(:registrado_en, 'no puede ser futura') if registrado_en && registrado_en.to_date > Time.zone.today
  end

  def riego_sin_lotes
    return unless tipo == 'riego' && cama&.lotes_en_cultivo&.exists?
    errors.add(:base, 'La cama tiene plantas: el riego se registra en el lote (así queda en su historia)')
  end

  def recarga_es_top_dress
    errors.add(:recarga, 'sólo aplica a un top dress') if recarga && tipo != 'top_dress'
  end

  def revertir_insumos
    Nutricion::Aplicar.revertir!(self)
  end
end
