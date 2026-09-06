# LA CAJA QUE QUEDÓ ABIERTA.
#
# Se cierra a la noche, y a la noche el admin no está: si alguien se fue sin cerrar, nadie se
# entera hasta la mañana siguiente —cuando el que abre no puede arrancar, porque ya hay una caja
# abierta— y para entonces el arqueo de esa jornada ya no lo puede hacer nadie: la mercadería
# pasó la noche sin contar y lo cobrado en efectivo quedó sin cuadrar contra nada.
#
# El admin elige la hora (Configuración → Alertas), general para la organización y por sede
# cuando alguna cierra distinto. Ver `Club#hora_limite_cierre_mostrador`.
#
# NO ACUSA A NADIE: dice qué caja quedó abierta, desde cuándo y quién la abrió, que es lo que
# hace falta para levantar el teléfono.
class CierreMostradorPendienteJob < ApplicationJob
  queue_as :default

  def perform
    cada_club_con(:produccion_dispensa) { |club| revisar(club) }
  end

  private

  def revisar(club)
    club.mostradores.activos.includes(:sede).each do |mostrador|
      limite = limite_de(club, mostrador)
      next if limite.nil?

      turno = mostrador.turno_abierto
      next if turno.nil?
      # Una caja abierta DESPUÉS de la hora no es una caja olvidada: es el turno que empieza.
      next if turno.abierto_at.present? && turno.abierto_at >= limite
      next if Time.zone.now < limite
      next if ya_avisado?(club, mostrador)

      avisar!(club, mostrador, turno, limite)
    end
  end

  # La hora de hoy: con un límite pasada la medianoche (una organización que cierra a la 01:00),
  # el aviso sale a esa hora del día en curso y la caja que se abrió ayer a la mañana entra igual,
  # porque su apertura es anterior.
  def limite_de(club, mostrador)
    hm = club.hora_limite_cierre_mostrador(mostrador.sede_id)
    return nil if hm.nil?

    Time.zone.now.change(hour: hm.first, min: hm.last)
  end

  def avisar!(club, mostrador, turno, limite)
    sede = mostrador.sede&.nombre
    texto = "La caja de #{sede} sigue abierta a las #{limite.strftime('%H:%M')}. " \
            "La abrió #{turno.abierto_por&.nombre_completo || 'alguien'} a las " \
            "#{turno.abierto_at&.strftime('%H:%M')}."

    AlertaInterna.create!(
      club: club, tipo: 'cierre_mostrador_pendiente', mensaje: texto, severidad: 'warning',
      destinada_a_role: 'admin',
      contexto: { mostrador_id: mostrador.id, sede_id: mostrador.sede_id, sede_nombre: sede,
                  turno_id: turno.id, abierto_at: turno.abierto_at }
    )

    # A esa hora el admin no está mirando la app: la campana sola se lee al día siguiente, que es
    # exactamente lo que esta alerta existe para evitar.
    PushNotificationService.notify_admins_async(
      club, title: 'Caja sin cerrar', body: texto, url: "/mostrador?sede=#{mostrador.sede_id}"
    )
  end

  # Uno por mostrador y por día. Cada quince minutos es cómo se aprende a ignorarlo.
  def ya_avisado?(club, mostrador)
    AlertaInterna.unscoped
                 .where(club_id: club.id, tipo: 'cierre_mostrador_pendiente')
                 .where("contexto->>'mostrador_id' = ?", mostrador.id.to_s)
                 .where('created_at >= ?', Time.zone.now.beginning_of_day)
                 .exists?
  end
end
