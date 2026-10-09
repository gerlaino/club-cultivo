require 'rails_helper'

# AC (4-oct-2026, plan A): el autoregistrado tiene 7 días desde que el mail SALIÓ para confirmarlo;
# si no, se pausa (y el link lo despausa). Si el mail nunca salió, no corre ningún reloj. Terminada
# la prueba sin activar, se pausa con «prueba terminada». Sólo toca a los autoregistrados.
RSpec.describe CorteAutoregistroJob do
  def autoregistrado(email:, mail_enviado_at: nil, hasta: Time.zone.today + 30)
    reg = Registros::CrearPersonal.new(nombre: 'Juana', email: email, password: 'clave-larga-1', acepta_terminos: true, mayor_de_edad: true).call
    reg.update!(mail_enviado_at: mail_enviado_at)
    reg.club.update!(plan_activo_hasta: hasta)
    reg
  end

  let(:hoy) { Time.zone.today }

  it 'pausa al que no confirmó a los 7 días de recibir el mail' do
    reg = autoregistrado(email: 'a@ej.com', mail_enviado_at: 7.days.ago)
    described_class.perform_now(hoy: hoy)
    expect(reg.club.reload.suspension_motivo).to eq('mail_sin_confirmar')
  end

  it 'no pausa antes de los 7 días' do
    reg = autoregistrado(email: 'b@ej.com', mail_enviado_at: 6.days.ago)
    described_class.perform_now(hoy: hoy)
    expect(reg.club.reload).not_to be_suspendido
  end

  it 'si el mail nunca salió, no pausa (no se le puede pedir que confirme lo que no le llegó)' do
    reg = autoregistrado(email: 'c@ej.com', mail_enviado_at: nil)
    reg.update_columns(created_at: 30.days.ago)
    described_class.perform_now(hoy: hoy)
    expect(reg.club.reload).not_to be_suspendido
  end

  it 'el que confirmó no se pausa por el mail' do
    reg = autoregistrado(email: 'd@ej.com', mail_enviado_at: 10.days.ago)
    reg.update!(confirmado_at: 9.days.ago)
    described_class.perform_now(hoy: hoy)
    expect(reg.club.reload).not_to be_suspendido
  end

  it 'terminada la prueba sin activar, pausa con «prueba terminada»' do
    reg = autoregistrado(email: 'e@ej.com', hasta: hoy - 1)
    reg.update!(confirmado_at: Time.current)
    described_class.perform_now(hoy: hoy)
    expect(reg.club.reload.suspension_motivo).to eq('prueba_terminada')
  end

  it 'si el super admin la activó (ya no es prueba), no la toca aunque la fecha pase' do
    reg = autoregistrado(email: 'f@ej.com', hasta: hoy - 1)
    reg.club.update!(plan_trial: false)
    described_class.perform_now(hoy: hoy)
    expect(reg.club.reload).not_to be_suspendido
  end

  it 'una organización en prueba dada de alta a mano no se corta' do
    club = create(:club, plan_trial: true, plan_activo_hasta: hoy - 5)
    described_class.perform_now(hoy: hoy)
    expect(club.reload).not_to be_suspendido
  end
end
