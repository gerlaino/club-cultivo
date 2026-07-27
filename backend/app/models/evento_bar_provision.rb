# Provisión de un producto para un evento del bar. POLIMÓRFICA: el provisionable puede ser
# un BarProducto (depósito del salón), un Insumo (depósito de cultivo/general) o un Stock
# (dispensario: flor/derivados regulatorios y mercadería externa).
# Flujo: prevista → (comprar faltante) → reservada (sale del depósito) → consumida → sobrante vuelve.
#
# DOS SEMÁNTICAS DE RESERVA, según lo que se provisione:
#   • Descuento real (BarProducto, Insumo): reservar SACA la mercadería del depósito y el
#     sobrante vuelve al cerrar. Lo consumido es el COGS del evento.
#   • Apartado (TODO Stock: propio, externo y derivados): reservar NO descuenta — el stock sale
#     del inventario únicamente cuando se dispensa, que es lo que deja la trazabilidad. La
#     provisión solo BLOQUEA la cantidad (Stock#apartado_para_eventos) para que ninguna dispensa
#     ni reserva de paciente la pise, y al cerrar el evento se libera. Es la misma mecánica que
#     una Reserva de paciente, con otro destinatario. Tampoco suma COGS: su costo e ingreso viven
#     en la dispensación, contarlos acá sería duplicar.
class EventoBarProvision < ApplicationRecord
  self.table_name = 'evento_bar_provisiones' # inflector EN no pluraliza "provision" bien

  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :evento_bar
  belongs_to :provisionable, polymorphic: true

  validates :cantidad_prevista, :cantidad_reservada, :cantidad_consumida, :cantidad_consumo_interno,
            numericality: { greater_than_or_equal_to: 0 }
  validates :provisionable_id, uniqueness: { scope: [:evento_bar_id, :provisionable_type] }

  # Sobrante = lo reservado que no se consumió (vuelve al depósito al cerrar).
  def sobrante = (cantidad_reservada.to_d - consumido_total)

  # Lo que ya salió del apartado, por cualquiera de sus dos vías:
  #   • cantidad_consumida       → dispensado a socios durante el evento (o vendido, en el bar)
  #   • cantidad_consumo_interno → consumido en el evento sin dispensar (degustación, muestra)
  def consumido_total = (cantidad_consumida.to_d + cantidad_consumo_interno.to_d)

  # Cuánto sigue bloqueado por esta provisión (no descontado y no consumido todavía).
  def saldo_apartado = [cantidad_reservada.to_d - consumido_total, 0].max

  # Faltante para comprar = lo previsto que todavía no se reservó y tampoco está en el depósito.
  def faltante = [cantidad_prevista.to_d - cantidad_reservada.to_d - stock_disponible, 0].max

  # ¿Es un apartado (no descuenta) en vez de una salida real del depósito?
  def apartado? = provisionable.is_a?(Stock)

  # Cantidad que le cuesta al evento. En un apartado, lo DISPENSADO no cuenta acá: tiene su
  # propio costo e ingreso en la dispensación y sumarlo sería contarlo dos veces. Lo que sí es
  # costo del evento es lo consumido internamente (degustación, muestra): salió sin ingreso.
  def cantidad_para_cogs = (apartado? ? cantidad_consumo_interno.to_d : cantidad_consumida.to_d)

  # Imputa una dispensa hecha desde lo apartado: libera el bloqueo en la misma medida en que la
  # dispensación descontó el stock real. Sin esto habría doble descuento (baja `cantidad` Y
  # sigue bloqueado). Devuelve cuánto se pudo imputar.
  def imputar_dispensa!(cantidad)
    usar = [cantidad.to_d, saldo_apartado].min
    return 0.to_d if usar <= 0

    update!(cantidad_consumida: cantidad_consumida.to_d + usar)
    usar
  end

  # Consumo interno al cerrar: lo apartado que se usó en el evento sin dispensar a nadie.
  # Descuenta de verdad (tipo `consumo_evento`) y deja de bloquear.
  def registrar_consumo_interno!(cantidad:, usuario:)
    cantidad = [cantidad.to_d, saldo_apartado].min
    return 0.to_d if cantidad <= 0 || !apartado?

    provisionable.consumo_interno_evento!(cantidad: cantidad, usuario: usuario, evento: evento_bar)
    update!(cantidad_consumo_interno: cantidad_consumo_interno.to_d + cantidad)
    cantidad
  end

  # ── Unificación bar / insumo / stock ────────────────────────────────────
  # El dispatch por tipo (nombre, unidad, costo, depósito, disponible) vive UNA sola vez, en
  # Bar::ItemVendible, compartido con el POS del salón.
  def item = @item ||= Bar::ItemVendible.new(provisionable)

  def stock_disponible      = provisionable ? item.disponible : 0.to_d
  def provisionable_nombre  = provisionable && item.nombre
  def costo_unitario        = provisionable ? item.costo_unitario : 0.to_d
  def deposito              = provisionable && item.deposito
  def unidad                = provisionable ? item.unidad : 'u'

  # Aparta la cantidad del depósito (baja stock, salvo en el apartado regulatorio). Dispatch por tipo.
  def aplicar_reserva!(cantidad:, usuario:)
    case provisionable
    when BarProducto
      provisionable.registrar_salida!(cantidad: cantidad, tipo: 'reserva_evento', created_by: usuario,
                                      evento_bar: evento_bar, motivo: "Reserva evento «#{evento_bar.nombre}»")
    when Insumo
      provisionable.reservar_para_evento!(cantidad: cantidad)
    when Stock
      # No descuenta: el bloqueo lo produce cantidad_reservada (Stock#apartado_para_eventos).
      # Igual se valida el disponible, para no comprometer lo que no está.
      raise ArgumentError, "Sin stock suficiente de #{provisionable_nombre}" if cantidad.to_d > stock_disponible
    end
  end

  # Devuelve el sobrante al depósito (sube stock). Dispatch por tipo.
  # En un apartado no hay nada que devolver: basta con soltar el bloqueo (lo hace quien llama,
  # bajando cantidad_reservada).
  def aplicar_devolucion!(cantidad:, usuario:)
    case provisionable
    when BarProducto
      provisionable.registrar_ingreso!(cantidad: cantidad, tipo: 'devolucion_evento', created_by: usuario,
                                       evento_bar: evento_bar, motivo: "Sobrante evento «#{evento_bar.nombre}»")
    when Insumo
      provisionable.devolver_para_evento!(cantidad: cantidad)
    when Stock
      nil # apartado: soltar el bloqueo alcanza, nunca se descontó
    end
  end
end
