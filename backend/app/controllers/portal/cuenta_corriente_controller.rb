module Portal
  # Su cuenta corriente: cuánto tiene, cuánto debe y qué movimientos la explican.
  #
  # Aparece SÓLO si la organización le abrió cuenta. Un paciente que paga siempre al contado no
  # tiene ninguna, y mostrarle una sección vacía con "saldo $0" le hace creer que debe algo o que
  # le falta cargar plata.
  #
  # Más adelante se acredita saldo desde acá; por ahora es lectura.
  class CuentaCorrienteController < BaseController
    def show
      cc = ficha&.cuenta_corriente
      return render json: { data: { tiene: false } } if cc.nil?

      render json: {
        data: {
          tiene:              true,
          # Arranca en 0 y se va a negativo a medida que usa el crédito: lo que ve el paciente es
          # "tenés saldo" o "debés", no un número con signo que hay que interpretar.
          saldo:              cc.saldo_disponible.to_f,
          debe:               [-cc.saldo_disponible.to_f, 0].max,
          limite:             cc.limite_credito.to_f,
          tiene_credito:      cc.tiene_credito?,
          porcentaje_usado:   cc.porcentaje_consumido,
          movimientos:        cc.movimientos.recientes.limit(30).map { |m| movimiento_json(m) },
        },
      }
    end

    private

    # Siempre la del paciente logueado: no hay un `:id` en la URL que se pueda cambiar por otro.
    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    # Sin `created_by`: quién cargó el movimiento es del funcionamiento interno de la
    # organización, no del paciente.
    def movimiento_json(mov)
      {
        id:     mov.id,
        fecha:  mov.created_at,
        tipo:   mov.tipo,
        label:  mov.tipo_label,
        monto:  mov.monto.to_f,
        saldo:  mov.saldo_nuevo.to_f,
        suma:   mov.es_carga?,
      }
    end
  end
end
