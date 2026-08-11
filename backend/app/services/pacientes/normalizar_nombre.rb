module Pacientes
  # Normaliza la capitalización de un nombre o apellido.
  #
  # Las cargas masivas traen lo que había en el sistema de origen, y ahí conviven tres estilos:
  # el listado de REPROCANN devuelve el apellido en MAYÚSCULAS ("Martin Ezequiel BLANCO"), las
  # altas a mano vienen en minúsculas ("ana perez") y las prolijas ya vienen bien. Mezclados en
  # la misma lista se lee como si el padrón estuviera sucio.
  #
  # Lo que NO hace, a propósito: **no corrige ortografía ni agrega acentos**. "Perez" no se
  # vuelve "Pérez". Es el nombre de una persona real y equivocarse es peor que dejarlo como
  # está — hay Perez sin tilde.
  class NormalizarNombre
    # Partículas que van en minúscula en el medio: "Juana de Arco", "Franco della Valle". Al
    # principio sí llevan mayúscula ("De Luca Martínez"), que es como se escribe un apellido
    # argentino que arranca con partícula.
    PARTICULAS = %w[de del la las los y e da das do dos di della van von der ten].freeze

    def self.call(texto)
      return texto if texto.blank?

      # `squeeze(' ')` de paso limpia los espacios dobles que dejan los copiados.
      texto.to_s.strip.squeeze(' ').split(' ').each_with_index.map do |palabra, i|
        palabra(palabra, primera: i.zero?)
      end.join(' ')
    end

    def self.palabra(texto, primera:)
      baja = texto.downcase

      return baja if !primera && PARTICULAS.include?(baja)
      # O'Brien, D'Angelo: la letra de después del apóstrofo también va en mayúscula.
      return "#{baja[0].upcase}'#{baja[2..].capitalize}" if baja.match?(/\A[dol]'\p{L}/)
      # Mc/Mac llevan mayúscula ADENTRO; sin esto quedaría "Mcdonald".
      return "Mc#{baja[2..].capitalize}"  if baja.match?(/\Amc\p{L}/)
      return "Mac#{baja[3..].capitalize}" if baja.match?(/\Amac\p{L}{2,}/)
      # El guion separa dos apellidos: "García-López", no "García-lópez".
      return baja.split('-').map(&:capitalize).join('-') if baja.include?('-')

      baja.capitalize
    end
    private_class_method :palabra
  end
end
