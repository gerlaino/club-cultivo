class PesadaPlanta < ApplicationRecord
  include Restorable
  self.table_name = 'pesadas_plantas'

  belongs_to :pesada,          optional: true
  belongs_to :pesaje_manicura, optional: true
  belongs_to :plant

  validates :peso_humedo_g, numericality: { greater_than: 0, allow_nil: true }
  validates :peso_seco_g,   numericality: { greater_than: 0, allow_nil: true }

  # A plant can only appear once per pesada (legacy flow)
  validates :plant_id, uniqueness: { scope: :pesada_id },          if: :pesada_id?
  # A plant can only appear once per pesaje_manicura (new flow)
  validates :plant_id, uniqueness: { scope: :pesaje_manicura_id }, if: :pesaje_manicura_id?

  validate :solo_un_parent

  private

  def solo_un_parent
    if pesada_id.present? && pesaje_manicura_id.present?
      errors.add(:base, 'Un registro de peso no puede pertenecer a una pesada Y a un pesaje a la vez')
    end
    if pesada_id.blank? && pesaje_manicura_id.blank?
      errors.add(:base, 'Debe pertenecer a una pesada o a un pesaje de manicura')
    end
  end
end
