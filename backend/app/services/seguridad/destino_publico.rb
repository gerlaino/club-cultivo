require 'ipaddr'
require 'resolv'

module Seguridad
  # ¿A DÓNDE SE CONECTA EL SERVIDOR CUANDO EL DESTINO LO ESCRIBE UN USUARIO?
  #
  # Los webhooks salientes y el SMTP propio de una organización hacen que el servidor abra una
  # conexión al host que cargó un admin. Y admin es cualquiera: el autoregistro de autocultivo
  # crea la cuenta con ese rol. Sin este chequeo, alguien se registra y apunta un webhook a
  # `http://<servicio-interno>:6379/` para recorrer la red privada de Render y leer lo que
  # contesta (barrido de seguridad, 13-oct-2026).
  #
  # La regla: el host tiene que resolver SÓLO a direcciones públicas. Se devuelve la IP ya
  # validada para conectarse a ESA y no volver a resolver: si se resolviera de nuevo al conectar,
  # un DNS que cambia de respuesta entre la validación y la conexión pasaría el chequeo.
  class DestinoPublico
    class Rechazado < StandardError; end

    PRIVADAS = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
      192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32
      ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 ::ffff:0:0/96 64:ff9b::/96
    ].map { |r| IPAddr.new(r) }.freeze

    # Devuelve la IP (String) a la que conectarse, o levanta `Rechazado` con un motivo que se
    # puede mostrar: nunca dice qué había del otro lado.
    def self.ip!(host)
      host = host.to_s.strip.delete_prefix('[').delete_suffix(']')
      raise Rechazado, 'Falta el servidor.' if host.empty?

      ips = direcciones(host)
      raise Rechazado, 'No se encontró ese servidor.' if ips.empty?
      raise Rechazado, 'Ese servidor no es una dirección pública.' if ips.any? { |ip| privada?(ip) }

      ips.first
    end

    def self.publico?(host)
      ip!(host)
      true
    rescue Rechazado
      false
    end

    def self.privada?(ip)
      dir = IPAddr.new(ip)
      PRIVADAS.any? { |red| red.family == dir.family && red.include?(dir) }
    rescue IPAddr::InvalidAddressError
      true
    end

    # Separado para que los specs no dependan del DNS de la máquina que los corre.
    def self.direcciones(host)
      return [host] if (IPAddr.new(host) rescue nil)

      Resolv.getaddresses(host)
    end
  end
end
