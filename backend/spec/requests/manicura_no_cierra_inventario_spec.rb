require 'rails_helper'

# Decisión de Germán (15-ago-2026): "manicura no debería poder cerrar inventario".
#
# Salió de auditar los guards: `manicura` estaba en `ROLES_ESCRITURA_STOCK` desde mayo, así que
# por API podía finalizar un stock —y desde ago-2026 hasta declararlo "vendido"— cuando ninguna
# de sus pantallas escribe stock. Su trabajo es PESAR: el contenedor lo crea y lo confirma
# admin o supervisor (`pesajes_manicura#confirmar` y `#registrar_directo`, que ya lo exigían).
#
# Lo que sigue pudiendo es LEER: necesita ver a qué contenedor va lo que pesa.
RSpec.describe 'El manicura no cierra inventario', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:manicurador) { create(:user, club: club, role: 'manicura') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:stock)       { create(:stock, club: club, sede: sede, cantidad: 500, estado: 'asignado') }

  describe 'sobre el stock' do
    before { sign_in_as(manicurador) }

    it 'no puede finalizarlo' do
      post "/stocks/#{stock.id}/descartar", params: { motivo: 'destruido' }, headers: auth_headers

      expect(response).to have_http_status(:forbidden)
      expect(stock.reload.cantidad).to eq(500)
    end

    it 'no puede ajustar la cantidad' do
      post "/stocks/#{stock.id}/ajuste",
           params: { cantidad_real: 10, motivo: 'reconteo' }, headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'no puede asignarlo a una sede' do
      post "/stocks/#{stock.id}/asignar", params: { sede_id: sede.id }, headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end

    # Lo que SÍ necesita para trabajar: ver los contenedores del lote que está pesando.
    it 'pero lo sigue viendo' do
      get '/stocks', headers: auth_headers

      expect(response).to have_http_status(:ok)
    end
  end

  # El contenedor lo crea y lo llena quien confirma el pesaje, que ya era admin o supervisor.
  # Esta es la prueba de que sacarle la escritura no le rompe el trabajo.
  describe 'el flujo de manicura sigue andando' do
    let(:lote) do
      create(:lote, club: club, estado: 'en_manicura', manicurador: manicurador,
                    sala: create(:sala, club: club, sede: sede, created_by: admin))
    end

    it 'el manicura pesa y envía; el admin confirma y ahí nace el stock' do
      plantas = create_list(:plant, 2, lote: lote, club: club, state: 'cosechado')

      pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador,
                                             fecha_pesaje: Date.current)
      plantas.each { |p| pesaje.pesadas_plantas.create!(plant: p, peso_seco_g: 50) }
      pesaje.enviar!

      expect {
        pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 100)
      }.to change(Stock, :count).by(1)
    end
  end
end
