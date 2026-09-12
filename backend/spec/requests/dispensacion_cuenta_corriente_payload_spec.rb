require 'rails_helper'

# LA CUENTA CORRIENTE VIAJA CON LA DISPENSA.
#
# El modal de edición la recibía por props y el HISTORIAL no se las pasaba (la ficha del paciente
# sí): al paciente con crédito recién habilitado, el desplegable le decía "Cuenta corriente (sin
# límite configurado)" y no lo dejaba elegirla, desde una puerta sí y desde la otra no. Un dato del
# paciente no puede depender de por qué pantalla se abrió el modal.
RSpec.describe 'La CC del paciente en el payload de la dispensa', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, precio_sugerido_ars: 1_000)
  end

  def json = JSON.parse(response.body)

  before do
    sign_in_as(admin)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'transferencia',
                                   fecha_dispensacion: Time.zone.today.to_s } },
         headers: auth_headers, as: :json
  end

  context 'el paciente tiene crédito habilitado' do
    let!(:cc) do
      CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: -2_000,
                              limite_credito: 50_000)
    end

    it 'el historial lo dice' do
      get '/dispensaciones', params: { fecha: Time.zone.today.to_s }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      d = json['dispensaciones'].first
      expect(d['paciente_limite_cc']).to eq(50_000.0)
      expect(d['paciente_saldo_cc']).to eq(-2_000.0)
    end

    it 'y también la ficha del paciente' do
      get "/pacientes/#{paciente.id}/dispensaciones", headers: auth_headers
      expect(json['dispensaciones'].first['paciente_limite_cc']).to eq(50_000.0)
    end
  end

  context 'el paciente NO tiene cuenta corriente' do
    it 'viaja en nil, que es lo que apaga la opción' do
      get '/dispensaciones', params: { fecha: Time.zone.today.to_s }, headers: auth_headers
      expect(json['dispensaciones'].first['paciente_limite_cc']).to be_nil
    end
  end
end
