# Reseña de un paciente sobre el producto (genética) que recibió en una dispensa.
# Feedback interno para el club (no público). La deja el paciente desde el pasaporte
# público /d/:token (autenticado por token de dispensa + DNI). Una por (dispensacion,
# genetica), editable.
class ResenaProducto < ApplicationRecord
  self.table_name = 'resenas_producto' # evita la inflexión 'resena_productos'

  acts_as_tenant(:club)
  belongs_to :club
  belongs_to :paciente
  belongs_to :genetica
  belongs_to :dispensacion

  PUNTAJES = { estrellas: true, puntaje_sabor: false, puntaje_aroma: false, puntaje_efecto: false }.freeze

  validates :estrellas, presence: true,
            numericality: { only_integer: true, in: 1..5 }
  validates :puntaje_sabor, :puntaje_aroma, :puntaje_efecto,
            numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :comentario, length: { maximum: 1000 }
  validates :dispensacion_id, uniqueness: { scope: :genetica_id }

  scope :recientes, -> { order(created_at: :desc) }

  # Resumen agregado para el panel del club (promedios por eje + conteo).
  def self.resumen
    {
      total:          count,
      avg_estrellas:  promedio(:estrellas),
      avg_sabor:      promedio(:puntaje_sabor),
      avg_aroma:      promedio(:puntaje_aroma),
      avg_efecto:     promedio(:puntaje_efecto),
    }
  end

  def self.promedio(col)
    avg = where.not(col => nil).average(col)
    avg && avg.to_f.round(1)
  end
end
