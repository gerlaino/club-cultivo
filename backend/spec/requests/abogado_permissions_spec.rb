require 'rails_helper'

RSpec.describe 'Abogado permissions', type: :request do
  let!(:club)     { create(:club) }
  let!(:admin)    { create(:user, :admin,   club: club) }
  let!(:abogado)  { create(:user, :abogado, club: club) }
  let!(:paciente) { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(abogado) }

  it 'GET /pacientes → 403' do
    get '/pacientes', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /pacientes/:id → 403' do
    get "/pacientes/#{paciente.id}", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /movimientos_contables → 403' do
    get '/movimientos_contables', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /informe_semestral → 403' do
    get '/informe_semestral', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /tareas → 403' do
    get '/tareas', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /documentos → 200 (filtrado a sus propios documentos)' do
    get '/documentos', headers: auth_headers
    expect(response).to have_http_status(:ok)
  end

  it 'GET /sedes → 403 (Ola 5: abogado pierde acceso a sedes directas)' do
    get '/sedes', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end
