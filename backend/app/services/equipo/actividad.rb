# QUÉ HIZO HOY CADA PERSONA DEL EQUIPO Y QUÉ TIENE PENDIENTE (12-oct-2026).
#
# Lo leen dos pantallas con el mismo texto: el panel de conducción («Equipo hoy», sólo quien tuvo
# actividad o tiene algo pendiente) y la lista de Equipo (todos, con sus horas del mes y su último
# acceso). Una sola cuenta, para que «3 dispensas» no diga otra cosa en la otra pantalla.
module Equipo
  class Actividad
    # `dispensas`: todas las dispensas de la organización (también las anuladas: una entrega se
    # cuenta por su envío). El panel le pasa las suyas.
    def initialize(club:, hoy: Time.zone.today, dispensas: nil)
      @club = club
      @hoy  = hoy
      @dispensas = dispensas || Dispensacion.where(paciente_id: Paciente.unscoped.where(club_id: club.id).select(:id))
    end

    # { user_id => { actividad: [String], alertas: [String] } } de quien hizo algo o debe algo.
    def por_usuario
      @por_usuario ||= begin
        ids = (disp.keys + entregas.keys + en_mano.keys + hechas.keys + vencidas.keys + turnos.keys + sin_ver.keys + cajas.keys).compact.uniq
        ids.index_with { |uid| { actividad: actividad(uid), alertas: alertas(uid) } }
      end
    end

    # Horas cargadas en el mes (enviadas y confirmadas), por persona.
    def horas_mes
      @horas_mes ||= JornadaLaboral.where(club_id: @club.id).del_mes(@hoy.year, @hoy.month)
                                   .group_by(&:user_id).transform_values { |js| js.sum(&:horas).round(1) }
    end

    private

    def dia = @hoy.beginning_of_day..@hoy.end_of_day

    def disp     = @disp ||= @dispensas.no_canceladas.where(fecha_dispensacion: @hoy).group(:user_id).count
    def entregas = @entregas ||= @dispensas.where(estado_envio: 'entregado', updated_at: dia).group(:delivery_id).count
    def en_mano  = @en_mano ||= Cobro.efectivo_en_transito.where(club_id: @club.id, rendicion_caja_id: nil).group(:created_by_id).sum(:monto_ars)
    def hechas   = @hechas ||= Tarea.del_club(@club.id).completadas.where(fecha_completada: dia).group(:asignada_a_id).count
    def vencidas = @vencidas ||= Tarea.del_club(@club.id).vencidas.group(:asignada_a_id).count
    def turnos   = @turnos ||= Turno.where(club_id: @club.id, fecha_hora: dia).where.not(estado: 'cancelado').group(:medico_id).count
    def cajas    = @cajas ||= CajaTurno.activas.where(club_id: @club.id).pluck(:abierta_por_id, :abierta_at).to_h

    def sin_ver
      @sin_ver ||= Turno.where(club_id: @club.id, visto_at: nil).where('fecha_hora >= ?', Time.current)
                        .where.not(estado: 'cancelado').group(:medico_id).count
    end

    def actividad(uid)
      out = []
      out << contar(disp[uid], 'dispensa') if disp[uid].to_i.positive?
      if (abierta = cajas[uid])
        out << "caja abierta desde #{abierta.in_time_zone.to_date == @hoy ? "las #{abierta.in_time_zone.strftime('%H:%M')}" : "el #{abierta.in_time_zone.strftime('%d/%m')}"}"
      end
      out << contar(entregas[uid], 'entrega') if entregas[uid].to_i.positive?
      out << "#{contar(hechas[uid], 'tarea')} completada#{hechas[uid] == 1 ? '' : 's'}" if hechas[uid].to_i.positive?
      out << contar(turnos[uid], 'turno') if turnos[uid].to_i.positive?
      out
    end

    def alertas(uid)
      out = []
      out << "rendición pendiente de $ #{ActiveSupport::NumberHelper.number_to_delimited(en_mano[uid].to_f.round, delimiter: '.')}" if en_mano[uid].to_d.positive?
      out << "#{contar(vencidas[uid], 'tarea')} vencida#{vencidas[uid] == 1 ? '' : 's'}" if vencidas[uid].to_i.positive?
      out << "#{sin_ver[uid]} asignaci#{sin_ver[uid] == 1 ? 'ón' : 'ones'} sin confirmar" if sin_ver[uid].to_i.positive?
      out
    end

    def contar(n, palabra) = "#{n} #{palabra}#{n == 1 ? '' : 's'}"
  end
end
