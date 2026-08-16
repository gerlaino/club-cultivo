# Un gasto que se repite, definido como MOLDE: la luz, el alquiler, el contador.
#
# Se da de alta una vez en su pantalla y después se elige al cargar un movimiento, que llega con
# todo puesto. `monto_ars` es una REFERENCIA: la luz es fija todos los meses salvo en el monto,
# que es justamente lo que cambia — se trae puesto y se corrige antes de guardar.
#
# NO genera nada solo, a propósito y por la misma razón que la detección de recurrentes nunca
# autogeneró: con inflación, un asiento automático es un dato falso.
class GastoRecurrente < ApplicationRecord
  # Rails infiere 'gasto_recurrentes' (pluraliza sólo la última palabra): la tabla es
  # `gastos_recurrentes`. Mismo caso que CategoriaContable y UnidadNegocio.
  self.table_name = 'gastos_recurrentes'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :categoria_contable, optional: true
  belongs_to :sede,              optional: true
  belongs_to :unidad_negocio,    optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :nombre, presence: true,
                     uniqueness: { scope: :club_id, conditions: -> { where(deleted_at: nil) },
                                   message: 'ya existe en esta organización' }
  validates :monto_ars, numericality: { greater_than: 0 }, allow_nil: true
  validates :cantidad,  numericality: { greater_than: 0 }, allow_nil: true

  scope :activos,   -> { where(activo: true) }
  scope :ordenados, -> { order(:orden, :nombre) }

  # El sector sale de la categoría, igual que en el alta de un movimiento: elegida la categoría
  # no hay una segunda decisión que tomar, y así no pueden contradecirse.
  before_validation :heredar_sector_de_la_categoria

  private

  def heredar_sector_de_la_categoria
    self.unidad_negocio ||= categoria_contable&.unidad_efectiva
  end
end
