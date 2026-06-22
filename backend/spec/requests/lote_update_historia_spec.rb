require 'rails_helper'

RSpec.describe 'PATCH /lotes/:id — corrección de estado e historia', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 60.days.ago.to_date) }

  before { sign_in_as(admin) }

  it 'cambia el estado del lote' do
    patch "/lotes/#{lote.id}", params: { lote: { estado: 'floracion' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(lote.reload.estado).to eq('floracion')
  end

  it 'reconcilia la fecha de inicio de floración creando el evento si falta' do
    fecha = 20.days.ago.to_date
    patch "/lotes/#{lote.id}",
          params: { lote: { estado: 'floracion' }, fechas_fase: { floracion: fecha.to_s } },
          headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    ev = lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'floracion').first
    expect(ev).to be_present
    expect(ev.registrado_en.to_date).to eq(fecha)
    body = JSON.parse(response.body)
    expect(body['fecha_inicio_floracion']).to eq(fecha.to_s)
  end

  it 'actualiza el evento existente en vez de duplicarlo' do
    lote.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', descripcion: 'x', registrado_en: 30.days.ago, club: club, user: admin)
    nueva = 10.days.ago.to_date
    patch "/lotes/#{lote.id}", params: { lote: { estado: 'floracion' }, fechas_fase: { floracion: nueva.to_s } }, headers: auth_headers, as: :json
    eventos_flor = lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'floracion')
    expect(eventos_flor.count).to eq(1)
    expect(eventos_flor.first.registrado_en.to_date).to eq(nueva)
  end

  context 'propagación del estado a las plantas' do
    let(:lote) { create(:lote, club: club, sala: sala, estado: 'esqueje', start_date: 60.days.ago.to_date) }
    let!(:p1)  { create(:plant, lote: lote, club: club, state: 'esqueje') }
    let!(:p2)  { create(:plant, lote: lote, club: club, state: 'esqueje') }
    let!(:descartada) { create(:plant, lote: lote, club: club, state: 'descartada') }

    it 'al cambiar esqueje → vegetativo pasa las plantas a vegetativo' do
      patch "/lotes/#{lote.id}", params: { lote: { estado: 'vegetativo' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(p1.reload.state).to eq('vegetativo')
      expect(p2.reload.state).to eq('vegetativo')
    end

    it 'no toca plantas descartadas' do
      patch "/lotes/#{lote.id}", params: { lote: { estado: 'vegetativo' } }, headers: auth_headers, as: :json
      expect(descartada.reload.state).to eq('descartada')
    end

    it 'no toca plantas si el estado no cambió' do
      patch "/lotes/#{lote.id}", params: { lote: { estado: 'esqueje', notes: 'solo nota' } }, headers: auth_headers, as: :json
      expect(p1.reload.state).to eq('esqueje')
    end
  end
end
