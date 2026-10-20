require 'rails_helper'

# AC (recorrido del 20-oct-2026): el médico abre «Disponibilidad» y ve el horario que cargó. La
# pantalla pedía GET /api/medico/disponibilidad y la ruta no existía (404 desde el 9-jun-2026):
# guardaba pero nunca podía ver lo guardado.
RSpec.describe 'Disponibilidad del médico', type: :request do
  let(:club)   { create(:club) }
  let(:medico) { create(:user, :medico, club: club) }

  before { sign_in_as(medico) }

  it 'guarda el horario y lo devuelve al volver a entrar' do
    put '/api/medico/disponibilidad',
        params: { disponibilidad: [{ dia_semana: 1, hora_inicio: 540, hora_fin: 780 }] }, as: :json
    expect(response).to have_http_status(:ok), response.body

    get '/api/medico/disponibilidad'
    expect(response).to have_http_status(:ok)
    slots = JSON.parse(response.body)
    expect(slots.size).to eq(1)
    expect(slots.first).to include('dia_semana' => 1, 'hora_inicio' => 540, 'hora_fin' => 780)
  end

  it 'sin horario cargado devuelve una lista vacía, no un error' do
    get '/api/medico/disponibilidad'
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq([])
  end

  it 'no muestra el horario que el mismo médico tiene en otra organización' do
    otro_club = create(:club)
    ActsAsTenant.with_tenant(otro_club) do
      DisponibilidadMedico.create!(medico: medico, club: otro_club, dia_semana: 3, hora_inicio: 600, hora_fin: 720)
    end

    get '/api/medico/disponibilidad'
    expect(JSON.parse(response.body)).to eq([])
  end

  it 'otro rol no entra' do
    sign_in_as(create(:user, :cultivador, club: club))
    get '/api/medico/disponibilidad'
    expect(response).to have_http_status(:forbidden)
  end
end
