# Una venta del bar (ticket). Cabecera + líneas (BarVentaItem), con el mismo patrón que
# Dispensacion. El ingreso contable asociado vive en movimiento_contable. La creación con
# descuento de stock y asiento contable la maneja Bar::RegistrarVenta.
class BarVenta < ApplicationRecord
  # El inflector inglés no pluraliza "venta" (BarVenta.tableize → 'bar_venta'), pero la tabla es
  # 'bar_ventas'. Sin esto, TODA query de ventas del bar tira `relation "bar_venta" does not exist`.
  self.table_name = 'bar_ventas'

  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar, class_name: 'Barra'
  belongs_to :user # vendedor
  belongs_to :unidad_negocio,      optional: true
  belongs_to :movimiento_contable, optional: true
  belongs_to :evento_bar,          optional: true # venta atribuida a un evento (opcional)
  belongs_to :caja_turno,          optional: true # caja de turno abierta al momento de la venta
  has_many :items, class_name: 'BarVentaItem', dependent: :destroy

  MEDIOS_PAGO = %w[efectivo transferencia mercado_pago].freeze

  validates :total_ars, numericality: { greater_than_or_equal_to: 0 }
  validates :medio_pago, inclusion: { in: MEDIOS_PAGO }

  # Al borrar (soft) una venta: devuelve el stock a los productos y saca el ingreso del libro.
  # prepend para correr antes del dependent: :destroy de las líneas (que todavía están vivas).
  before_destroy :revertir_efectos, prepend: true

  scope :del_dia, ->(fecha = Time.zone.today) { where(created_at: fecha.all_day) }
  scope :recientes, -> { order(created_at: :desc) }

  # Crea (o re-crea, al restaurar) el asiento de ingreso del bar en el libro, etiquetado con la
  # sede del bar y la unidad "Bar". Fuente única usada por Bar::RegistrarVenta y por el restorer.
  def crear_ingreso!
    unidad = bar&.unidad_negocio_bar
    mov = club.movimientos_contables.create!(
      created_by: user, tipo: 'ingreso',
      categoria: 'otro', categoria_contable: categoria_venta_bar(unidad),
      unidad_negocio: unidad, sede_id: bar&.sede_id, evento_bar_id: evento_bar_id,
      descripcion: "Venta bar ##{id}",
      monto_ars: total_ars, fecha: Date.current,
      pagado: true, medio_pago: medio_pago, comprobante_tipo: 'sin_comprobante'
    )
    update!(movimiento_contable: mov)
    mov
  end

  private

  def categoria_venta_bar(unidad)
    club.categorias_contables.create_with(tipo: 'ingreso', unidad_negocio: unidad, es_sistema: true)
        .find_or_create_by!(nombre: 'Venta bar')
  end

  def revertir_efectos
    items.each { |it| it.bar_producto&.increment!(:stock, it.cantidad) }
    movimiento_contable&.destroy
  end
end
