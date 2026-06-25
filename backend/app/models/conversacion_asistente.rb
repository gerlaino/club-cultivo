class ConversacionAsistente < ApplicationRecord
  self.table_name = 'conversaciones_asistente'

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :user

  MAX_TURNOS = 8

  def self.de_hoy(user)
    find_or_create_by(user: user, club: user.club, fecha: Date.current)
  end

  def agregar_intercambio(texto_usuario, resumen_asistente)
    nuevos = [
      { rol: 'cultivador', contenido: texto_usuario.truncate(200),     hora: Time.current.strftime('%H:%M') },
      { rol: 'asistente',  contenido: resumen_asistente.truncate(150), hora: Time.current.strftime('%H:%M') },
    ]
    update!(mensajes: (mensajes + nuevos).last(MAX_TURNOS * 2))
  end

  def historial_para_prompt
    return '' if mensajes.blank?
    lines = mensajes.map do |m|
      prefix = m['rol'] == 'cultivador' ? 'Cultivador' : 'Asistente'
      "[#{m['hora']}] #{prefix}: #{m['contenido']}"
    end
    "\n═══ HISTORIAL DE ESTA JORNADA ═══\n" \
    "#{lines.join("\n")}\n" \
    "(Usá este historial para resolver referencias como 'esa planta', 'ese lote', 'lo de antes')\n"
  end
end
