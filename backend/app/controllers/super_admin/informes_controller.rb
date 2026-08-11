# Informes de plataforma.
#
# Acá aterrizan los agregados que antes ocupaban el dashboard: cuántas plantas, cuántos lotes y
# cuántos pacientes hay sumando todos los clubes. Para el que abre el panel a la mañana esos
# números no sirven —no es su cultivo—, pero como informe sí: dicen qué tamaño tiene la
# plataforma y son la semilla del benchmarking del sector.
#
# Siempre sobre clubes REALES: una organización demo tiene cientos de dispensaciones inventadas y, de
# cara al benchmarking, mete en el promedio números que nunca existieron.
class SuperAdmin::InformesController < SuperAdmin::BaseController
  # GET /super_admin/informes/plataforma
  def plataforma
    ids = Club.reales.pluck(:id)

    render json: {
      reseña: 'Qué tamaño tiene la plataforma hoy. Cuenta sólo organizaciones reales: las ' \
              'demo tienen datos inventados y ensucian cualquier promedio.',
      clubes: {
        total:       ids.size,
        operando:    Club.reales.activos.where(activo: true).count,
        suspendidos: Club.reales.activos.where(activo: false).count,
        eliminados:  Club.reales.where.not(deleted_at: nil).count,
        demo:        Club.where(demo: true).count,
      },
      volumen: {
        usuarios:  User.where.not(role: 'super_admin').where(club_id: ids).count,
        pacientes: Paciente.where(club_id: ids).count,
        sedes:     Sede.where(club_id: ids).count,
        salas:     Sala.where(club_id: ids).count,
        lotes:     Lote.where(club_id: ids).count,
        plantas:   Plant.joins(:lote).where(lotes: { club_id: ids }).count,
      },
      dispensacion_mes: dispensacion_mes(ids),
      por_plan:         Club.reales.activos.group(:plan).count,
      # El promedio dice más que el total: una organización mediano cultiva N lotes y atiende M pacientes.
      promedio_por_club: promedio_por_club(ids),
    }
  end

  private

  def dispensacion_mes(ids)
    desde = Time.zone.today.beginning_of_month
    d = Dispensacion.no_canceladas.joins(:paciente)
                    .where(pacientes: { club_id: ids })
                    .where('fecha_dispensacion >= ?', desde)

    { desde: desde, cantidad: d.count, gramos: d.sum(:cantidad).to_f }
  end

  def promedio_por_club(ids)
    operando = Club.reales.activos.where(activo: true).count
    return {} if operando.zero?

    {
      pacientes: (Paciente.where(club_id: ids).count.to_f / operando).round(1),
      lotes:     (Lote.where(club_id: ids).count.to_f / operando).round(1),
      usuarios:  (User.where.not(role: 'super_admin').where(club_id: ids).count.to_f / operando).round(1),
    }
  end
end
