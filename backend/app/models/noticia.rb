class Noticia < ApplicationRecord
  self.table_name = 'noticias'

  belongs_to :club

  # Active Storage para cover image
  has_one_attached :cover_image

  # Validaciones
  validates :titulo, presence: true
  validates :contenido, presence: true

  # Scopes
  scope :publicadas, -> { where(publicada: true).where.not(publicada_at: nil) }
  scope :recientes, -> { order(publicada_at: :desc) }
  scope :para_web, -> { publicadas.recientes }

  # Callbacks
  before_save :set_publicada_at, if: :publicada_changed?

  private

  def set_publicada_at
    self.publicada_at = publicada ? Time.current : nil
  end
end