require 'rails_helper'

RSpec.describe 'Delivery role pacientes restriction', type: :request do
  let!(:club)     { create(:club) }
  let!(:admin)    { create(:user, :admin,    club: club) }
  let!(:delivery) { create(:user, :delivery, club: club) }
  let!(:paciente) { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(delivery) }

  it 'GET /pacientes → 403' do
    get '/pacientes', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /pacientes/:id → 403' do
    get "/pacientes/#{paciente.id}", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /sedes → 200 (delivery can still access sedes)' do
    get '/sedes', headers: auth_headers
    expect(response).to have_http_status(:ok)
  end
end
