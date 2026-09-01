# Un frasco sobre la mesa durante un turno del mostrador.
#
# Se cuenta por STOCK, no por genética: dos frascos de la misma variedad de dos lotes distintos
# son dos ítems y dos conteos. Sumarlos perdería la trazabilidad lote→dispensación, que es el
# activo del producto.
class TurnoMostradorItem < ApplicationRecord
  acts_as_tenant(:club)

  # Los números que ajustan inventario: con cuánto se recibió, cuánto se corrigió y cuánto se
  # contó al cerrar. Lo repuesto y lo devuelto NO se auditan acá: ya tienen su propio rastro con
  # autor y hora en `TurnoMostradorMovimiento`, y duplicarlo llenaría el historial de ruido.
  include Auditable
  auditar_solo :cantidad_apertura, :cantidad_ajuste, :cantidad_cierre, :motivo_diferencia

  belongs_to :club
  belongs_to :turno_mostrador
  belongs_to :stock

  has_many :movimientos, class_name: 'TurnoMostradorMovimiento', dependent: :destroy

  validates :stock_id, uniqueness: { scope: :turno_mostrador_id }

  scope :en_turno_abierto, -> { joins(:turno_mostrador).where(turno_mostradores: { estado: 'abierto' }) }
  # Lo que se puede ofrecer para dispensar: además de abierto, RECIBIDO por quien atiende.
  scope :operativos, -> { en_turno_abierto.where.not(turno_mostradores: { confirmado_at: nil }) }

  # Lo mismo que `#esperado`, escrito en SQL. Existe para que sumar el apartado de un stock sea
  # UNA query y no una por ítem: `Stock#cantidad_disponible_real` se llama en listados enteros, y
  # `apartado_para_eventos` ya suma en Ruby (con su N+1 propio). No sumamos otro.
  SALDO_SQL = 'GREATEST(cantidad_apertura + cantidad_repuesta - cantidad_devuelta ' \
              '+ cantidad_ajuste - cantidad_dispensada, 0)'.freeze

  def self.saldo_total = sum(Arel.sql(SALDO_SQL)).to_d

  # Imputa una dispensa hecha desde este mostrador: libera el bloqueo en la misma medida en que
  # la dispensación descontó el stock real. Sin esto habría doble descuento —baja `cantidad` Y
  # sigue apartado— y el disponible caería el doble. Es el gemelo de
  # `EventoBarProvision#imputar_dispensa!`, por el mismo motivo.
  # El conteo del cierre. La diferencia contra lo esperado es una CORRECCIÓN DE CONTEO, no una
  # segunda puerta de salida del inventario: la regla de oro sigue siendo que lo trazable sale
  # por dispensación. Por eso va como `ajuste` y no como `merma` — el informe de Pérdidas cuenta
  # merma, y anotar ahí lo que no cuadró declararía destruido producto que quizá está entero.
  # "No cuadró" y "se pudrió" no son lo mismo, y para un auditor la diferencia importa.
  #
  # El motivo es obligatorio cuando hay diferencia: un faltante sin explicación no se puede
  # revisar después, y a los tres días nadie se acuerda.
  def registrar_cierre!(contado:, usuario:, motivo: nil)
    update!(cantidad_cierre: contado.to_d, motivo_diferencia: motivo.presence)
    dif = diferencia_cierre
    return 0.to_d if dif.nil? || dif.zero?

    stock.with_lock do
      stock.update!(cantidad: [stock.cantidad.to_d + dif, 0].max)
      stock.stock_movimientos.create!(
        tipo: 'ajuste', gramos: dif, usuario: usuario, turno_mostrador: turno_mostrador,
        notas: "Arqueo del mostrador — #{dif.negative? ? 'faltante' : 'sobrante'} de " \
               "#{dif.abs.round(3).to_f} #{stock.unidad || 'g'}#{motivo.present? ? " — #{motivo}" : ''}"
      )
    end
    stock.reload.marcar_agotado_si_vacio!(usuario: usuario)
    dif
  end

  # El inverso de `imputar_dispensa!`: la dispensa se canceló y el producto vuelve.
  #
  # Sólo tiene sentido con el turno ABIERTO. Si ya cerró, su arqueo se hizo con el producto
  # afuera y tocarlo ahora movería un número que alguien ya firmó: en ese caso el producto vuelve
  # al depósito y la mesa de mañana se carga de cero.
  def revertir_dispensa!(cantidad)
    return 0.to_d unless turno_mostrador&.abierto?

    devolver = [cantidad.to_d, cantidad_dispensada.to_d].min
    return 0.to_d if devolver <= 0

    update!(cantidad_dispensada: cantidad_dispensada.to_d - devolver)
    devolver
  end

  def imputar_dispensa!(cantidad)
    usar = [cantidad.to_d, saldo_apartado].min
    return 0.to_d if usar <= 0

    update!(cantidad_dispensada: cantidad_dispensada.to_d + usar)
    usar
  end

  # La verdad del ítem, derivada y nunca guardada calculada. Este mismo número es lo que el ítem
  # BLOQUEA sobre el stock (apartado, no descuento) y el techo de lo que se puede dispensar.
  def esperado
    cantidad_apertura.to_d + cantidad_repuesta.to_d - cantidad_devuelta.to_d +
      cantidad_ajuste.to_d - cantidad_dispensada.to_d
  end

  # Lo que sigue bloqueado sobre el stock. Nunca negativo: un ítem sobre-dispensado (que no
  # debería poder pasar) no puede devolver disponibilidad al pozo.
  def saldo_apartado = [esperado, 0.to_d].max

  # Cuánto no apareció al contarlo. nil mientras el turno no se cerró.
  def diferencia_cierre
    return nil if cantidad_cierre.nil?

    (cantidad_cierre.to_d - esperado).round(3)
  end

  # Lo que el que abrió corrigió sobre lo que dejó el turno anterior. No es una ceremonia de
  # conteo: es un campo editable, y si lo tocó queda registrado.
  def diferencia_apertura
    return nil if cantidad_heredada.nil?

    (cantidad_apertura.to_d - cantidad_heredada.to_d).round(3)
  end
end
