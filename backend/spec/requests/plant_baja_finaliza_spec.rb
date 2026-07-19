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

  it 'descartar TODAS las plantas finaliza el lote (sin producción)' do
    plantas = create_list(:plant, 2, lote: lote, club: club, state: 'cosechado')
    sign_in_as(admin)
    patch "/plants/#{plantas.first.id}", params: { plant: { state: 'descartada' }, motivo: 'x' }, headers: auth_headers
    expect(lote.reload.estado).to eq('en_manicura') # todavía queda 1 activa

    patch "/plants/#{plantas.last.id}", params: { plant: { state: 'descartada' }, motivo: 'x' }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(lote.reload.estado).to eq('finalizado')  # 0 activas → sin producción → finalizado
  end

  it 'reevaluar_manicura finaliza un lote que quedó listo pero atascado' do
    plantas = create_list(:plant, 2, lote: lote, club: club, state: 'cosechado')
    confirmar_pesaje(plantas, 100)
    lote.update_column(:estado, 'en_manicura') # simular atasco (dato de antes del fix)

    sign_in_as(admin)
    post "/lotes/#{lote.id}/reevaluar_manicura", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['estado']).to eq('curado')
    expect(lote.reload.estado).to eq('curado')
  end

  it 'reevaluar_manicura NO finaliza si aún faltan plantas' do
    plantas = create_list(:plant, 3, lote: lote, club: club, state: 'cosechado')
    confirmar_pesaje(plantas.first(2), 100)

    sign_in_as(admin)
    post "/lotes/#{lote.id}/reevaluar_manicura", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['estado']).to eq('en_manicura')
  end

  it 'descartar la última planta pendiente pasa el lote a curado' do
    plantas = create_list(:plant, 3, lote: lote, club: club, state: 'cosechado')
    confirmar_pesaje(plantas.first(2), 100)
    expect(lote.reload.estado).to eq('en_manicura') # falta 1 sin procesar

    sign_in_as(admin)
    patch "/plants/#{plantas.last.id}", params: { plant: { state: 'descartada' }, motivo: 'test' }, headers: auth_headers
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

  it 'descartar exige motivo y lo guarda en la nota de la planta' do
    planta = create(:plant, lote: lote, club: club, state: 'cosechado')
    sign_in_as(admin)

    patch "/plants/#{planta.id}", params: { plant: { state: 'descartada' } }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(planta.reload.state).not_to eq('descartada')

    patch "/plants/#{planta.id}", params: { plant: { state: 'descartada' }, motivo: 'se secó por plaga' }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(planta.reload.state).to eq('descartada')
    expect(planta.notas).to include('se secó por plaga')
  end

  it 'no descuenta plants_count dos veces al descartar y luego eliminar la misma planta' do
    lote.update_column(:plants_count, 3)
    plantas = create_list(:plant, 3, lote: lote, club: club, state: 'cosechado')
    sign_in_as(admin)

    patch "/plants/#{plantas.first.id}", params: { plant: { state: 'descartada' }, motivo: 'test' }, headers: auth_headers
    expect(lote.reload.plants_count).to eq(2) # descartar: -1

    delete "/plants/#{plantas.first.id}", headers: auth_headers
    expect(lote.reload.plants_count).to eq(2) # eliminar la ya-descartada: NO vuelve a restar
  end
end
