module Portal
  # Lo que el paciente retiró. Es la primera cosa que va a buscar cuando entra: cuándo fue, qué
  # se llevó y cuánto pagó.
  #
  # No reusa el listado interno de dispensaciones a propósito. Ese trae precio de costo, quién
  # dispensó, notas internas y el estado de la cuenta corriente; acá sale lo que es SUYO y nada
  # del funcionamiento de la organización.
  class HistorialController < BaseController
    def index
      # Sin ficha no hay historial. Pasa con una cuenta creada a mano o con la ficha borrada: sin
      # esto era un 500 en la pantalla de inicio, que ahora pide este endpoint siempre.
      return render json: { data: [] } if ficha.nil?

      dispensas = ficha.dispensaciones
                       .includes(:sede, items: { stock: %i[genetica lote] })
                       .order(fecha_dispensacion: :desc, id: :desc)
                       .limit(100)

      render json: { data: dispensas.map { |d| dispensa_json(d) } }
    end

    # GET /portal/historial/:id — el detalle de UNA dispensa suya, con la trazabilidad de cada
    # frasco (27-oct-2026). Se busca DENTRO de sus dispensas: el id de otro paciente da 404.
    def show
      dispensa = ficha&.dispensaciones&.find_by(id: params[:id])
      return render json: { error: 'No encontramos esa dispensa.' }, status: :not_found unless dispensa

      render json: { data: Portal::DetalleDispensa.new(dispensa).call }
    end

    private

    # La ficha del paciente logueado. Siempre la suya: no hay un `:id` en la URL que alguien
    # pueda cambiar por el del vecino.
    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    def dispensa_json(dispensa)
      {
        id:     dispensa.id,
        numero: format('%04d', dispensa.id),
        fecha:  dispensa.fecha_dispensacion,
        sede:   dispensa.sede&.nombre,
        anulada: dispensa.anulada_at.present?,
        # Para abrir el pasaporte que ya existe, con las fotos y la ficha de la genética.
        token:  dispensa.token,
        gramos: dispensa.cantidad_total.to_f,
        # Lo que aportó por esa entrega. `aporte_socio_ars` es el total de la dispensa.
        total:  dispensa.aporte_socio_ars.to_f,
        # Cuánto de ese total fue el envío (nil = sin envío; 0 = bonificado).
        envio:  dispensa.costo_envio_ars&.to_f,
        items:  dispensa.items.map { |i|
          { genetica: i.stock&.genetica&.nombre, cantidad: i.cantidad.to_f,
            forma: i.stock&.forma_producto, unidad: i.stock&.unidad,
            lote: i.lote_codigo.presence || i.stock&.lote&.codigo }
        },
      }
    end
  end
end
