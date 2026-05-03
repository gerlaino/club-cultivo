require 'rails_helper'

RSpec.describe 'Dispensador clinical tabs restriction', type: :request do
  let!(:club)        { create(:club) }
  let!(:admin)       { create(:user, :admin,       club: club) }
  let!(:dispensador) { create(:user, :dispensador, club: club) }
  let!(:paciente)    { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(dispensador) }

  it 'GET /pacientes → 200 (dispensador puede ver la lista)' do
    get '/pacientes', headers: auth_headers
    expect(response).to have_http_status(:ok)
  end

  it 'GET /pacientes/:id/notas → 403' do
    get "/pacientes/#{paciente.id}/notas", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'POST /pacientes/:id/notas → 403' do
    post "/pacientes/#{paciente.id}/notas",
         params: { nota: { contenido: 'nota' } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /pacientes/:id/dispensaciones → 200 (dispensador puede ver dispensaciones)' do
    get "/pacientes/#{paciente.id}/dispensaciones", headers: auth_headers
    expect(response).to have_http_status(:ok)
  end
end
