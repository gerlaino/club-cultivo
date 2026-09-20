require 'rails_helper'

# Las genéticas del catálogo INASE son filas globales, compartidas por TODAS las organizaciones.
# Se miran; no se editan desde una organización: hasta el 20-sep-2026 un admin podía marcarlas
# «disponible» y se las marcaba a todos («me trajo una genética de otro usuario»).
RSpec.describe 'Genéticas — el catálogo INASE es compartido y de sólo lectura', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:global) { ActsAsTenant.without_tenant { Genetica.create!(nombre: "INASE #{SecureRandom.hex(2)}", tipo: 'hibrida', global: true, registrada_inase: true, club_id: nil, disponible: false) } }
  let(:org)    { create(:club, features: { 'cultivo' => true }) }
  let(:admin)  { create(:user, :admin, club: org) }

  it 'una organización no puede marcarla disponible (se la marcaría a todas)' do
    sign_in_as(admin)
    patch "/geneticas/#{global.id}", params: { genetica: { disponible: true } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(json['error']).to include('compartido')
    expect(global.reload.disponible).to be false
  end

  it 'ni apagarla' do
    sign_in_as(admin)
    delete "/geneticas/#{global.id}", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
    expect(global.reload.activa).to be true
  end

  it 'la organización sí la ve, como referencia, y su propia genética sí se edita' do
    sign_in_as(admin)
    global
    propia = ActsAsTenant.with_tenant(org) { Genetica.create!(club: org, nombre: 'Casera', tipo: 'hibrida') }
    get '/geneticas', headers: auth_headers
    ids = json.map { |g| g['id'] }
    expect(ids).to include(propia.id)
    expect(ids).to include(global.id)
    patch "/geneticas/#{propia.id}", params: { genetica: { disponible: false } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
  end

  it 'el cultivador de casa ve SÓLO las suyas: el catálogo no es de nadie y lo confunde' do
    personal = create(:club, plan: 'personal', features: { 'cultivo' => true })
    yo = create(:user, :admin, club: personal)
    global
    ActsAsTenant.with_tenant(personal) { Genetica.create!(club: personal, nombre: 'Mía', tipo: 'hibrida') }
    sign_in_as(yo)
    get '/geneticas', headers: auth_headers
    expect(json.map { |g| g['nombre'] }).to eq(['Mía'])
    expect(json.map { |g| g['id'] }).not_to include(global.id)
  end
end
