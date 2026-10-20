require 'rails_helper'

# AC (regla del proyecto): la pantalla nunca pide lo que el backend le va a negar. Las reseñas de
# una genética son de administración; la ficha dice si este rol las ve y el cultivador no las pide.
RSpec.describe 'Reseñas de una genética', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)     { create(:club, features: { 'cultivo' => true }) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:genetica) { ActsAsTenant.with_tenant(club) { create(:genetica, club: club) } }

  it 'la ficha le dice al admin que ve las reseñas, y las recibe' do
    sign_in_as(admin)
    get "/geneticas/#{genetica.id}", headers: auth_headers
    expect(json['ve_resenas']).to be(true)

    get "/geneticas/#{genetica.id}/resenas", headers: auth_headers
    expect(response).to have_http_status(:ok)
  end

  it 'la ficha le dice al cultivador que no las ve, y el endpoint se las niega' do
    sign_in_as(create(:user, :cultivador, club: club))
    get "/geneticas/#{genetica.id}", headers: auth_headers
    expect(json['ve_resenas']).to be(false)

    get "/geneticas/#{genetica.id}/resenas", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'no muestra la genética de otra organización' do
    otro = create(:club, features: { 'cultivo' => true })
    ajena = ActsAsTenant.with_tenant(otro) { create(:genetica, club: otro) }
    sign_in_as(admin)
    get "/geneticas/#{ajena.id}/resenas", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
