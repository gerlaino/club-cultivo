# Un mensaje del chat del portal, igual para los dos lados (paciente y organización): el texto, de
# quién, cuándo, la dispensa que cita y el adjunto. Lista blanca campo por campo.
module MensajePacienteSerializer
  module_function

  def serialize(m, url_helper:)
    {
      id:      m.id,
      autor:   m.autor,
      # Del lado de la organización se firma con el nombre de pila de quien contestó.
      quien:   m.autor == 'organizacion' ? m.user&.first_name : nil,
      texto:   m.texto,
      at:      m.created_at,
      dispensa: m.dispensacion && {
        id: m.dispensacion.id, numero: format('%04d', m.dispensacion.id), fecha: m.dispensacion.fecha_dispensacion,
        resumen: m.dispensacion.items.map { |i| [i.genetica_nombre.presence || i.stock&.genetica&.nombre, "#{i.cantidad.to_f.to_s.sub(/\.0\z/, '')} #{i.stock&.unidad || 'g'}"].compact.join(' ') }.join(' + '),
      },
      adjunto: m.adjunto.attached? ? {
        url: url_helper.call(m.adjunto), nombre: m.adjunto.filename.to_s, tipo: m.adjunto.content_type,
        es_imagen: m.adjunto.content_type.to_s.start_with?('image/'),
      } : nil,
    }
  end

  def conversacion(c)
    return { leida_org_at: nil, leida_paciente_at: nil, resuelta_at: nil } if c.nil?

    { leida_org_at: c.leida_org_at, leida_paciente_at: c.leida_paciente_at, resuelta_at: c.resuelta_at }
  end
end
