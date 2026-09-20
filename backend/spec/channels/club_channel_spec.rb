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
end
