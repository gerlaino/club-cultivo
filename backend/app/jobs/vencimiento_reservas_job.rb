# Mantenimiento diario de reservas de dispensa:
#   1. Vence las reservas pendientes cuya fecha de entrega estimada pasó hace más de
#      Reserva::DIAS_VENCIMIENTO días. Al marcarlas 'vencida' dejan de bloquear stock
#      (Stock#gramos_reservados sólo suma pendientes).
#   2. Avisa al admin de las reservas cuya entrega es HOY y siguen pendientes, para que
#      se despachen/retiren.
class VencimientoReservasJob < ApplicationJob
  queue_as :default

  def perform
    cada_club_con(:produccion_dispensa) { |club| procesar_club(club) }
  end

  private

  def procesar_club(club)
    vencer_reservas(club)
    avisar_entregas_de_hoy(club)
  rescue StandardError => e
    Rails.logger.warn "VencimientoReservasJob: club #{club.id} falló: #{e.message}"
  end

  def vencer_reservas(club)
    club.reservas.a_vencer.find_each do |reserva|
      reserva.marcar_vencida!
      AlertaInterna.create!(
        club:             club,
        tipo:             'reserva_vencida',
        mensaje:          "Reserva ##{reserva.id} de #{reserva.paciente.nombre_completo} venció (entrega estimada #{reserva.fecha_entrega_estimada}). Se liberó el stock apartado.",
        severidad:        'warning',
        destinada_a_role: 'admin',
        contexto:         { reserva_id: reserva.id, paciente_id: reserva.paciente_id, accion: 'reserva_vencida' }
      )
    end
  end

  def avisar_entregas_de_hoy(club)
    club.reservas.pendientes.where(fecha_entrega_estimada: Date.current).find_each do |reserva|
      next if alerta_de_hoy?(club, reserva)

      AlertaInterna.create!(
        club:             club,
        tipo:             'reserva_por_entregar',
        mensaje:          "Reserva ##{reserva.id} de #{reserva.paciente.nombre_completo} se entrega hoy — #{reserva.cantidad.to_f}#{reserva.stock&.unidad || 'g'}.",
        severidad:        'info',
        destinada_a_role: 'admin',
        contexto:         { reserva_id: reserva.id, paciente_id: reserva.paciente_id, accion: 'reserva_por_entregar' }
      )
    end
  end

  def alerta_de_hoy?(club, reserva)
    AlertaInterna.where(club_id: club.id, tipo: 'reserva_por_entregar')
                 .where("contexto ->> 'reserva_id' = ?", reserva.id.to_s)
                 .where("created_at >= ?", Date.current.beginning_of_day)
                 .exists?
  end
end
