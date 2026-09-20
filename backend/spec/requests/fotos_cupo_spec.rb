require 'rails_helper'

# El techo de fotos del plan (20-sep-2026): las de lote, sala y planta cuentan contra el mismo
# número, y las tres puertas lo respetan. Mide almacenamiento, no capacidad del cultivo: por
# eso hasta el plan Total tiene uno.
RSpec.describe 'Fotos — cupo del plan', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, plan: 'personal') }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, start_date: Date.new(2026, 9, 1), estado: 'vegetativo') }
  let(:plant) { create(:plant, club: club, lote: lote) }

  def imagen(bytes = "\x89PNG\r\n\x1a\n")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), 'image/png', original_filename: 'p.png')
  end

  before { sign_in_as(admin) }

  it 'la galería dice cuántas van y cuántas caben' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-15' }, headers: auth_headers
    get "/lotes/#{lote.id}/fotos", headers: auth_headers
    expect(json['cupo']).to eq('usadas' => 1, 'tope' => PlanEnforcer::PLANES['personal'][:fotos])
  end

  it 'las tres puertas cuentan contra el mismo techo y al llegar devuelven 402' do
    stub_const('PlanEnforcer::PLANES', PlanEnforcer::PLANES.deep_merge('personal' => { fotos: 3 }))

    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-15' }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body
    post "/salas/#{sala.id}/fotos", params: { foto: imagen }, headers: auth_headers
    expect(response).to have_http_status(:created).or(have_http_status(:ok)), response.body
    post "/plants/#{plant.id}/add_foto", params: { foto: imagen }, headers: auth_headers
    expect(response.status).to be_between(200, 299), response.body

    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-16' }, headers: auth_headers
    expect(response).to have_http_status(:payment_required)
    expect(json['error']).to eq('limite_plan')
    expect(json['mensaje']).to include('3 fotos')
    expect(json['cupo']).to eq('usadas' => 3, 'tope' => 3)

    post "/salas/#{sala.id}/fotos", params: { foto: imagen }, headers: auth_headers
    expect(response).to have_http_status(:payment_required)
    post "/plants/#{plant.id}/add_foto", params: { foto: imagen }, headers: auth_headers
    expect(response).to have_http_status(:payment_required)
  end

  # Quien no contrata no negocia el plan: al cultivador se le pide que avise, no que escriba.
  it 'al cultivador el tope le habla de su administrador' do
    stub_const('PlanEnforcer::PLANES', PlanEnforcer::PLANES.deep_merge('personal' => { fotos: 0 }))
    cultivador = create(:user, :cultivador, club: club)
    sign_in_as(cultivador)
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-15' }, headers: auth_headers
    expect(response).to have_http_status(:payment_required)
    expect(json['mensaje']).to include('administrador')
  end

  it 'una foto de más de 8 MB no entra, y lo dice' do
    stub_const('PlanEnforcer::FOTO_MAX_BYTES', 10)
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen('x' * 11), tomada_el: '2026-09-15' }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['error']).to include('pesa más de')
  end

  it 'el plan Total también tiene techo de fotos, más alto' do
    expect(PlanEnforcer::PLANES['total'][:fotos]).to be > PlanEnforcer::PLANES['basico'][:fotos]
    expect(PlanEnforcer::PLANES['basico'][:fotos]).to be > PlanEnforcer::PLANES['personal'][:fotos]
  end
end
