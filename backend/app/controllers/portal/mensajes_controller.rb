module Portal
  # El chat del paciente con su organización, del lado del paciente (27-oct-2026).
  #
  #   GET  /portal/mensajes          su conversación (los últimos 200) y hasta dónde leyó cada lado
  #   POST /portal/mensajes          mandar (texto y/o adjunto; puede citar una dispensa suya)
  #   POST /portal/mensajes/leidos   «ya lo vi»: lo llama el chat abierto cuando llega una respuesta
  #
  # Siempre SU conversación: sale de su ficha, no hay un id en la URL.
  class MensajesController < BaseController
    LIMITE = 200

    def index
      return render json: { data: [], conversacion: MensajePacienteSerializer.conversacion(nil), sin_leer: 0 } if ficha.nil?

      conv = ficha.conversacion_portal
      mensajes = conv ? conv.mensajes.includes(:user, adjunto_attachment: :blob, dispensacion: { items: { stock: :genetica } }).last(LIMITE) : []
      render json: {
        data:         mensajes.map { |m| MensajePacienteSerializer.serialize(m, url_helper: method(:url_for)) },
        conversacion: MensajePacienteSerializer.conversacion(conv),
        sin_leer:     conv ? conv.sin_leer_para_paciente : 0,
      }
    end

    def create
      return render json: { error: 'Tu cuenta no tiene ficha de paciente.' }, status: :unprocessable_entity if ficha.nil?

      conv = ConversacionPaciente.de!(ficha)
      mensaje = conv.mensajes.new(club: current_club, user: current_user, autor: 'paciente',
                                  texto: params[:texto].to_s.strip.presence,
                                  dispensacion_id: params[:dispensacion_id].presence)
      mensaje.adjunto.attach(params[:adjunto]) if params[:adjunto].present?

      if mensaje.save
        render json: { data: MensajePacienteSerializer.serialize(mensaje, url_helper: method(:url_for)) }, status: :created
      else
        render json: { error: mensaje.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def leidos
      conv = ficha&.conversacion_portal
      if conv && conv.sin_leer_para_paciente.positive?
        conv.update_columns(leida_paciente_at: Time.current)
        conv.avisar!(:leido)
      end
      head :no_content
    end

    private

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end
  end
end
