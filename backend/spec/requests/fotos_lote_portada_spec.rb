require 'rails_helper'

# Portada de la foto del lote: la que se muestra en el slot del layout de la sala.
# Regla: la marcada como portada (si sigue adjunta) o, si no hay, la última subida.
RSpec.describe 'Fotos de lote — portada', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  def attach_foto(name)
    lote.fotos.attach(io: StringIO.new("fake-#{name}"), filename: name, content_type: 'image/jpeg')
    lote.fotos.blobs.order(created_at: :desc, id: :desc).first
  end

  it 'sin portada marcada, cae a la última subida' do
    attach_foto('a.jpg')
    b2 = attach_foto('b.jpg')
    expect(lote.foto_portada_attachment.blob_id).to eq(b2.id)
  end

  it 'PATCH portada marca la foto y la refleja en el index (es_portada)' do
    b1 = attach_foto('a.jpg')
    attach_foto('b.jpg')

    patch "/lotes/#{lote.id}/fotos/#{b1.id}/portada", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(lote.reload.foto_portada_blob_id).to eq(b1.id)
    expect(lote.foto_portada_attachment.blob_id).to eq(b1.id)

    get "/lotes/#{lote.id}/fotos", headers: auth_headers
    portada = JSON.parse(response.body).find { |f| f['es_portada'] }
    expect(portada['id']).to eq(b1.id)
  end

  it 'borrar la foto de portada limpia foto_portada_blob_id' do
    b1 = attach_foto('a.jpg')
    lote.update_column(:foto_portada_blob_id, b1.id)

    delete "/lotes/#{lote.id}/fotos/#{b1.id}", headers: auth_headers
    expect(response).to have_http_status(:no_content)
    expect(lote.reload.foto_portada_blob_id).to be_nil
  end

  it 'el detalle de la sala serializa la foto_url de portada del lote (para el slot)' do
    b1 = attach_foto('a.jpg')
    lote.update_column(:foto_portada_blob_id, b1.id)

    get "/salas/#{sala.id}", headers: auth_headers
    expect(response).to have_http_status(:ok)
    lote_hist = JSON.parse(response.body)['lotes_historial'].find { |l| l['id'] == lote.id }
    expect(lote_hist['foto_url']).to be_present
  end
end
