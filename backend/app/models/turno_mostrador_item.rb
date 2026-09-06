# EL CONTEO DE UN PRODUCTO EN UN TURNO: cuánto decía la mesa y cuánto se contó, al abrir y al
# cerrar. Más lo que salió mientras el turno estuvo abierto.
#
# YA NO ES EL CONTENIDO DE LA MESA — eso es `MostradorItem`, permanente y del mostrador. Este
# registro es el ARQUEO: existe para poder mostrar después contra qué se contó y quién lo hizo.
#
# Se cuenta por STOCK, no por genética: dos frascos de la misma variedad de dos lotes distintos
# son dos conteos. Sumarlos perdería la trazabilidad lote→dispensación, que es el activo del
# producto.
class TurnoMostradorItem < ApplicationRecord
  acts_as_tenant(:club)

  # Los números del arqueo. Lo repuesto y lo devuelto NO se auditan acá: eso ahora son
  # movimientos de la mesa, con su propio autor y hora en `MostradorMovimiento`.
  include Auditable
  auditar_solo :esperado_apertura, :cantidad_apertura, :esperado_cierre, :cantidad_cierre,
               :motivo_diferencia

  belongs_to :club
  belongs_to :turno_mostrador
  belongs_to :stock

  validates :stock_id, uniqueness: { scope: :turno_mostrador_id }

  # EL ESPERADO NO SE CALCULA ACÁ: lo dice la mesa (`MostradorItem#cantidad`), que es el estado
  # real del mostrador. Se GUARDA en el ítem al abrir y al cerrar para que el arqueo quede
  # escrito. Reconstruirlo sumando movimientos sería volver a tener el mismo número en dos
  # lugares, que es de dónde salieron los tres bugs de doble descuento de este proyecto.
  #
  # Cuánto no apareció al contarlo. nil mientras el turno no se cerró.
  def diferencia_cierre
    return nil if cantidad_cierre.nil? || esperado_cierre.nil?

    (cantidad_cierre.to_d - esperado_cierre.to_d).round(3)
  end

  # ¿ESTE SOBRANTE QUEDÓ ANOTADO SIN APLICARSE?
  #
  # Cuando quien atiende cuenta MÁS de lo que había, el número se guarda pero no mueve nada:
  # contar no crea producto de la nada (ver `CerrarCaja#sobrante_sin_aplicar?`). Entonces
  # `cantidad_cierre` dice 1.000 y el inventario nunca vio esos 700 de más — y todo lo que
  # después haga cuentas contra lo contado tiene que saberlo, o las repite sobre una base falsa.
  # Le pasaba a `CorregirCierre`: corregir 1.000 a 100 restaba 900 del stock en vez de 200.
  #
  # Se DERIVA en vez de guardarse en una columna: es la misma regla que lo produjo, y escrita en
  # dos lados un día dejan de coincidir. El precio es que si esa persona cambia de rol después,
  # esto responde por el rol de hoy — por eso la corrección la hace administración, con motivo,
  # y viendo lo esperado y lo contado en pantalla.
  def sobrante_no_aplicado?
    return false if esperado_cierre.nil? || cantidad_cierre.nil?
    return false unless cantidad_cierre.to_d > esperado_cierre.to_d

    turno_mostrador&.cerrado_por&.atiende_mostrador? || false
  end

  # Cuánto movió del INVENTARIO el cierre de este ítem. No es lo mismo que la diferencia contada:
  # un sobrante de quien atiende quedó anotado y no movió nada.
  def efecto_en_inventario
    return 0.to_d if sobrante_no_aplicado?

    diferencia_cierre || 0.to_d
  end

  # Lo que quien abrió contó, contra lo que decía la mesa. No es una ceremonia: es un campo
  # editable que no bloquea, y si lo tocó queda registrado.
  def diferencia_apertura
    return nil if esperado_apertura.nil?

    (cantidad_apertura.to_d - esperado_apertura.to_d).round(3)
  end

  # Lo dispensado durante el turno. Es un CONTADOR para el arqueo y la merma: quien baja la mesa
  # de verdad es `MostradorItem`. Tenerlo también acá no es duplicar el apartado —el apartado
  # vive en un solo lugar— sino registrar cuánto salió en ESTA jornada.
  def imputar_dispensa!(cantidad)
    usar = cantidad.to_d
    return 0.to_d if usar <= 0

    update!(cantidad_dispensada: cantidad_dispensada.to_d + usar)
    usar
  end

  # El inverso: la dispensa se canceló y el producto vuelve. Sólo con el turno ABIERTO — si ya
  # cerró, su arqueo se hizo con el producto afuera y tocarlo ahora movería un número firmado.
  def revertir_dispensa!(cantidad)
    return 0.to_d unless turno_mostrador&.abierto?

    devolver = [cantidad.to_d, cantidad_dispensada.to_d].min
    return 0.to_d if devolver <= 0

    update!(cantidad_dispensada: cantidad_dispensada.to_d - devolver)
    devolver
  end
end
