class Alerta < ApplicationRecord
  include Restorable
  self.table_name = 'alertas'

  belongs_to :regla,    class_name: 'ReglaAmbiental', foreign_key: :regla_id
  belongs_to :sala
  belongs_to :lectura,  class_name: 'LecturaAmbiental', foreign_key: :lectura_id, optional: true
  belongs_to :reconocida_por, class_name: 'User', foreign_key: :reconocida_por_id, optional: true
  belongs_to :resuelta_por,   class_name: 'User', foreign_key: :resuelta_por_id,   optional: true

  ESTADOS = %w[activa reconocida resuelta].freeze

  validates :estado,  inclusion: { in: ESTADOS }
  validates :mensaje, presence: true
  validates :club_id, presence: true

  scope :activas,     -> { where(estado: 'activa') }
  scope :reconocidas, -> { where(estado: 'reconocida') }
  scope :resueltas,   -> { where(estado: 'resuelta') }
  scope :no_resueltas,-> { where(estado: %w[activa reconocida]) }
  scope :del_club,    ->(club_id) { where(club_id: club_id) }
  scope :de_sala,     ->(sala_id) { where(sala_id: sala_id) }
  scope :recientes,   -> { order(created_at: :desc) }
  scope :desde,       ->(ts) { where('created_at >= ?', ts) }

  def reconocer!(user)
    update!(estado: 'reconocida', reconocida_at: Time.current, reconocida_por: user)
  end

  def resolver!(user)
    update!(estado: 'resuelta', resuelta_at: Time.current, resuelta_por: user)
  end

  def resolver_automatico!
    update!(estado: 'resuelta', resuelta_at: Time.current)
  end

  def activa?     = estado == 'activa'
  def reconocida? = estado == 'reconocida'
  def resuelta?   = estado == 'resuelta'
end
