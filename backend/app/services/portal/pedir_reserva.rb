module Portal
  # El paciente pide desde su portal lo que hay sobre la mesa (Germán, 28-oct-2026: el catálogo ES
  # «Reservar»). El pedido nace «solicitada» y NO aparta nada: recién cuando administración (admin o
  # supervisor) lo confirma pasa a ser una reserva como cualquiera.
  #
  # Reglas:
  # - elige la sede y retira HOY o MAÑANA, nunca más allá (`Reserva#fecha_entrega_futura`);
  # - sólo lo que ve en el catálogo de ESA sede (`Portal::Catalogo`): lo que no se muestra no se pide;
  # - contra lo libre de la mesa, sin decirle cuánto hay (`Reserva#stock_disponible`);
  # - una reserva por día (`Reserva.del_dia`): una para hoy y otra para mañana, no dos el mismo día.
  class PedirReserva
    Resultado = Struct.new(:reserva, :error, keyword_init: true) do
      def ok? = error.nil?
    end

    def self.call(...) = new(...).call

    def initialize(paciente:, sede_id:, fecha:, items:, notas: nil)
      @paciente = paciente
      @club     = paciente.club
      @sede_id  = sede_id
      @fecha    = fecha
      @items    = Array(items)
      @notas    = notas.to_s.strip.first(500).presence
    end

    def call
      return error('Elegí al menos un producto.') if lineas.empty?

      fecha = Date.iso8601(@fecha.to_s) rescue nil
      return error('Elegí si lo retirás hoy o mañana.') unless fecha
      if Reserva.del_dia(@paciente, fecha)
        dia = fecha == Time.zone.today ? 'hoy' : 'ese día'
        return error("Ya tenés una reserva para #{dia}. Podés pedir para el otro día, o cancelar la que tenés si todavía no la confirmaron.")
      end

      mesa = Portal::Catalogo.de_la_sede(@club, @sede_id)
      return error('Esa sede no tiene productos para reservar.') if mesa.nil?

      reserva = @club.reservas.new(paciente: @paciente, origen: 'portal', estado: 'solicitada',
                                   solicitada_at: Time.current, fecha_entrega_estimada: fecha,
                                   notas: @notas && "Del paciente: #{@notas}")
      lineas.each do |ln|
        item = mesa[ln[:stock_id]]
        return error('Uno de los productos ya no está en la mesa de esa sede. Volvé a mirar el catálogo.') unless item

        reserva.items.build(stock: item.stock, cantidad: ln[:cantidad],
                            precio_unitario_ars: Reserva.precio_para(item.stock, @paciente))
      end
      reserva.aporte_estimado_ars = reserva.items.sum(&:subtotal_ars).round(2)

      return error(reserva.errors.full_messages.to_sentence) unless reserva.save

      avisar_a_quien_confirma(reserva)
      Resultado.new(reserva: reserva)
    end

    private

    def lineas
      @lineas ||= @items.filter_map do |l|
        l = l.respond_to?(:to_unsafe_h) ? l.to_unsafe_h : l.to_h
        stock_id = l['stock_id'] || l[:stock_id]
        cantidad = (l['cantidad'] || l[:cantidad]).to_d
        { stock_id: stock_id.to_i, cantidad: cantidad } if stock_id.present? && cantidad.positive?
      end
    end

    # Sin el detalle en el push (se ve con el teléfono bloqueado): quién y a dónde ir.
    def avisar_a_quien_confirma(reserva)
      quien = @paciente.nombre_completo
      Reserva::ROLES_CONFIRMAN.each do |rol|
        AlertaInterna.create!(
          club: @club, tipo: 'reserva_solicitada', severidad: 'info', destinada_a_role: rol,
          mensaje: "#{quien} pidió desde el portal para retirar #{reserva.fecha_entrega_estimada == Time.zone.today ? 'hoy' : 'mañana'}: " \
                   "#{reserva.descripcion_items}. Confirmalo o rechazalo.",
          contexto: { reserva_id: reserva.id, paciente_id: @paciente.id, accion: 'reserva_solicitada' }
        )
      end
      PushNotificationService.notify_roles_async(
        @club, Reserva::ROLES_CONFIRMAN, title: "#{quien} pidió una reserva desde el portal",
        body: 'Confirmala o rechazala.', url: '/reservas?estado=solicitada', tipo: 'reserva_solicitada'
      )
    rescue StandardError => e
      Rails.logger.warn("[pedido portal] no se pudo avisar: #{e.class} #{e.message}")
    end

    def error(msg) = Resultado.new(error: msg)
  end
end
