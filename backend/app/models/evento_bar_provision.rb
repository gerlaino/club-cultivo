# Provisión de un producto para un evento del bar. POLIMÓRFICA: el provisionable puede ser
# un BarProducto (depósito del salón) o un Insumo (depósito de cultivo/general).
# Flujo: prevista → (comprar faltante) → reservada (sale del depósito) → consumida → sobrante vuelve.
class EventoBarProvision < ApplicationRecord
  self.table_name = 'evento_bar_provisiones' # inflector EN no pluraliza "provision" bien

  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :evento_bar
  belongs_to :provisionable, polymorphic: true

  validates :cantidad_prevista, :cantidad_reservada, :cantidad_consumida,
            numericality: { greater_than_or_equal_to: 0 }
  validates :provisionable_id, uniqueness: { scope: [:evento_bar_id, :provisionable_type] }

  # Sobrante = lo reservado que no se consumió (vuelve al depósito al cerrar).
  def sobrante = (cantidad_reservada.to_d - cantidad_consumida.to_d)

  # Faltante para comprar = lo previsto que no está en el depósito del provisionable.
  def faltante = [cantidad_prevista.to_d - stock_disponible, 0].max

  # ── Unificación bar / insumo ────────────────────────────────────────────
  def stock_disponible
    case provisionable
    when BarProducto then provisionable.stock.to_d
    when Insumo      then provisionable.stock_actual.to_d
    else 0.to_d
    end
  end

  def provisionable_nombre = provisionable&.nombre

  def costo_unitario
    case provisionable
    when BarProducto then provisionable.costo_ars.to_d
    when Insumo      then provisionable.costo_promedio_ars.to_d
    else 0.to_d
    end
  end

  # Depósito de origen para la UI: salon | cultivo | general.
  def deposito
    case provisionable
    when BarProducto then 'salon'
    when Insumo      then provisionable.tipo
    end
  end

  def unidad
    provisionable.respond_to?(:unidad_medida) ? provisionable.unidad_medida : 'u'
  end

  # Aparta la cantidad del depósito (baja stock). Dispatch por tipo.
  def aplicar_reserva!(cantidad:, usuario:)
    case provisionable
    when BarProducto
      provisionable.registrar_salida!(cantidad: cantidad, tipo: 'reserva_evento', created_by: usuario,
                                      evento_bar: evento_bar, motivo: "Reserva evento «#{evento_bar.nombre}»")
    when Insumo
      provisionable.reservar_para_evento!(cantidad: cantidad)
    end
  end

  # Devuelve el sobrante al depósito (sube stock). Dispatch por tipo.
  def aplicar_devolucion!(cantidad:, usuario:)
    case provisionable
    when BarProducto
      provisionable.registrar_ingreso!(cantidad: cantidad, tipo: 'devolucion_evento', created_by: usuario,
                                       evento_bar: evento_bar, motivo: "Sobrante evento «#{evento_bar.nombre}»")
    when Insumo
      provisionable.devolver_para_evento!(cantidad: cantidad)
    end
  end
end
