require 'rails_helper'

# AC (Germán, 27-oct-2026): «al activar el portal en la organización, se habilita para TODOS sus
# pacientes» (activos y admitidos): se les crea la cuenta, sin mandarles nada en ese momento.
RSpec.describe PortalAcceso::HabilitarTodos do
  include ActiveJob::TestHelper

  let(:club)  { create(:club, vista_paciente_activa: false, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }

  def t(&) = ActsAsTenant.with_tenant(club, &)
  def paciente(**attrs)
    t { create(:paciente, club: club, email: 'p@example.com', aprobado_at: Time.current, created_by: admin, **attrs) }
  end

  it 'al abrir el portal, el padrón entero queda con cuenta y no sale ningún mail' do
    a = paciente
    b = paciente

    expect do
      perform_enqueued_jobs(only: HabilitarPortalJob) { club.update!(vista_paciente_activa: true) }
    end.not_to have_enqueued_mail(AccesoMailer, :portal_link)

    expect(t { [a.reload.user, b.reload.user] }).to all(be_present)
    expect(AccesoPortal.unscoped.count).to eq(0)
  end

  it 'deja afuera a los dados de baja y a las altas sin aprobar' do
    baja      = paciente(es_paciente: false)
    pendiente = paciente
    pendiente.update_column(:aprobado_at, nil)
    club.update_column(:vista_paciente_activa, true)

    described_class.call(club)

    expect(t { [baja.reload.user_id, pendiente.reload.user_id] }).to eq([nil, nil])
  end

  it 'al que ya tenía cuenta no se la toca' do
    con_cuenta = paciente
    club.update_column(:vista_paciente_activa, true)
    user = t { Pacientes::Acceso.crear!(con_cuenta).user }
    digest = user.encrypted_password

    expect(described_class.call(club).creadas).to eq(0)
    expect(user.reload.encrypted_password).to eq(digest)
  end

  it 'con el portal cerrado no crea nada' do
    p = paciente
    expect(described_class.call(club).creadas).to eq(0)
    expect(t { p.reload.user_id }).to be_nil
  end

  it 'sólo toca a los pacientes de esa organización' do
    otra = create(:club, features: { 'produccion_dispensa' => true })
    ajeno = ActsAsTenant.with_tenant(otra) do
      create(:paciente, club: otra, aprobado_at: Time.current, created_by: create(:user, :admin, club: otra))
    end
    paciente
    club.update_column(:vista_paciente_activa, true)

    described_class.call(club)

    expect(ActsAsTenant.with_tenant(otra) { ajeno.reload.user_id }).to be_nil
  end
end
