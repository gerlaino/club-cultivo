# Un paquete de créditos de IA vendido por fuera del plan.
#
# El plan fija el tope mensual base; esto es lo que se le suma a UN mes concreto. Al cambiar el
# mes, los créditos no usados se pierden — que es la única forma de que "créditos extra" sea
# algo que se pueda cobrar todos los meses y no un saldo que crece solo.
class IaRecarga < ApplicationRecord
  self.table_name = 'ia_recargas' # el inflector EN no pluraliza "recarga"

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :user, optional: true

  validates :creditos, numericality: { only_integer: true, greater_than: 0 }
  validates :mes, presence: true

  before_validation :normalizar_mes

  scope :del_mes, ->(fecha = Time.zone.today) { where(mes: fecha.beginning_of_month) }
  scope :recientes, -> { order(created_at: :desc) }

  # Cuántos créditos extra tiene esta organización ESTE mes. Se usa para el tope, así que no
  # puede levantar: sin recargas, cero.
  def self.total_del_mes(club, fecha = Time.zone.today)
    where(club_id: club.id).del_mes(fecha).sum(:creditos)
  end

  private

  # Siempre el día 1. Guardar la fecha de compra haría que `del_mes` no encontrara nada: se
  # busca por mes, no por día.
  def normalizar_mes
    self.mes = (mes || Time.zone.today).to_date.beginning_of_month
  end
end
