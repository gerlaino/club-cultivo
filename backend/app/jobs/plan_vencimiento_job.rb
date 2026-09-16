# Avisa al admin de la organización que su plan vence, o que venció. Hasta sep-2026
# `plan_activo_hasta` lo leía sólo el panel de plataforma: la organización no tenía forma de
# saber cuándo vencía, y el dueño de la plataforma se enteraba de que venció por el panel, con
# la organización operando igual. Dos avisos, no uno por día: siete días antes (hay tiempo de
# renovar) y el día que vence. Es INFORMATIVO: el vencimiento no corta nada (decisión de
# negocio pendiente); lo que hace es que nadie se sorprenda.
class PlanVencimientoJob < ApplicationJob
  queue_as :default

  DIAS_ANTES = 7

  def perform(hoy: Time.zone.today)
    Club.reales.activos.where(activo: true).where.not(plan_activo_hasta: nil).find_each do |club|
      dias = (club.plan_activo_hasta - hoy).to_i
      next unless dias == DIAS_ANTES || dias.zero?

      ActsAsTenant.with_tenant(club) { avisar(club, dias) }
    end
  end

  private

  def avisar(club, dias)
    tipo  = dias.zero? ? 'plan_vencido' : 'plan_por_vencer'
    fecha = club.plan_activo_hasta.strftime('%d/%m/%Y')
    texto = if dias.zero?
              "El plan de la organización vence hoy (#{fecha}). La app sigue andando; hablá con Cultivo Espacial para renovarlo."
            else
              "El plan de la organización vence el #{fecha}, en #{dias} días. Hablá con Cultivo Espacial para renovarlo."
            end

    # Una vez por vencimiento: si el job corriera dos veces el mismo día, no se duplica.
    return if AlertaInterna.where(club: club, tipo: tipo).where("contexto->>'vence' = ?", club.plan_activo_hasta.to_s).exists?

    AlertaInterna.create!(
      club: club, tipo: tipo, mensaje: texto, severidad: dias.zero? ? 'error' : 'warning',
      destinada_a_role: 'admin', contexto: { vence: club.plan_activo_hasta.to_s, dias: dias }
    )
    PushNotificationService.notify_admins_async(club, title: dias.zero? ? 'Tu plan vence hoy' : 'Tu plan vence en una semana',
                                                      body: texto, url: '/configuracion/club')

    # Y por mail, por la casilla de la plataforma, a cada admin con una casilla real: la campana
    # la ve quien entra, y el que dejó de entrar es justo el que hay que avisar.
    club.users.where(role: 'admin').find_each do |admin|
      next if admin.email_real.blank?

      AccesoMailer.plan_vence(user: admin, club: club, dias: dias).deliver_later
    end
  end
end
