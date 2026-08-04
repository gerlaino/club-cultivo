require 'rails_helper'

# El botón "Tomar foto" de la PWA existía pero su handler era un placeholder VACÍO: abría la cámara,
# sacabas la foto y no pasaba nada — ni se guardaba ni avisaba. `Sala` ni siquiera tenía fotos.
RSpec.describe 'Fotos de sala', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  def imagen
    Rack::Test::UploadedFile.new(
      StringIO.new("\x89PNG\r\n\x1a\n"), 'image/png', original_filename: 'cuarto.png'
    )
  end

  before { sign_in_as(admin) }

  it 'sube una foto y queda disponible en el listado' do
    post "/api/salas/#{sala.id}/fotos", params: { foto: imagen }

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)['url']).to be_present

    get "/api/salas/#{sala.id}/fotos"
    fotos = JSON.parse(response.body)
    expect(fotos.size).to eq(1)
    expect(fotos.first['filename']).to eq('cuarto.png')
  end

  it 'avisa si no llega ninguna foto en vez de crear algo vacío' do
    post "/api/salas/#{sala.id}/fotos", params: {}
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'se puede borrar' do
    post "/api/salas/#{sala.id}/fotos", params: { foto: imagen }
    id = JSON.parse(response.body)['id']

    delete "/api/salas/#{sala.id}/fotos/#{id}"
    expect(response).to have_http_status(:no_content)

    get "/api/salas/#{sala.id}/fotos"
    expect(JSON.parse(response.body)).to be_empty
  end

  # Las fotos son del cuarto de UN club: no pueden verse ni tocarse desde otro.
  it 'no expone las fotos de una sala de otro club' do
    otro       = create(:club)
    otro_admin = create(:user, :admin, club: otro)
    sala_ajena = ActsAsTenant.with_tenant(otro) do
      s = create(:sede, club: otro, created_by: otro_admin)
      create(:sala, club: otro, sede: s, created_by: otro_admin, kind: 'vegetativo')
    end

    get "/api/salas/#{sala_ajena.id}/fotos"
    expect(response).to have_http_status(:not_found)
  end
end
