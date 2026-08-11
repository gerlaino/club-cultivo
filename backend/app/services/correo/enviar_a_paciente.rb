module Correo
  # Único lugar donde se le manda un mail a un paciente y se deja el rastro.
  #
  # Existe porque ahora hay tres puertas —el envío manual desde la ficha, el alta hecha por
  # admin/médico y la aprobación de un alta de mostrador— y las tres tienen que registrar igual
  # en `mails_enviados`. Con la lógica copiada, la primera que se toque deja a las otras dos
  # mandando distinto.
  #
  # El envío es SINCRÓNICO a propósito (ver `PacientesController#enviar_mail`): si Gmail rechaza
  # la contraseña de aplicación, quien apretó el botón se entera en el acto en vez de ver un
  # "enviado" falso mientras el error se pierde en el worker. Cuando llegue el envío masivo eso
  # cambia —ahí sí va a cola—, pero para un mail suelto la respuesta inmediata es lo correcto.
  class EnviarAPaciente
    Resultado = Struct.new(:ok, :mail, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(...) = new(...).call

    def initialize(paciente:, usuario:, asunto:, cuerpo:, tipo: 'personalizado', plantilla: nil)
      @paciente  = paciente
      @usuario   = usuario
      @asunto    = asunto.to_s.strip
      @cuerpo    = cuerpo.to_s.strip
      @tipo      = tipo
      @plantilla = plantilla
    end

    def call
      return fallo('El paciente no tiene email registrado.')  if @paciente.email.blank?
      return fallo('El asunto y el cuerpo son obligatorios.') if @asunto.blank? || @cuerpo.blank?
      # Sin casilla conectada, `ApplicationMailer#mail_para_club` hace `return` y NO manda nada,
      # sin levantar error. Sin este chequeo quedaría un registro de un mail que nunca salió.
      return fallo('La organización no tiene su casilla de correo conectada. Configurala en Preferencias → Correo electrónico.') unless club.smtp_configured?

      mail = MailEnviado.new(
        paciente: @paciente, user: @usuario, club: club,
        asunto: @asunto, cuerpo: @cuerpo, tipo: @tipo,
        plantilla_mail: @plantilla,
        email_destino: @paciente.email, enviado_at: Time.current
      )
      return fallo(mail.errors.full_messages.to_sentence) unless mail.save

      begin
        PacienteMailer.mensaje(mail_enviado: mail).deliver_now
      rescue => e
        # Si no salió, el registro no queda: el historial del paciente dice lo que SE ENVIÓ.
        mail.destroy
        return fallo("No se pudo enviar el correo: #{e.message}")
      end

      Resultado.new(ok: true, mail: mail)
    end

    private

    def club = @paciente.club

    def fallo(msg) = Resultado.new(ok: false, error: msg)
  end
end
