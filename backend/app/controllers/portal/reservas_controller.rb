module Portal
  # «Reservar» del paciente (28-oct-2026): pide de la mesa, ve cómo quedaron sus pedidos y cancela el
  # que todavía nadie confirmó.
  #
  #   GET    /portal/reservas              sus pedidos y reservas de los últimos 30 días, y los días que
  #                                        puede elegir para retirar (hoy y mañana) con cuál está libre
  #   POST   /portal/reservas              pedir: { sede_id, fecha (hoy o mañana), items: [{ stock_id, cantidad }], notas }
  #   PATCH  /portal/reservas/:id/cancelar sólo un pedido «solicitada» suyo
  #
  # Siempre SUS reservas: salen de su ficha. Lista blanca campo por campo (nada de notas internas,
  # ni de quién la cargó, ni de la seña).
  class ReservasController < BaseController
    DIAS = 30

    # Pedir es de las organizaciones que atienden Reservar; cancelar uno que ya pidió, siempre.
    before_action only: :create do
      next if current_club.portal_reservar?

      render json: { error: 'Tu organización no toma reservas desde el portal por ahora.' }, status: :forbidden
    end

    def index
      return render json: { data: [], fechas_retiro: [] } if ficha.nil?

      reservas = current_club.reservas.where(paciente_id: ficha.id)
                             .where('created_at >= ?', DIAS.days.ago)
                             .includes(items: { stock: [:sede, :genetica, { lote: :genetica }] })
                             .order(created_at: :desc)
      render json: {
        data:          reservas.map { |r| reserva_json(r) },
        # Los días que la pantalla ofrece para retirar y cuáles le quedan libres (una por día): lo
        # decide el backend.
        fechas_retiro: Reserva.dias_portal(ficha),
      }
    end

    def create
      return render json: { error: 'Tu cuenta no tiene ficha de paciente.' }, status: :unprocessable_entity if ficha.nil?

      res = Portal::PedirReserva.call(paciente: ficha, sede_id: params[:sede_id], fecha: params[:fecha],
                                      items: params[:items], notas: params[:notas])
      return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

      render json: { data: reserva_json(res.reserva) }, status: :created
    end

    def cancelar
      reserva = ficha && current_club.reservas.find_by(id: params[:id], paciente_id: ficha.id)
      return render json: { error: 'Pedido no encontrado' }, status: :not_found unless reserva
      unless reserva.solicitada?
        return render json: { error: 'Ya lo confirmó tu organización: para cambiarlo, escribile por el chat.' }, status: :unprocessable_entity
      end

      reserva.cancelar!(motivo: 'Lo canceló el paciente desde el portal')
      render json: { data: reserva_json(reserva) }
    end

    private

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    def reserva_json(r)
      sede = r.items.first&.stock&.sede
      {
        id:             r.id,
        estado:         r.estado,
        origen:         r.origen,
        fecha:          r.fecha_entrega_estimada,
        sede:           sede&.nombre,
        total_estimado: r.aporte_estimado_ars&.to_f,
        motivo_rechazo: r.motivo_rechazo,
        creada_at:      r.created_at,
        items: r.items.map do |it|
          { nombre: it.genetica_nombre.presence || Portal::DetalleDispensa::FORMAS.fetch(it.stock&.forma_producto, 'Producto'),
            cantidad: it.cantidad.to_f, unidad: it.stock&.unidad.presence || 'g',
            precio: it.precio_unitario_ars&.to_f }
        end,
      }
    end
  end
end
