# Un bar del club, ligado a una sede social o mixta. Es una entidad independiente: sus
# productos, ventas, caja y resultado son propios de esa sede. Un club puede tener varios
# (uno por sede social/mixta). Recuperable desde la papelera.
class Bar < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede
  has_many :bar_productos, dependent: :destroy
  has_many :bar_ventas,    dependent: :destroy

  validates :nombre, presence: true
  validate  :sede_habilitada
  validate  :una_por_sede, on: :create

  scope :activos, -> { where(activo: true) }

  # Resultado del bar en un período = ingresos − egresos del libro etiquetados con esta sede
  # y la unidad de negocio "Bar". Es la fuente de verdad contable (no se calcula de las ventas).
  def resultado_periodo(desde, hasta)
    movs = club.movimientos_contables
               .where(sede_id: sede_id, unidad_negocio_id: unidad_negocio_bar&.id)
               .del_periodo(desde, hasta)
    ingresos = movs.ingresos.sum(:monto_ars)
    egresos  = movs.egresos.sum(:monto_ars)
    { ingresos: ingresos.to_f, egresos: egresos.to_f, resultado: (ingresos - egresos).to_f }
  end

  # Unidad de negocio "Bar" del club (compartida por todos los bares; el aislamiento por bar
  # se logra con la sede). La crea si el catálogo no fue sembrado.
  def unidad_negocio_bar
    @unidad_negocio_bar ||= club.unidades_negocio.create_with(nombre: 'Bar', es_sistema: true)
                                .find_or_create_by!(tipo: 'bar')
  end

  private

  def sede_habilitada
    return if sede.nil?
    return if sede.es_social?

    errors.add(:sede, 'debe ser una sede social o mixta para tener bar')
  end

  def una_por_sede
    return if sede_id.nil?
    return unless club&.bares&.where(sede_id: sede_id)&.exists?

    errors.add(:sede, 'ya tiene un bar')
  end
end
