module Pagos
  module Suscripciones
    # Arma la suscripción en Mercado Pago y devuelve el link para suscribirse (`init_point`).
    #
    # Sin plan asociado y una por organización: así cada organización tiene SU monto (lo pone
    # super admin) y el autocultivo, el precio fijo de la plataforma. El preapproval nace
    # `pending`: la persona elige cómo paga en Mercado Pago, y lo que pase después llega por el
    # webhook. `external_reference` = la organización, para que el aviso sepa de quién es.
    #
    # Mercado Pago cobra en PESOS: el monto es en ARS. Generar una nueva cancela la anterior que
    # siguiera viva (no puede haber dos cobrando a la misma organización).
    class Crear
      class Error < StandardError; end

      def initialize(club:, monto_ars:, payer_email:, origen:, por: nil, cliente: MercadoPago.new)
        @club = club
        @monto = monto_ars.to_d
        @email = payer_email.to_s.strip.downcase
        @origen = origen
        @por = por
        @cliente = cliente
      end

      def call
        raise Error, 'Mercado Pago no está configurado todavía.' unless MercadoPago.configurado?
        raise Error, 'El monto tiene que ser mayor a cero.' unless @monto.positive?
        raise Error, 'Falta el mail de la cuenta de Mercado Pago que va a pagar.' unless URI::MailTo::EMAIL_REGEXP.match?(@email)

        motivo = @origen == 'autocultivo' ? 'Cultivo Espacial · Autocultivo' : "Cultivo Espacial · #{@club.name}"
        mp = @cliente.crear_preapproval(
          reason: motivo, external_reference: "club-#{@club.id}", payer_email: @email,
          back_url: "#{base_url}/#{@origen == 'autocultivo' ? 'preferencias' : ''}",
          status: 'pending',
          auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: @monto.to_f, currency_id: 'ARS' }
        )

        Suscripcion.transaction do
          @club.suscripciones.vivas.find_each { |s| Cancelar.new(s, cliente: @cliente).call }
          @club.suscripciones.create!(
            mp_preapproval_id: mp['id'], estado: Suscripcion::ESTADO_MP.fetch(mp['status'], 'pendiente'),
            origen: @origen, monto_ars: @monto, payer_email: @email, motivo: motivo,
            link: mp['init_point'], creada_por: @por, mp_datos: mp
          )
        end
      rescue MercadoPago::Error => e
        raise Error, e.message
      end

      private

      # Mercado Pago exige una URL pública de vuelta. Es a dónde vuelve la persona: no confirma nada
      # (la confirmación es el webhook).
      def base_url = ENV['APP_HOST'].presence&.then { |h| h.start_with?('http') ? h : "https://#{h}" } || 'https://cultivoespacial.com'
    end
  end
end
