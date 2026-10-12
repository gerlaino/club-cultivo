# DÓNDE ESTÁ LA PLATA DE LA ORGANIZACIÓN AHORA (12-oct-2026, rediseño de Contabilidad).
#
# Tres cifras que el panel de conducción y Contabilidad muestran con el mismo nombre, así que
# salen de acá y de ningún otro lado (regla «mismo nombre, mismo número»):
#   · efectivo en cajas abiertas (lo que el arqueo espera encontrar en cada cajón);
#   · efectivo de delivery sin rendir (cobrado en la calle + rendiciones entregadas sin recibir);
#   · cuentas por cobrar (saldos negativos de las cuentas corrientes), con su antigüedad.
#
# El saldo del banco no se lleva en la app: no se inventa.
#
# ANTIGÜEDAD (FIFO): un pago cancela lo más viejo primero, así que lo que se debe hoy son los
# cargos MÁS RECIENTES hasta cubrir la deuda. Se recorren los movimientos que bajaron el saldo, del
# más nuevo al más viejo, y cada peso adeudado toma la edad del cargo del que sale.
module Contabilidad
  class Posicion
    TRAMOS = [[:hasta_30, 0..30], [:de_30_a_60, 31..60], [:mas_de_60, 61..]].freeze

    def initialize(club:, sede_id: nil, hoy: Time.zone.today)
      @club = club
      @sede_id = sede_id.presence
      @hoy = hoy
    end

    def call
      efectivo = efectivo_en_cajas_ars
      delivery = delivery_sin_rendir_ars
      {
        efectivo_en_cajas_ars:   efectivo,
        cajas_abiertas:          cajas.size,
        delivery_sin_rendir_ars: delivery,
        disponible_ars:          (efectivo + delivery).round(2),
        por_cobrar_ars:          por_cobrar_ars,
        deudores:                deudas.count,
        antiguedad:              antiguedad,
      }
    end

    def cajas
      @cajas ||= begin
        sede_ids = @sede_id ? [@sede_id] : @club.sedes.pluck(:id)
        CajaTurno.activas.where(club_id: @club.id, sede_id: sede_ids).to_a
      end
    end

    def efectivo_en_cajas_ars = cajas.sum { |c| c.efectivo_esperado_ars.to_d }.to_f.round(2)

    # El delivery es de la organización, no de una sede: con una sede elegida no se cuenta.
    # Lo ya rendido (tiene `rendicion_caja_id`) se cuenta por su rendición, no dos veces.
    def delivery_sin_rendir_ars
      return 0.0 if @sede_id

      en_mano  = Cobro.efectivo_en_transito.where(club_id: @club.id, rendicion_caja_id: nil).sum(:monto_ars).to_d
      rendidas = RendicionCaja.pendientes.where(club_id: @club.id).sum(:monto_declarado_ars).to_d
      (en_mano + rendidas).to_f.round(2)
    end

    def deudas = CuentaCorriente.where(club_id: @club.id).where('saldo_disponible < 0')

    def por_cobrar_ars = deudas.sum('-saldo_disponible').to_f

    def antiguedad
      tramos = TRAMOS.to_h { |k, _| [k, 0.to_d] }
      lista = deudas.pluck(:id, :saldo_disponible)
      return tramos.transform_values(&:to_f) if lista.empty?

      cargos = CuentaCorrienteMovimiento.where(cuenta_corriente_id: lista.map(&:first))
                                        .where('saldo_nuevo < saldo_anterior')
                                        .order(created_at: :desc)
                                        .pluck(:cuenta_corriente_id, :saldo_anterior, :saldo_nuevo, :created_at)
                                        .group_by(&:first)
      lista.each do |cc_id, saldo|
        resta = -saldo.to_d
        (cargos[cc_id] || []).each do |_, antes, despues, cuando|
          break unless resta.positive?

          parte = [antes.to_d - despues.to_d, resta].min
          tramos[tramo((@hoy - cuando.in_time_zone.to_date).to_i)] += parte
          resta -= parte
        end
        # Deuda sin cargo que la explique (datos viejos): se la trata como la más antigua.
        tramos[:mas_de_60] += resta if resta.positive?
      end
      tramos.transform_values { |v| v.to_f.round(2) }
    end

    private

    def tramo(dias) = TRAMOS.find { |_, r| r.cover?(dias) }&.first || :hasta_30
  end
end
