require 'rails_helper'

# El canal «algo cambió» de la organización. El stream sale del club del usuario conectado,
# nunca de un parámetro: nadie puede escuchar otra organización.
RSpec.describe ClubChannel, type: :channel do
  let(:club) { create(:club) }
  let(:user) { create(:user, :admin, club: club) }

  it 'escucha el canal de SU organización' do
    stub_connection current_user: user
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("club_#{club.id}")
  end

  it 'no escucha otra aunque la pida' do
    otro = create(:club)
    stub_connection current_user: user
    subscribe(club_id: otro.id)
    expect(subscription).not_to have_stream_from("club_#{otro.id}")
  end

  it 'sin organización se rechaza' do
    stub_connection current_user: create(:user, :super_admin)
    subscribe
    expect(subscription).to be_rejected
  end

  # El paciente no escucha lo que hace el equipo (27-oct-2026): lo suyo le llega por PacienteChannel.
  it 'el paciente no se suscribe al canal de la organización' do
    paciente = create(:user, club: club, role: 'paciente')
    stub_connection current_user: paciente
    subscribe
    expect(subscription).to be_rejected
  end

  describe '«está escribiendo» en el chat con un paciente' do
    let(:club) { create(:club, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
    let(:ficha) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: user) } }

    it 'se le avisa a ESE paciente, con el nombre de quien escribe' do
      stub_connection current_user: user
      subscribe
      expect { perform :escribiendo, paciente_id: ficha.id }
        .to have_broadcasted_to(PacienteChannel.stream(ficha.id)).with(hash_including(accion: 'escribiendo', por: user.first_name))
    end

    it 'a un paciente de otra organización, no' do
      otro_club = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro_club) { create(:paciente, club: otro_club, created_by: create(:user, :admin, club: otro_club)) }
      stub_connection current_user: user
      subscribe
      expect { perform :escribiendo, paciente_id: ajeno.id }.not_to have_broadcasted_to(PacienteChannel.stream(ajeno.id))
    end
  end
end
