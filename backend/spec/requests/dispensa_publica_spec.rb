require 'rails_helper'

RSpec.describe 'Pasaporte público de dispensa (/d/:token)', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:genetica) { Genetica.create!(club: club, nombre: 'OG Kush', tipo: 'hibrida', thc: 22.5, cbd: 0.8, terpenos: 'mirceno, limoneno', slug: "og-#{SecureRandom.hex(3)}") }
  let(:lote)     { create(:lote, club: club, sala: sala, genetica: genetica, codigo: 'L-OG-1') }
  let(:paciente) { create(:paciente, club: club, created_by: admin, dni: '30.111.222') }
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, genetica: genetica, origen: 'lote',
                  forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
  end

  def dispensar
    Dispensacion.create!(paciente: paciente, user: admin, stock: stock, cantidad: 10,
                         fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo')
  end

  describe 'al crear la dispensa' do
    it 'genera token y snapshot del producto' do
      d = dispensar
      expect(d.token).to be_present
      expect(d.producto_snapshot['genetica']['nombre']).to eq('OG Kush')
      expect(d.producto_snapshot['genetica']['thc_pct']).to eq(22.5)
      expect(d.producto_snapshot['forma_producto']).to eq('flor_seca')
    end

    it 'el snapshot sobrevive al borrado del stock' do
      d = dispensar
      stock.destroy   # dependent: :nullify deja la dispensa sin stock
      d.reload
      expect(d.stock).to be_nil
      expect(d.producto_snapshot['genetica']['nombre']).to eq('OG Kush')
    end
  end

  describe 'GET /d/:token (preview)' do
    it 'devuelve el club sin pedir DNI' do
      d = dispensar
      get "/d/#{d.token}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig('club', 'nombre')).to eq(club.name)
    end

    it '404 si el token no existe' do
      get '/d/inexistente'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /d/:token/ver (gate DNI)' do
    it 'con DNI correcto devuelve el pasaporte' do
      d = dispensar
      post "/d/#{d.token}/ver", params: { dni: '30111222' }, as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig('genetica', 'nombre')).to eq('OG Kush')
      expect(body.dig('genetica', 'thc_pct')).to eq(22.5)
      expect(body['cantidad']).to eq(10.0)
      expect(body['socio_numero']).to eq(paciente.id)
    end

    it 'acepta el DNI con puntos (normaliza)' do
      d = dispensar
      post "/d/#{d.token}/ver", params: { dni: '30.111.222' }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'con DNI incorrecto responde 401 y no expone datos' do
      d = dispensar
      post "/d/#{d.token}/ver", params: { dni: '99999999' }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('OG Kush')
    end
  end
end
