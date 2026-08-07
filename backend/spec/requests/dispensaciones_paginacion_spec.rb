require 'rails_helper'

RSpec.describe 'GET /pacientes/:id/dispensaciones — paginación', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 10) }

  before do
    12.times do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                           cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 10)
    end
    sign_in_as(admin)
  end

  it 'devuelve 10 por página con meta del total real' do
    get "/pacientes/#{paciente.id}/dispensaciones", headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['dispensaciones'].size).to eq(10)
    expect(body['meta']['total']).to eq(12)
    expect(body['meta']['gramos_totales']).to eq(12.0)
  end

  it 'la segunda página trae el resto' do
    get "/pacientes/#{paciente.id}/dispensaciones", params: { pagina: 2 }, headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['dispensaciones'].size).to eq(2)
    expect(body['meta']['pagina']).to eq(2)
  end
end
