module Ambiente
  class VpdCalculator
    # Returns VPD in kPa given temperature (°C) and relative humidity (%).
    # Uses Tetens formula for saturation vapor pressure.
    def self.call(temperatura:, humedad:)
      t   = temperatura.to_f
      hr  = humedad.to_f
      svp = 0.6108 * Math.exp(17.27 * t / (t + 237.3))
      (svp * (1.0 - hr / 100.0)).round(3)
    end
  end
end
