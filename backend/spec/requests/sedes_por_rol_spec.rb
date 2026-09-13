require 'rails_helper'

# CADA ROL SÓLO SE ASIGNA A LAS SEDES DONDE TIENE ALGO QUE HACER (Germán, 13-sep-2026): un cultivador
# no va a un dispensario ni un dispensador a una finca. La regla vive en `Sede::TIPOS_POR_ROL`, la
# aplica `UserSede` (por API se saltea siempre) y viaja en `/me` para que la pantalla ofrezca sólo eso.
RSpec.describe 'A qué sedes se asigna cada rol', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:finca)  { create(:sede, club: club, created_by: admin, nombre: 'Finca', tipo: 'produccion') }
  let(:disp)   { create(:sede, club: club, created_by: admin, nombre: 'Dispensario', tipo: 'social') }
  let(:mixta)  { create(:sede, club: club, created_by: admin, nombre: 'Central', tipo: 'mixta') }

  before { sign_in_as(admin) }

  def asignar(user, sede)
    post "/api/usuarios/#{user.id}/asignar_sede", params: { sede_id: sede.id }
    response
  end

  it 'un cultivador va a producción o mixta, no a un dispensario' do
    cul = create(:user, :cultivador, club: club)
    expect(asignar(cul, finca)).to have_http_status(:ok)
    expect(asignar(cul, mixta)).to have_http_status(:ok)
    expect(asignar(cul, disp)).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/cultivador no se asigna a una sede de dispensario/i)
  end

  it 'un dispensador va a un dispensario o mixta, no a una finca' do
    d = create(:user, :dispensador, club: club)
    expect(asignar(d, disp)).to have_http_status(:ok)
    expect(asignar(d, finca)).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/dispensador no se asigna a una sede de producción/i)
  end

  it 'la regla viaja en /me para que la pantalla ofrezca sólo eso' do
    get '/api/me'
    reglas = JSON.parse(response.body).dig('reglas_cultivo', 'sedes_por_rol')
    expect(reglas['cultivador']).to eq(%w[produccion mixta])
    expect(reglas['dispensador']).to eq(%w[social mixta])
  end
end
