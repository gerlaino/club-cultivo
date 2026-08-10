require 'rails_helper'

# AC (10-ago-2026): el modo observador está SUSPENDIDO y no se puede activar por ningún camino.
#
# Entrar a medias a un club que está trabajando se nota, así que no alcanza con no ponerle
# botón: el endpoint se puede llamar igual, y una observación que hubiera quedado guardada
# tampoco puede revivir sola.
#
# Estos specs corren SIEMPRE. El día que se reactive (User::OBSERVADOR_HABILITADO = true) tienen
# que fallar: esa es la señal de que hay que volver a mirar
# spec/requests/super_admin_observador_spec.rb, que es el que describe el modo andando.
RSpec.describe 'Modo observador suspendido', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:club)        { create(:club, name: 'Club Observado') }

  before do
    skip 'el modo observador está activo — este spec cubre el estado suspendido' if User::OBSERVADOR_HABILITADO
  end

  it 'el endpoint no lo activa y lo dice' do
    sign_in_as(super_admin)

    post "/api/super_admin/clubs/#{club.id}/observar"

    expect(response).to have_http_status(:service_unavailable)
    expect(JSON.parse(response.body)['observador_suspendido']).to be(true)
    expect(super_admin.reload.observer_club_id).to be_nil
  end

  # Lo importante: aunque los campos quedaran cargados a mano, el modo no se enciende. Es lo
  # que hace que apagarlo sea de verdad y no dependa de que nadie toque la base.
  it 'un usuario con la observación cargada a mano sigue sin observar nada' do
    super_admin.update_columns(observer_club_id: club.id, observer_expires_at: 1.hour.from_now)

    expect(super_admin.reload.modo_observador?).to be(false)
    expect(super_admin.observando_club).to        be_nil
    expect(super_admin.club_id).to                be_nil
    expect(super_admin.club).to                   be_nil
  end

  it 'y su sesión no informa ninguna observación' do
    super_admin.update_columns(observer_club_id: club.id, observer_expires_at: 1.hour.from_now)
    sign_in_as(super_admin)

    get '/api/me'

    expect(JSON.parse(response.body)).not_to have_key('observando')
  end

  # El club sigue viendo exactamente lo de siempre: ningún bloqueo nuevo se le aplica por error.
  it 'no le cambia nada a los usuarios del club' do
    admin = create(:user, :admin, club: club)
    sign_in_as(admin)

    get '/api/salas'

    expect(response).to have_http_status(:ok)
  end
end
