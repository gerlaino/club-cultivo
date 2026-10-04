# Manda el mail de confirmación de un autoregistro y, SÓLO si salió, anota cuándo: desde ahí corren
# los días de gracia (`RegistroPersonal#pausa_el`). Por eso no es un `deliver_later` suelto: hay
# que saber si el correo de la plataforma lo aceptó. Si falla, se reintenta como todo job; si
# nunca sale, la cuenta no se pausa por un mail que no le llegó.
class EnviarConfirmacionRegistroJob < ApplicationJob
  queue_as :default

  def perform(registro_id)
    registro = RegistroPersonal.find_by(id: registro_id)
    return if registro.nil? || registro.confirmado?

    token = registro.nuevo_token!
    AccesoMailer.confirmar_mail(registro: registro, token: token).deliver_now
    registro.update!(mail_enviado_at: Time.current)
  end
end
