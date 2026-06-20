require 'rails_helper'

RSpec.describe 'foto_url en el listado de plantas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:plant) { Plant.create!(lote: lote, club: club, nombre: 'P1', state: 'vegetativo') }

  before { sign_in_as(admin) }

  it 'devuelve foto_url cuando la foto se subió a `fotos` (has_many)' do
    plant.fotos.attach(io: StringIO.new('fake-img'), filename: 'p1.jpg', content_type: 'image/jpeg')

    get '/api/plants', params: { lote_id: lote.id }
    expect(response).to have_http_status(:ok)
    row = JSON.parse(response.body).find { |p| p['id'] == plant.id }
    expect(row['foto_url']).to be_present
  end

  it 'foto_url es nil si la planta no tiene fotos' do
    plant
    get '/api/plants', params: { lote_id: lote.id }
    row = JSON.parse(response.body).find { |p| p['id'] == plant.id }
    expect(row['foto_url']).to be_nil
  end
end
