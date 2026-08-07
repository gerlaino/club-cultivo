class SuperAdmin::StatsController < SuperAdmin::BaseController
  # Las métricas de plataforma cuentan SOLO clubes reales. Un club demo (el Club Modelo que se le
  # muestra a un prospecto, o una copia de prueba) tiene cientos de dispensaciones y pacientes
  # inventados: contarlos infla todo y, de cara al benchmarking del sector, mete en el promedio
  # números que nunca existieron.
  #
  # El LISTADO sí los muestra —hay que poder entrar a administrarlos—, marcados con `demo: true`.
  def show
    clubs = Club.unscoped.includes(:users, :pacientes, :lotes)
    reales = Club.reales.pluck(:id)

    render json: {
      resumen: {
        total_clubs:     reales.size,
        total_usuarios:  User.where.not(role: 'super_admin').where(club_id: reales).count,
        total_pacientes: Paciente.where(club_id: reales).count,
        total_plantas:   Plant.where(club_id: reales).count,
        total_lotes:     Lote.where(club_id: reales).count,
      },
      por_plan:      Club.reales.group(:plan).count,
      clubs_trial:   Club.reales.where(plan_trial: true).count,
      clubs_activos: Club.reales.where('plan_activo_hasta >= ? OR plan_activo_hasta IS NULL', Time.zone.today).count,
      clubs: clubs.order(:created_at).map { |c| serialize_club(c) },
    }
  end

  def metricas
    inicio_mes = Time.zone.today.beginning_of_month
    reales     = Club.reales.pluck(:id)
    dispensas  = Dispensacion.no_canceladas
                             .joins(:paciente).where(pacientes: { club_id: reales })
                             .where('fecha_dispensacion >= ?', inicio_mes)

    render json: {
      total_clubes:          reales.size,
      total_clubes_activos:  Club.reales.where(activo: true).count,
      total_pacientes:       Paciente.where(club_id: reales).count,
      total_dispensaciones_mes:     dispensas.count,
      total_gramos_dispensados_mes: dispensas.sum(:cantidad).to_f,
      total_lotes_activos:   Lote.where(club_id: reales).where.not(estado: 'finalizado').count,
      churn_30d:             0,
      mrr:                   0,
    }
  end

  private

  def serialize_club(c)
    {
      id:               c.id,
      name:             c.name,
      slug:             c.slug,
      email:            c.email,
      city:             c.city,
      plan:             c.plan,
      plan_trial:       c.plan_trial,
      plan_activo_hasta: c.plan_activo_hasta,
      # Para que en la lista se vea cuál es un club de demostración y cuál opera de verdad.
      demo:             c.demo,
      usuarios_count:   c.users.count,
      pacientes_count:  c.pacientes.count,
      lotes_count:      c.lotes.count,
      created_at:       c.created_at,
      deleted_at:       c.deleted_at,
    }
  end
end
