# Le manda a un paciente el link para entrar a su portal. Es la ÚNICA forma de darle acceso: al
# admitirlo, desde la ficha («Invitar al portal» / «Mandar un link nuevo») y en el «me olvidé la
# clave» (con motivo `recuperacion`).
#
# Reemplaza a la contraseña que el admin veía una vez y tenía que dictar (27-oct-2026): ahora nadie
# de la organización conoce la clave del paciente. El link se puede mandar por mail (si la ficha
# tiene uno) y siempre se devuelve para compartirlo por WhatsApp desde la ficha.
module PortalAcceso
  class Invitar
    Resultado = Struct.new(:link, :expira_at, :mail_enviado, :texto, :error, keyword_init: true) do
      def ok? = error.nil?
    end

    def self.call(paciente, creado_por: nil, motivo: 'invitacion', mandar_mail: true)
      new(paciente, creado_por:, motivo:, mandar_mail:).call
    end

    def initialize(paciente, creado_por:, motivo:, mandar_mail:)
      @paciente    = paciente
      @creado_por  = creado_por
      @motivo      = motivo
      @mandar_mail = mandar_mail
    end

    def call
      club = @paciente.club
      return Resultado.new(error: 'Tu organización no tiene el portal de pacientes contratado.') unless club.feature?(:vista_paciente)
      return Resultado.new(error: 'El paciente está dado de baja.') unless @paciente.es_paciente?
      return Resultado.new(error: 'El paciente todavía no está aprobado.') unless @paciente.aprobado?

      # La cuenta se crea acá si no la tiene (los pacientes de antes del portal). Su clave inicial
      # no se le muestra a nadie: la elige el paciente al abrir el link.
      cuenta = Pacientes::Acceso.crear!(@paciente)
      return Resultado.new(error: cuenta.error) unless cuenta.ok?

      emitido = AccesoPortal.emitir!(@paciente, motivo: @motivo, creado_por: @creado_por)
      link    = "#{App.base_url}/portal/entrar/#{emitido.token}"
      Resultado.new(link: link, expira_at: emitido.acceso.expira_at, mail_enviado: mandar(emitido),
                    texto: texto_para_compartir(link, club))
    end

    private

    def mandar(emitido)
      return false unless @mandar_mail && @paciente.email.present?

      AccesoMailer.portal_link(acceso: emitido.acceso, token: emitido.token).deliver_later
      true
    rescue StandardError => e
      # Que el mail falle no deja al paciente sin link: está en la ficha para mandarlo por WhatsApp.
      Rails.logger.warn("[portal] no se pudo mandar el link al paciente #{@paciente.id}: #{e.class} #{e.message}")
      false
    end

    # El mensaje que la ficha pega en WhatsApp. Sin datos de salud: sólo el nombre y el link.
    def texto_para_compartir(link, club)
      nombre = @paciente.nombre.to_s.split.first
      if @motivo == 'invitacion'
        "Hola #{nombre}! Te invitamos a tu portal de paciente de #{club.name}. Entrá acá, poné tu DNI y elegí tu clave: #{link} (el link sirve una vez y vence en 72 horas)."
      else
        "Hola #{nombre}! Para elegir una clave nueva en tu portal de #{club.name}, entrá acá: #{link}"
      end
    end
  end
end
