module Ambiente
  # VPD en kPa. Por defecto calcula el VPD DE HOJA, que es el que gobierna la transpiración
  # de la planta y con el que se decide un riego — no el del aire.
  #
  # La diferencia no es un detalle: la hoja transpira y se enfría respecto del aire (2-3 °C
  # bajo LED, menos bajo HPS porque el infrarrojo la calienta), y ese par de grados cambia el
  # VPD lo suficiente como para mover una decisión. Con aire a 26 °C y 60 % de humedad, el VPD
  # de aire da 1.35 kPa y el de hoja 1.19: uno dice "está bien" y el otro "regá".
  #
  # Antes se calculaba el de aire, y por eso NO coincidía con lo que muestra la app de un
  # sensor Pulse (que informa el de hoja). Los dos números eran correctos; medían cosas
  # distintas.
  class VpdCalculator
    # Cuánto más fría está la hoja que el aire, si la sala no tiene su propio ajuste.
    OFFSET_HOJA_DEFAULT = -2.0

    # `offset_hoja: 0` devuelve el VPD del AIRE (sin corrección), para cuando se lo quiera
    # comparar contra el dato crudo de un equipo.
    def self.call(temperatura:, humedad:, offset_hoja: OFFSET_HOJA_DEFAULT)
      t_aire = temperatura.to_f
      hr     = humedad.to_f
      t_hoja = t_aire + offset_hoja.to_f

      # La humedad de saturación se calcula a la temperatura de la HOJA; la presión de vapor
      # que hay en el aire, a la del AIRE. Ahí está la corrección.
      svp_hoja = svp(t_hoja)
      vp_aire  = svp(t_aire) * (hr / 100.0)

      [(svp_hoja - vp_aire), 0].max.round(3)
    end

    # Presión de vapor saturado (Tetens).
    def self.svp(t)
      0.6108 * Math.exp(17.27 * t / (t + 237.3))
    end
    private_class_method :svp
  end
end
