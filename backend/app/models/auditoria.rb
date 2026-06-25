# Rastro inmutable de cambios sobre registros sensibles (hoy: MovimientoContable).
# Solo se crea — nunca se actualiza ni se borra desde la app.
class Auditoria < ApplicationRecord
  self.table_name = 'auditorias'  # el inflector EN no pluraliza "auditoria"

  # optional: al auditar un "eliminar", el registro ya no existe en la DB;
  # auditable_type/id quedan guardados igual como referencia histórica.
  belongs_to :auditable, polymorphic: true, optional: true
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :user, optional: true

  ACCIONES = %w[crear actualizar eliminar].freeze

  validates :accion, inclusion: { in: ACCIONES }

  scope :recientes, -> { order(created_at: :desc) }
  scope :de,        ->(registro) { where(auditable: registro) }
end
