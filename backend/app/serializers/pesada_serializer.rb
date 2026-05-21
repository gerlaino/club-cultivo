class PesadaSerializer
  def self.serialize(p)
    {
      id:               p.id,
      fase_origen:      p.fase_origen,
      fase_destino:     p.fase_destino,
      peso_humedo_g:    p.peso_humedo_g&.to_f,
      peso_seco_g:      p.peso_seco_g&.to_f,
      peso_curado_g:    p.peso_curado_g&.to_f,
      manicurado:           p.manicurado,
      plantas_manicuradas:  p.plantas_manicuradas,
      notas:                p.notas,
      registrado_por:       p.registrado_por&.first_name,
      registrado_at:    p.registrado_at,
      merma_porcentual: p.merma_porcentual,
      aprobada_at:      p.aprobada_at,
      aprobada_por:     p.aprobada_por&.first_name,
      rechazada_at:     p.rechazada_at,
      motivo_rechazo:   p.motivo_rechazo,
      pesadas_plantas:  p.pesadas_plantas.map { |pp|
        { plant_id: pp.plant_id, nombre: pp.plant.nombre,
          peso_humedo_g: pp.peso_humedo_g&.to_f, peso_seco_g: pp.peso_seco_g&.to_f }
      },
    }
  end
end
