require 'rails_helper'

# Al borrar/descartar plantas de un lote en manicura, hay que re-evaluar la finalización
# (el flujo normal solo la dispara al confirmar un pesaje). Si no, el lote queda pegado
# en_manicura aunque ya no haya nada que manicurar.
RSpec.describe 'Baja/descarte de plantas y finalización del lote', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, kind: 'manicura') }
  let(:lote)     { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura) }

  def confirmar_pesaje(plantas, peso_cu)
    pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicura, fecha_pesaje: Date.current)
    plantas.each { |pl| pesaje.pesadas_plantas.create!(plant: pl, peso_seco_g: peso_cu) }
    pesaje.enviar!
    pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: peso_cu * plantas.size)
  end

  it 'descartar la última planta pendiente pasa el lote a curado' do
    plantas = create_list(:plant, 3, lote: lote, club: club, state: 'cosechado')
    confirmar_pesaje(plantas.first(2), 100)
    expect(lote.reload.estado).to eq('en_manicura') # falta 1 sin procesar

    sign_in_as(admin)
    patch "/plants/#{plantas.last.id}", params: { plant: { state: 'descartada' } }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(lote.reload.estado).to eq('curado')
  end

  it 'eliminar (soft-delete) la última planta pendiente pasa el lote a curado' do
    plantas = create_list(:plant, 3, lote: lote, club: club, state: 'cosechado')
    confirmar_pesaje(plantas.first(2), 100)
    expect(lote.reload.estado).to eq('en_manicura')

    sign_in_as(admin)
    delete "/plants/#{plantas.last.id}", headers: auth_headers
    expect(response).to have_http_status(:no_content)
    expect(lote.reload.estado).to eq('curado')
  end

  it 'no descuenta plants_count dos veces al descartar y luego eliminar la misma planta' do
    lote.update_column(:plants_count, 3)
    plantas = create_list(:plant, 3, lote: lote, club: club, state: 'cosechado')
    sign_in_as(admin)

    patch "/plants/#{plantas.first.id}", params: { plant: { state: 'descartada' } }, headers: auth_headers
    expect(lote.reload.plants_count).to eq(2) # descartar: -1

    delete "/plants/#{plantas.first.id}", headers: auth_headers
    expect(lote.reload.plants_count).to eq(2) # eliminar la ya-descartada: NO vuelve a restar
  end
end
