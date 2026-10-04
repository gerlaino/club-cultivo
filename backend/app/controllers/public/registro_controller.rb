# El autoregistro de uso personal (/registro en la SPA). Ver `Registros::CrearPersonal`.
#
#   GET  /api/public/registro            → lo que la pantalla muestra y no decide: días de prueba,
#                                          versión de los términos
#   POST /api/public/registro            → crea la cuenta; la SPA después entra con el login normal
#   POST /api/public/registro/confirmar  → el link del mail (token); también despausa
#   POST /api/public/registro/reenviar   → vuelve a mandar el link (por mail, sin sesión: tiene que
#                                          andar con la cuenta pausada)
#
# Frenos: rack-attack (registro y reenvío por IP) y un campo trampa para robots (`sitio`), que
# una persona no ve y un bot llena.
module Public
  class RegistroController < BaseController
    self.public_tenant_mode = :token

    def show
      render json: { dias_prueba: Registros::CrearPersonal::DIAS_PRUEBA,
                     terminos_version: Legal::TERMINOS_VERSION,
                     password_minimo: Registros::CrearPersonal::PASSWORD_MINIMO }
    end

    def create
      # El robot que completó el campo invisible recibe un «listo» y no se crea nada.
      return head :created if params[:sitio].present?

      registro = Registros::CrearPersonal.new(
        nombre: params[:nombre], email: params[:email], password: params[:password],
        acepta_terminos: params[:acepta_terminos],
        ip: request.remote_ip, user_agent: request.user_agent,
      ).call
      EnviarConfirmacionRegistroJob.perform_later(registro.id)
      render json: { ok: true, email: registro.email }, status: :created
    rescue Registros::CrearPersonal::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def confirmar
      registro = RegistroPersonal.por_token(params[:token])
      return render json: { error: 'El link no es válido o ya se usó. Pedí uno nuevo desde la app.' }, status: :not_found unless registro

      registro.confirmar!
      render json: { ok: true, email: registro.email }
    end

    # Siempre la misma respuesta, exista o no la cuenta: no sirve para averiguar quién está registrado.
    def reenviar
      email = params[:email].to_s.strip.downcase
      registro = RegistroPersonal.sin_confirmar.find_by(email: email) if email.present?
      EnviarConfirmacionRegistroJob.perform_later(registro.id) if registro
      render json: { ok: true }
    end
  end
end
