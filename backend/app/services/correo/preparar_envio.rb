module Correo
  # Arma la lista de destinatarios de un envío masivo y la deja lista para el job.
  #
  # Existe porque el texto NO es el mismo para todos: si la plantilla dice "Hola {{nombre}}",
  # cada paciente tiene que recibir el suyo. Resolverlo acá —una vez, contra el paciente real—
  # y guardarlo por destinatario evita que el job tenga que volver a la base por cada mail.
  class PrepararEnvio
    Resultado = Struct.new(:ok, :envio, :error, :salteados, keyword_init: true) do
      def ok? = ok
    end

    def self.call(...) = new(...).call

    def initialize(club:, usuario:, asunto:, cuerpo:, destino:, plantilla: nil,
                   paciente_ids: [], emails: [])
      @club = club
      @usuario = usuario
      @asunto = asunto.to_s.strip
      @cuerpo = cuerpo.to_s.strip
      @destino = destino
      @plantilla = plantilla
      @paciente_ids = Array(paciente_ids).map(&:to_i)
      @emails = Array(emails).map { |e| e.to_s.strip.downcase }.reject(&:blank?).uniq
    end

    def call
      return fallo('La organización no tiene su casilla de correo conectada.') unless @club.smtp_configured?
      return fallo('El asunto y el cuerpo son obligatorios.') if @asunto.blank? || @cuerpo.blank?

      destinatarios, salteados = @destino == 'pacientes' ? de_pacientes : de_emails
      return fallo('No hay ningún destinatario con dirección de correo.', salteados) if destinatarios.empty?

      # El tope se chequea ANTES de crear el envío: arrancar y cortar a la mitad deja a media
      # nómina avisada y a la otra media no, sin forma de saber dónde quedó.
      restante = CupoDiario.restante(@club)
      if destinatarios.size > restante
        return fallo("Hoy te quedan #{restante} envíos de #{CupoDiario::LIMITE}. " \
                     "Este envío son #{destinatarios.size}: mandalo en partes o esperá a mañana.", salteados)
      end

      envio = EnvioMasivo.create!(
        club: @club, user: @usuario, plantilla_mail: @plantilla,
        asunto: @asunto, cuerpo: @cuerpo, destino: @destino,
        destinatarios: destinatarios, total: destinatarios.size
      )
      EnvioMasivoJob.perform_later(envio.id)

      Resultado.new(ok: true, envio: envio, salteados: salteados)
    end

    private

    # Quien no tiene email queda AFUERA y se informa por nombre: un contador de "3 salteados" no
    # le sirve a nadie; saber a quién hay que llamar por teléfono, sí.
    def de_pacientes
      pacientes = @club.pacientes.where(id: @paciente_ids)
      con_mail, sin_mail = pacientes.partition { |p| p.email.present? }

      lista = con_mail.map do |p|
        {
          'email'       => p.email,
          'paciente_id' => p.id,
          'nombre'      => p.nombre_completo,
          'asunto'      => PlantillaMail.render(@asunto, paciente: p, club: @club),
          'cuerpo'      => PlantillaMail.render(@cuerpo, paciente: p, club: @club),
        }
      end
      [lista, sin_mail.map(&:nombre_completo)]
    end

    def de_emails
      validos, invalidos = @emails.partition { |e| e.match?(URI::MailTo::EMAIL_REGEXP) }
      [validos.map { |e| { 'email' => e } }, invalidos]
    end

    def fallo(msg, salteados = []) = Resultado.new(ok: false, error: msg, salteados: salteados)
  end
end
