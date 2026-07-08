# Una tarea del cronograma de un evento (la "cuenta regresiva"). Sin efectos contables.
class EventoBarTarea < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :evento_bar

  validates :titulo, presence: true

  scope :ordenadas, -> { order(:hecha, :orden, :vence_el) }
end
