require 'rails_helper'

# Portada de la foto del lote: la que se muestra en el slot del layout de la sala.
# Regla: la marcada como portada (si sigue) o, si no hay, la última sacada. Desde el 20-sep-2026
# las fotos son `LoteFoto`; `foto_portada_blob_id` sigue apuntando al blob.
RSpec.describe 'Fotos de lote — portada', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  def foto(name, **attrs)
    f = lote.lote_fotos.new(club: club, user: admin, **attrs)
    f.imagen.attach(io: StringIO.new("fake-#{name}"), filename: name, content_type: 'image/jpeg')
    f.save!
    f
  end

  it 'sin portada marcada, cae a la última sacada' do
    foto('a.jpg', tomada_el: Date.new(2026, 9, 1))
    f2 = foto('b.jpg', tomada_el: Date.new(2026, 9, 10))
    expect(lote.foto_portada_attachment.blob_id).to eq(f2.imagen.blob.id)
  end

  it 'PATCH portada marca la foto y la refleja en el index (es_portada)' do
    f1 = foto('a.jpg')
    foto('b.jpg')

    patch "/lotes/#{lote.id}/fotos/#{f1.id}/portada", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(lote.reload.foto_portada_blob_id).to eq(f1.imagen.blob.id)

    get "/lotes/#{lote.id}/fotos", headers: auth_headers
    portada = JSON.parse(response.body)['fotos'].find { |f| f['es_portada'] }
    expect(portada['id']).to eq(f1.id)
  end

  it 'borrar la foto de portada limpia foto_portada_blob_id' do
    f1 = foto('a.jpg')
    lote.update_column(:foto_portada_blob_id, f1.imagen.blob.id)

    delete "/lotes/#{lote.id}/fotos/#{f1.id}", headers: auth_headers
    expect(response).to have_http_status(:no_content)
    expect(lote.reload.foto_portada_blob_id).to be_nil
  end

  it 'el detalle de la sala serializa la foto_url de portada del lote (para el slot)' do
    f1 = foto('a.jpg')
    lote.update_column(:foto_portada_blob_id, f1.imagen.blob.id)

    get "/salas/#{sala.id}", headers: auth_headers
    expect(response).to have_http_status(:ok)
    lote_hist = JSON.parse(response.body)['lotes_historial'].find { |l| l['id'] == lote.id }
    expect(lote_hist['foto_url']).to be_present
  end
end
