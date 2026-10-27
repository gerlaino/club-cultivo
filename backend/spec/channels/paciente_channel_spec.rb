require 'rails_helper'

# Lo que le cambia al paciente, en vivo (su chat). El stream sale de SU ficha: nunca de un
# parámetro, así que no puede escuchar el de otro.
RSpec.describe PacienteChannel, type: :channel do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ficha) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) } }
  let(:user)  { ActsAsTenant.with_tenant(club) { Pacientes::Acceso.crear!(ficha).user } }

  it 'el paciente escucha SU canal' do
    stub_connection current_user: user
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(PacienteChannel.stream(ficha.id))
  end

  it 'no escucha el de otro paciente aunque lo pida' do
    otra = ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) }
    stub_connection current_user: user
    subscribe(paciente_id: otra.id)
    expect(subscription).not_to have_stream_from(PacienteChannel.stream(otra.id))
  end

  it 'el equipo no se suscribe a este canal' do
    stub_connection current_user: admin
    subscribe
    expect(subscription).to be_rejected
  end

  it '«está escribiendo» le llega a su organización' do
    stub_connection current_user: user
    subscribe
    expect { perform :escribiendo }
      .to have_broadcasted_to("club_#{club.id}").with(hash_including(recurso: 'mensajes', accion: 'escribiendo', id: ficha.id))
  end
end
