module Pagos
  module Suscripciones
    # Lo que hace un aviso de Mercado Pago. NUNCA se cree lo que trae el aviso: se usa sólo para
    # saber QUÉ mirar, y se le vuelve a pedir el recurso a MP. Idempotente: el mismo aviso dos
    # veces deja todo igual (los cobros son únicos por `mp_id`).
    #
    #   · `subscription_preapproval`: cambió la suscripción (se autorizó, se pausó, se canceló).
    #   · `subscription_authorized_payment`: un cobro mensual. Si salió, el plan se extiende un
    #     mes desde lo que ya tenía pago (o desde hoy) y, si estaba pausada por falta de pago o por
    #     fin de la prueba, se despausa.
    class ProcesarAviso
      DIAS_GRACIA = 3

      def initialize(tipo:, id:, cliente: MercadoPago.new, hoy: Time.zone.today)
        @tipo = tipo.to_s
        @id = id.to_s
        @cliente = cliente
        @hoy = hoy
      end

      def call
        case @tipo
        when 'subscription_preapproval', 'preapproval' then preapproval!
        when 'subscription_authorized_payment', 'authorized_payment' then cobro!
        end
      end

      private

      def preapproval!
        mp = @cliente.preapproval(@id)
        s  = Suscripcion.find_by(mp_preapproval_id: mp['id'])
        return unless s

        s.update!(estado: Suscripcion::ESTADO_MP.fetch(mp['status'], s.estado), mp_datos: mp)
        s
      end

      def cobro!
        mp = @cliente.authorized_payment(@id)
        s  = Suscripcion.find_by(mp_preapproval_id: mp['preapproval_id'])
        return unless s

        aprobado = mp.dig('payment', 'status') == 'approved'
        Suscripcion.transaction do
          cobro = s.cobros.find_or_initialize_by(mp_id: mp['id'].to_s)
          ya_aprobado = cobro.persisted? && cobro.aprobado?
          cobro.assign_attributes(estado: aprobado ? 'aprobado' : (mp.dig('payment', 'status') || mp['status']).to_s,
                                  monto_ars: mp['transaction_amount'], mp_datos: mp,
                                  cobrado_at: (Time.zone.parse(mp['date_created'].to_s) rescue nil) || Time.current)
          if aprobado && !ya_aprobado
            club  = s.club
            # Desde lo PAGADO (el último cobro), no desde `plan_activo_hasta`, que lleva la gracia:
            # si no, cada mes se correría tres días. Sin cobros previos, desde la prueba o desde hoy.
            pagado = SuscripcionCobro.joins(:suscripcion).where(suscripciones: { club_id: club.id })
                                     .where(estado: 'aprobado').maximum(:extiende_hasta)
            desde = [pagado || club.plan_activo_hasta, @hoy].compact.max
            hasta = desde + 1.month
            cobro.extiende_hasta = hasta
            club.update!(plan_trial: false, plan_activo_hasta: hasta + DIAS_GRACIA)
            club.reactivar! if club.suspendido? && %w[no_pago prueba_terminada].include?(club.suspension_motivo)
            s.update!(ultimo_cobro_at: Time.current, estado: 'activa')
          end
          cobro.save!
          cobro
        end
      end
    end
  end
end
