module Devoluciones
  # DE QUÉ CAJA SALE EL EFECTIVO QUE SE LE DEVUELVE A UN PACIENTE. La elegida (administración) o
  # la abierta en la sede (quien atiende, que devuelve de su cajón). Con caja, TIENE QUE ALCANZAR:
  # devolver $8.500 de un cajón con $5.000 es un faltante inventado esa noche — se devuelve por
  # transferencia o se trae plata. Sin ninguna caja (administración, de su bolsillo) se escribe
  # igual y no entra a ningún arqueo, como cualquier pago en efectivo del admin.
  #
  # Vivía adentro de `Dispensaciones::Cancelar`. Salió cuando la devolución de lo que el paciente
  # tiene a favor (`CuentasCorrientes::DevolverSaldo`) necesitó la misma regla: dos copias de
  # «¿alcanza la caja?» dejan de coincidir a la primera corrección.
  #
  # `eligio_caja`: si la persona dijo algo sobre la caja (aunque sea «ninguna»). Si no dijo nada,
  # se usa la abierta de la sede.
  module CajaDeSalida
    MEDIOS = %w[efectivo transferencia mercado_pago].freeze

    def self.call(club_id:, sede_id:, monto:, eligio_caja:, caja_turno_id: nil)
      caja = if eligio_caja
               return nil if caja_turno_id.blank?

               c = CajaTurno.unscoped.abiertas.where(club_id: club_id, punto_type: CajaTurno::PUNTO_MOSTRADOR).find_by(id: caja_turno_id)
               raise ArgumentError, 'Esa caja no está abierta.' if c.nil?
               c
             else
               CajaTurno.abierta_en_sede(club_id: club_id, sede_id: sede_id)
             end
      return nil if caja.nil?

      hay = caja.efectivo_esperado_ars.to_d
      if hay < monto.to_d
        raise ArgumentError, "En la caja hay #{fmt(hay)} y hay que devolver #{fmt(monto)}: devolvé por transferencia, o ingresá plata a la caja primero."
      end
      caja
    end

    def self.fmt(n) = ActionController::Base.helpers.number_to_currency(n, unit: '$', separator: ',', delimiter: '.', precision: 0)
  end
end
