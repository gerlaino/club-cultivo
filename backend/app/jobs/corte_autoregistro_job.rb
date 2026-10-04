# Una vez por día, sobre los usos personales que se registraron SOLOS (`RegistroPersonal`):
#   · no confirmó el mail y ya pasaron los días de gracia desde que le salió → pausa
#     (`mail_sin_confirmar`; tocar el link la despausa sola);
#   · terminó la prueba gratis y nadie la activó (`plan_trial` sigue en true) → pausa
#     (`prueba_terminada`; la activa el super admin a mano, como hasta ahora).
#
# Pausar es la suspensión de siempre: la app muestra el cartel y no se borra nada. Sólo toca a
# los autoregistrados: una organización en prueba dada de alta a mano sigue con su criterio
# (`PlanVencimientoJob` avisa y no corta).
class CorteAutoregistroJob < ApplicationJob
  queue_as :default

  def perform(hoy: Time.zone.today)
    RegistroPersonal.includes(:club).find_each do |r|
      club = r.club
      next if club.nil? || club.eliminado? || club.suspendido?

      if club.plan_trial? && club.plan_vencido?(hoy)
        club.suspender!(motivo: 'prueba_terminada')
      elsif r.pausa_el && r.pausa_el <= hoy
        club.suspender!(motivo: 'mail_sin_confirmar')
      end
    end
  end
end
