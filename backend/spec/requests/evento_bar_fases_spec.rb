require 'rails_helper'

# Eventos por fases (B6 del rediseño del Salón): el estado avanza por el carril
# planificado → en_venta → en_curso → finalizado, siempre se puede cancelar, y un evento
# terminal (finalizado/cancelado) NO se reabre.
RSpec.describe 'Eventos del bar — transiciones por fases', type: :request do
  let(:club)   { create(:club, features: { 'bar' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, tipo: 'social') }
  let(:bar)    { create(:barra, club: club, sede: sede) }
  let(:evento) { bar.eventos_bar.create!(club: club, nombre: 'Fiesta', estado: estado_inicial) }
  let(:estado_inicial) { 'planificado' }

  before { sign_in_as(admin) }

  def cambiar(estado)
    patch "/bares/#{bar.id}/eventos/#{evento.id}", params: { evento_bar: { estado: estado } }, headers: auth_headers, as: :json
  end

  it 'avanza por el carril: planificado → en_venta' do
    cambiar('en_venta')
    expect(response).to have_http_status(:ok)
    expect(evento.reload.estado).to eq('en_venta')
  end

  it 'se puede cancelar desde una fase activa' do
    cambiar('cancelado')
    expect(response).to have_http_status(:ok)
    expect(evento.reload.estado).to eq('cancelado')
  end

  it 'permite cerrar directo (planificado → finalizado)' do
    cambiar('finalizado')
    expect(response).to have_http_status(:ok)
    expect(evento.reload.estado).to eq('finalizado')
  end

  context 'cuando el evento está finalizado' do
    let(:estado_inicial) { 'finalizado' }

    it 'no se puede reabrir' do
      cambiar('en_curso')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(evento.reload.estado).to eq('finalizado')
    end
  end

  context 'cuando el evento está cancelado' do
    let(:estado_inicial) { 'cancelado' }

    it 'no se puede reactivar' do
      cambiar('planificado')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(evento.reload.estado).to eq('cancelado')
    end
  end

  it 'expone las transiciones posibles en el detalle' do
    get "/bares/#{bar.id}/eventos/#{evento.id}", headers: auth_headers, as: :json
    body = JSON.parse(response.body)
    expect(body['transiciones']).to include('en_venta', 'en_curso', 'finalizado', 'cancelado')
    expect(body['transiciones']).not_to include('planificado')
  end

  it 'guarda y devuelve el horario (texto libre)' do
    patch "/bares/#{bar.id}/eventos/#{evento.id}", params: { evento_bar: { horario: '22:00 a 05:00' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['horario']).to eq('22:00 a 05:00')
    expect(evento.reload.horario).to eq('22:00 a 05:00')
  end
end
