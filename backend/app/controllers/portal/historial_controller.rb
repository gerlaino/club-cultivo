module Portal
  # Lo que el paciente retiró. Es la primera cosa que va a buscar cuando entra: cuándo fue, qué
  # se llevó y cuánto pagó.
  #
  # No reusa el listado interno de dispensaciones a propósito. Ese trae precio de costo, quién
  # dispensó, notas internas y el estado de la cuenta corriente; acá sale lo que es SUYO y nada
  # del funcionamiento de la organización.
  class HistorialController < BaseController
    def index
      dispensas = ficha.dispensaciones
                       .includes(items: { stock: :genetica })
                       .order(fecha_dispensacion: :desc, id: :desc)
                       .limit(100)

      render json: { data: dispensas.map { |d| dispensa_json(d) } }
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
        fecha:  dispensa.fecha_dispensacion,
        # Para abrir el pasaporte que ya existe, con las fotos y la ficha de la genética.
        token:  dispensa.token,
        gramos: dispensa.cantidad_total.to_f,
        # Lo que aportó por esa entrega. `aporte_socio_ars` es el total de la dispensa.
        total:  dispensa.aporte_socio_ars.to_f,
        items:  dispensa.items.map { |i|
          { genetica: i.stock&.genetica&.nombre, cantidad: i.cantidad.to_f,
            forma: i.stock&.forma_producto, unidad: i.stock&.unidad }
        },
      }
    end
  end
end
