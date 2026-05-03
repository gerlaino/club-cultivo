class SetpointFase < ApplicationRecord
  self.table_name = 'setpoints_fase'

  belongs_to :genetica, optional: true

  FASES = %w[clon madre vegetativo floracion lavado secado curado].freeze

  validates :fase,          inclusion: { in: FASES }
  validates :club_id,       presence: true
  validates :tipo_lectura,  inclusion: { in: AmbienteTipos::TIPOS }, allow_blank: true

  before_validation :asignar_unidad_canonica

  scope :del_club, ->(club_id)    { where(club_id: club_id) }
  scope :para_fase, ->(fase)       { where(fase: fase) }
  scope :default,  ->              { where(genetica_id: nil) }
  scope :para_genetica, ->(gid)   { where(genetica_id: gid) }

  def self.para(club_id:, genetica_id:, fase:, tipo:)
    base = where(club_id: club_id, fase: fase, tipo_lectura: tipo)
    base.find_by(genetica_id: genetica_id) || base.find_by(genetica_id: nil)
  end

  private

  def asignar_unidad_canonica
    return if tipo_lectura.blank?
    self.unidad = AmbienteTipos::TIPOS_CANONICOS[tipo_lectura]
  end
end
