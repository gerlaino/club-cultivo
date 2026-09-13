# Una compra financiada en cuotas mensuales (ej: un aire acondicionado en 6 cuotas con la
# tarjeta del club). Al crearse genera N MovimientoContable (egresos), uno por mes desde
# `fecha_primera_cuota`, para que cada cuota impacte el balance del mes que corresponde.
# Se puede backdatear la primera cuota para cuadrar meses anteriores.
class CompraCuotas < ApplicationRecord
  self.table_name = 'compras_cuotas'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede
  belongs_to :created_by, class_name: 'User'
  # La categoría del catálogo que eligió la persona. `optional` porque las compras cargadas antes
  # de esta columna no la tienen, y una compra vieja tiene que poder seguir editándose.
  belongs_to :categoria_contable, optional: true
  has_many   :movimientos_contables, class_name: 'MovimientoContable',
             foreign_key: :compra_cuotas_id, dependent: :destroy  # las cuotas generadas

  validates :descripcion,         presence: true
  # LA MISMA LISTA QUE LOS MOVIMIENTOS QUE ESTA COMPRA GENERA.
  #
  # Validaba contra `CATEGORIAS_EGRESO`, que era —según su propio comentario— la lista de las que
  # "TÍPICAMENTE son egresos": una heurística usada como lista blanca. Y las categorías que crea el
  # club no están ahí: una categoría propia sin `clave_sistema` no tiene clave legacy, así que el
  # formulario manda `otro`, que SÍ es una categoría válida de movimiento y NO estaba entre esas
  # nueve. Resultado: el mismo gasto entraba como pago único y rebotaba en cuotas, con un
  # «Categoría no está en la lista» sobre una categoría que estaba elegida en pantalla.
  #
  # Una compra en cuotas son N egresos y nada más: si la categoría sirve para un egreso, sirve acá.
  validates :categoria,           presence: true,
                                  inclusion: { in: MovimientoContable::CATEGORIAS,
                                               message: '«%{value}» no es una categoría del libro' }
  validates :monto_total_ars,     presence: true, numericality: { greater_than: 0 }
  validates :cuotas_total,        presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 120 }
  validates :fecha_primera_cuota, presence: true

  after_create :generar_cuotas!

  # Edita la compra y REGENERA las cuotas desde cero (borra los movimientos viejos y crea los
  # nuevos con el total/cantidad actualizados). Atómico. Devuelve true/false (errores en el
  # record). El guard de período cerrado se valida en el controller antes de llamar.
  #
  # LOS PAGOS YA REGISTRADOS SE CONSERVAN, cuota por cuota (por su número): corregir el proveedor
  # de una compra con tres cuotas pagas no puede volver a dejarlas pendientes. Si la cantidad de
  # cuotas baja y una pagada queda afuera, se pierde ese registro — es el mismo caso que borrar
  # la compra, y la pantalla lo avisa.
  def actualizar_y_regenerar!(attrs)
    transaction do
      pagos = movimientos_contables.where(pagado: true)
                                   .pluck(:cuota_numero, :medio_pago, :fecha_pago, :caja_turno_id)
                                   .to_h { |n, *resto| [n, resto] }
      update!(attrs)
      movimientos_contables.destroy_all
      generar_cuotas!
      movimientos_contables.each do |cuota|
        medio, fecha_pago, caja_id = pagos[cuota.cuota_numero]
        next if fecha_pago.nil?

        cuota.update!(pagado: true, medio_pago: medio, fecha_pago: fecha_pago, caja_turno_id: caja_id)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # El total se reparte en cuotas iguales; la última absorbe el redondeo para que sumen
  # exacto. Cada cuota queda fechada en su mes (cuota i → primera_cuota + (i-1) meses).
  def generar_cuotas!
    base = (monto_total_ars / cuotas_total).round(2)
    (1..cuotas_total).each do |i|
      fecha = fecha_primera_cuota >> (i - 1)
      monto = i == cuotas_total ? (monto_total_ars - base * (cuotas_total - 1)) : base
      movimientos_contables.create!(
        club:        club,
        sede:        sede,
        created_by:  created_by,
        tipo:        'egreso',
        categoria:   categoria,
        # LA CATEGORÍA REAL, no sólo la clave legacy. Sin esto cada cuota entraba al libro
        # diciendo "Otro" —porque las categorías propias del club no tienen clave legacy— en vez
        # de la que la persona eligió en pantalla.
        categoria_contable_id: categoria_contable_id,
        descripcion: "#{descripcion} — cuota #{i}/#{cuotas_total}",
        monto_ars:   monto,
        fecha:       fecha,
        medio_pago:  medio_pago,
        proveedor:   proveedor,
        cuota_numero: i,
        # TODAS nacen pendientes (sep-2026, decisión de Germán). Antes las de fecha pasada nacían
        # pagadas solas, con el medio de la compra y sin caja: una compra backdateada quedaba
        # «pagada» sin que nadie dijera cuándo ni con qué. Cada cuota se salda con «Registrar
        # pago», que pide medio, fecha y de qué caja salió si fue en efectivo.
        pagado:      false,
        # Se refleja quién pagó (tarjeta/responsable) en cada cuota para que sea visible.
        notas:       [("Pago: #{responsable}" if responsable.present?), notas].compact.join(' · ').presence,
      )
    end
  end
end
