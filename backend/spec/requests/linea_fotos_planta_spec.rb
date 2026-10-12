require 'rails_helper'

# AC (11-oct-2026, plan aprobado por Germán): ver crecer una planta. Todas sus fotos en orden —las
# de su ficha y las de la galería que la nombran—, más las del lote sin planta («todas»), marcadas;
# las de otra planta no. Cada una con su día de vida y la fase de ese día.
RSpec.describe 'Línea de fotos de una planta', type: :request do
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:admin) { create(:user, :admin, club: club) }
  def img = Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1a\n"), 'image/png', original_filename: 'f.png')

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  it 'junta las de la ficha y las de la galería, en orden, sin las de otra planta' do
    sala = create(:sala, club: club)
    lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 20.days.ago.to_date)
    yo   = create(:plant, lote: lote, club: club, state: 'vegetativo')
    otra = create(:plant, lote: lote, club: club, state: 'vegetativo')
    foto = ->(plant, dias) { LoteFoto.create!(club: club, lote: lote, plant: plant, tomada_el: dias.days.ago.to_date, imagen: img) }
    foto.(yo, 10); foto.(nil, 5); foto.(otra, 3)
    yo.fotos.attach(img)

    get "/plants/#{yo.id}/linea_fotos"

    expect(response).to have_http_status(:ok)
    expect(json.size).to eq(3)
    expect(json.map { |f| f['dia'] }).to eq([11, 16, 21])
    expect(json.map { |f| f['de_todas'] }).to eq([false, true, false])
    expect(json.first['fase']).to eq('vegetativo')
  end

  it 'aislamiento: la planta de otra cuenta no se ve' do
    otro = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
    ajena = ActsAsTenant.with_tenant(otro) do
      lote = create(:lote, club: otro, sala: create(:sala, club: otro), estado: 'vegetativo')
      create(:plant, lote: lote, club: otro, state: 'vegetativo')
    end

    get "/plants/#{ajena.id}/linea_fotos"
    expect(response).to have_http_status(:not_found)
  end
end
