class Nota < ApplicationRecord
  acts_as_paranoid

  belongs_to :noteable, polymorphic: true
  belongs_to :club
  belongs_to :user

  validates :contenido, presence: true
  validates :fuente, inclusion: { in: %w[manual asistente_voz] }

  scope :recientes, -> { order(created_at: :desc) }
  scope :de_sala,   -> { where(noteable_type: 'Sala') }
  scope :de_lote,   -> { where(noteable_type: 'Lote') }
  scope :de_planta, -> { where(noteable_type: 'Plant') }

  def usuario
    user&.nombre_completo || user&.email || '—'
  end
end