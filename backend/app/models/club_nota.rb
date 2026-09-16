# Una anotación del dueño de la plataforma sobre una organización: «habló con Juan el 3/9,
# quiere Delivery en octubre». Se crea y se borra, nunca se edita: es un rastro, y una nota
# corregida sin fecha es una nota que dice otra cosa de la que se dijo ese día.
#
# Sin `acts_as_tenant` a propósito: es dato de la PLATAFORMA sobre la organización, lo escribe
# el super admin (que no tiene tenant) y la organización nunca lo ve.
class ClubNota < ApplicationRecord
  self.table_name = 'club_notas' # el inflector EN no pluraliza "nota"

  belongs_to :club
  belongs_to :user, optional: true

  validates :texto, presence: true, length: { maximum: 2_000 }

  scope :recientes, -> { order(created_at: :desc) }
end
