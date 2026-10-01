# Una planta de un riego por planta: cuánto recibió, en litros y —si se cargó así— en pulsos.
class RiegoPlantaSerializer
  def self.call(rp)
    {
      plant_id:         rp.plant_id,
      codigo:           rp.plant && (rp.plant.nombre.presence || rp.plant.codigo_qr),
      volumen_l:        rp.volumen_l.to_f,
      pulsos:           rp.pulsos&.to_f,
      litros_por_pulso: rp.litros_por_pulso&.to_f,
      texto:            texto(rp),
    }
  end

  # «2 pulsos (0,5 L)» o «0,5 L».
  def self.texto(rp)
    litros = "#{Lotes::Nutricion.num(rp.volumen_l)} L"
    return litros if rp.pulsos.nil?
    p = Lotes::Nutricion.num(rp.pulsos)
    "#{p} #{rp.pulsos == 1 ? 'pulso' : 'pulsos'} (#{litros})"
  end

  # El riego en una línea, para el historial del lote: «en 5 plantas: 3 con 1 pulso (0,25 L),
  # 2 con 2 pulsos (0,5 L)». Agrupa las plantas que recibieron lo mismo.
  def self.resumen(riego_plantas)
    rps = riego_plantas.to_a
    return nil if rps.empty?
    grupos = rps.group_by { |rp| texto(rp) }.map { |t, g| "#{g.size} con #{t}" }
    "en #{rps.size} #{rps.size == 1 ? 'planta' : 'plantas'}: #{grupos.join(', ')}"
  end
end
