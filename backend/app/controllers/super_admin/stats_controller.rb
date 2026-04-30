class SuperAdmin::StatsController < SuperAdmin::BaseController
  def show
    clubs = Club.all.includes(:users, :pacientes, :lotes)

    render json: {
      resumen: {
        total_clubs:    clubs.count,
        total_usuarios: User.where.not(role: 'super_admin').count,
        total_pacientes: Paciente.count,
        total_plantas:  Plant.count,
        total_lotes:    Lote.count,
      },
      por_plan: Club.group(:plan).count,
      clubs_trial: Club.where(plan_trial: true).count,
      clubs_activos: Club.where('plan_activo_hasta >= ? OR plan_activo_hasta IS NULL', Date.today).count,
      clubs: clubs.order(:created_at).map { |c| serialize_club(c) },
    }
  end

  def metricas
    inicio_mes = Date.today.beginning_of_month

    render json: {
      total_clubes:          Club.count,
      total_clubes_activos:  Club.where(activo: true).count,
      total_pacientes:       Paciente.count,
      total_dispensaciones_mes: Dispensacion.where('fecha_dispensacion >= ?', inicio_mes).count,
      total_gramos_dispensados_mes: Dispensacion.where('fecha_dispensacion >= ?', inicio_mes).sum(:cantidad).to_f,
      total_lotes_activos:   Lote.where.not(estado: 'finalizado').count,
      churn_30d:             0,
      mrr:                   0,
    }
  end

  private

  def serialize_club(c)
    {
      id:           c.id,
      name:         c.name,
      slug:         c.slug,
      plan:         c.plan,
      plan_trial:   c.plan_trial,
      plan_activo_hasta: c.plan_activo_hasta,
      usuarios:     c.users.count,
      pacientes:    c.pacientes.count,
      lotes:        c.lotes.count,
      created_at:   c.created_at,
    }
  end
end