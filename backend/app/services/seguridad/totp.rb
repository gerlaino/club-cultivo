require 'openssl'
require 'securerandom'

module Seguridad
  # El código de seis números que cambia cada 30 segundos (TOTP, RFC 6238), el mismo que muestran
  # Google Authenticator, 1Password o Authy (29-oct-2026, seguridad tanda 2).
  #
  # Sin gema: son veinte líneas sobre el HMAC de OpenSSL y así no sumamos una dependencia a algo
  # que custodia la entrada. Los vectores de prueba del RFC están en `spec/services/seguridad/totp_spec.rb`.
  module Totp
    PASO     = 30 # segundos que dura un código
    DIGITOS  = 6
    TOLERANCIA = 1 # acepta el código anterior y el siguiente: el reloj del teléfono puede estar corrido
    EMISOR   = 'Cultivo Espacial'.freeze
    BASE32   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'.freeze

    module_function

    # La salida de emergencia: `SEGUNDO_PASO_SUPER_ADMIN=apagado` en Render deja entrar sin código.
    def suspendido?
      ENV['SEGUNDO_PASO_SUPER_ADMIN'] == 'apagado'
    end

    # 20 bytes al azar, en base32 (lo que se escribe a mano si el QR no se puede escanear).
    def generar_secreto
      bits = SecureRandom.random_bytes(20).unpack1('B*')
      bits.scan(/.{5}/).map { |b| BASE32[b.to_i(2)] }.join
    end

    def paso_de(tiempo = Time.current)
      tiempo.to_i / PASO
    end

    def codigo(secreto, paso)
      hmac   = OpenSSL::HMAC.digest('SHA1', decodificar(secreto), [paso].pack('Q>'))
      offset = hmac.bytes.last & 0x0f
      numero = (hmac[offset, 4].unpack1('N') & 0x7fffffff) % (10**DIGITOS)
      numero.to_s.rjust(DIGITOS, '0')
    end

    # Devuelve el paso en que el código vale, o nil. Uno ya usado (`ultimo_paso`) o anterior no
    # vale: quien lo vio por encima del hombro no puede volver a usarlo.
    def verificar(secreto, ingresado, ultimo_paso: nil, tiempo: Time.current)
      ingresado = ingresado.to_s.gsub(/\s/, '')
      return nil if secreto.blank? || ingresado !~ /\A\d{#{DIGITOS}}\z/

      ahora = paso_de(tiempo)
      ((ahora - TOLERANCIA)..(ahora + TOLERANCIA)).find do |paso|
        next false if ultimo_paso && paso <= ultimo_paso

        ActiveSupport::SecurityUtils.secure_compare(codigo(secreto, paso), ingresado)
      end
    end

    # Lo que va en el QR: la app lo lee y queda anotada la cuenta.
    def uri(secreto, cuenta)
      etiqueta = ERB::Util.url_encode("#{EMISOR}:#{cuenta}")
      "otpauth://totp/#{etiqueta}?secret=#{secreto}&issuer=#{ERB::Util.url_encode(EMISOR)}&digits=#{DIGITOS}&period=#{PASO}"
    end

    def decodificar(secreto)
      bits = secreto.to_s.upcase.delete('=').chars.map { |c| BASE32.index(c).to_s(2).rjust(5, '0') }.join
      [bits[0, bits.length - (bits.length % 8)]].pack('B*')
    end
  end
end
