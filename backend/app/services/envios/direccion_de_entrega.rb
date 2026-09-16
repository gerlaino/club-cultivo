# A dónde va el paquete. UNA regla para las dos puertas —la dispensa con envío y la entrega de
# una reserva—, que hasta sep-2026 la tenían copiada y con un defecto las dos: «domicilio del
# paciente» resolvía a la dirección de ENVÍO si estaba cargada y al domicilio si no, sin decirle
# a nadie cuál. Con las dos cargadas, el que dispensaba apretaba «domicilio» y el paquete salía a
# la otra. Lo encontró el socio de Germán en el primer reparto de Mitocondria ONG.
#
# Ahora la pantalla dice cuál eligió (`direccion_origen`: `domicilio` · `envio` · `otra`) y acá
# se copia ESA como snapshot en la dispensa. `usar_domicilio_paciente` (los clientes viejos, la
# PWA con el bundle cacheado) sigue andando con la regla de antes.
#
# `guardar_como_envio`: lo tipeado en «Otra dirección» queda en la ficha como dirección de envío,
# así la próxima vez aparece para elegir en vez de tipearse de nuevo.
module Envios
  class DireccionDeEntrega
    CAMPOS  = %i[calle altura piso depto barrio ciudad].freeze
    ORIGENES = %w[domicilio envio otra].freeze

    Error = Class.new(StandardError)

    # `params` acepta claves string o symbol: la dispensa las manda anidadas bajo `dispensacion`
    # y la reserva sueltas.
    def self.aplicar(dispensacion, paciente:, params:)
      # `to_unsafe_h`: acá sólo se LEEN seis campos con nombre; no se asigna nada en masa.
      crudo = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      new(dispensacion, paciente, crudo.with_indifferent_access).aplicar
    end

    def initialize(dispensacion, paciente, params)
      @d, @paciente, @params = dispensacion, paciente, params
    end

    def aplicar
      origen = @params[:direccion_origen].to_s
      dir =
        if ORIGENES.include?(origen)
          origen == 'otra' ? tipeada : elegida(origen)
        elsif ActiveModel::Type::Boolean.new.cast(@params[:usar_domicilio_paciente]) || @params[:envio_calle].blank?
          @paciente.direccion_entrega   # regla vieja, para quien todavía no manda `direccion_origen`
        else
          # Cliente viejo con dirección tipeada: se acepta como siempre (con calle alcanza; el
          # modelo valida lo suyo). Exigirle ciudad ahora rompería la PWA que todavía no actualizó.
          tipeada(estricta: false)
        end

      CAMPOS.each { |c| @d.public_send("envio_#{c}=", dir[c]) }
      @d.contacto_nombre   = @paciente.nombre_completo if @d.contacto_nombre.blank?
      @d.contacto_telefono = @paciente.telefono        if @d.contacto_telefono.blank?

      guardar_como_envio!(dir) if origen == 'otra' && ActiveModel::Type::Boolean.new.cast(@params[:guardar_como_envio])
      @d
    end

    private

    def elegida(origen)
      @paciente.direccion(origen) or
        raise Error, "El paciente no tiene cargada su #{Paciente::DIRECCIONES.dig(origen, :label).to_s.downcase}. Cargala en su ficha o elegí «Otra dirección»."
    end

    def tipeada(estricta: true)
      dir = CAMPOS.to_h { |c| [c, @params["envio_#{c}"].presence] }
      if estricta && (dir[:calle].blank? || dir[:altura].blank? || dir[:ciudad].blank?)
        raise Error, 'Completá calle, altura y ciudad de la dirección de entrega.'
      end

      dir
    end

    def guardar_como_envio!(dir)
      @paciente.update!(CAMPOS.to_h { |c| ["envio_#{c}", dir[c]] })
    end
  end
end
