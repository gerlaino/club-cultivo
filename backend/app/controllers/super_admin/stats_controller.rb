class SuperAdmin::StatsController < SuperAdmin::BaseController
  def show
    clubs = Club.all.includes(:users, :socios, :lotes)

    render json: {
      resumen: {
        total_clubs:    clubs.count,
        total_usuarios: User.where.not(role: 'super_admin').count,
        total_pacientes: Socio.count,
        total_plantas:  Plant.count,
        total_lotes:    Lote.count,
      },
      por_plan: Club.group(:plan).count,
      clubs_trial: Club.where(plan_trial: true).count,
      clubs_activos: Club.where('plan_activo_hasta >= ? OR plan_activo_hasta IS NULL', Date.today).count,
      clubs: clubs.order(:created_at).map { |c| serialize_club(c) },
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
      pacientes:    c.socios.count,
      lotes:        c.lotes.count,
      created_at:   c.created_at,
    }
  end
end