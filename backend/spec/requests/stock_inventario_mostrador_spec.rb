require 'rails_helper'

# EL INVENTARIO NO PUEDE CONTRADECIRSE CONSIGO MISMO.
#
# El KPI de arriba sumaba la cantidad menos lo reservado y la columna «Actual» restaba ADEMÁS la
# mesa: con el frasco entero cargado al mostrador, la pantalla decía "18.0g de flor seca
# disponible" arriba y "0.0g" en rojo abajo, en el único renglón. El socio de Germán lo mandó así:
# "El stock está, pero no lo muestra en el listado. Está en mostrador".
#
# La mesa es un LUGAR, no un compromiso —administración dispensa igual de un frasco que está
# arriba— así que no se resta de lo disponible: se DICE, en su propia columna.
RSpec.describe 'GET /stocks/inventario — dónde está el producto', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'social') }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 18, precio_sugerido_ars: 1_000)
  end

  def json = JSON.parse(response.body)
  def fila  = json['stocks'].find { |s| s['id'] == stock.id }

  def cargar_mesa(cantidad, de: stock)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                               cambios: [{ stock_id: de.id, cantidad: cantidad }],
                               motivo: 'Carga del día')
    end
  end

  before { sign_in_as(admin) }

  context 'el frasco entero está sobre la mesa' do
    before { cargar_mesa(18) }

    it 'el KPI y la columna dicen lo mismo: 18' do
      get '/stocks/inventario', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json['totales']['total_g'].to_f).to eq(18.0)
      expect(fila['disponible_para_entregar'].to_f).to eq(18.0)
    end

    it 'y la fila dice DÓNDE está' do
      get '/stocks/inventario', headers: auth_headers
      expect(fila['en_mostrador_g'].to_f).to eq(18.0)
    end
  end

  context 'nada sobre la mesa' do
    it 'la columna viaja en cero, no ausente: un número que aparece de la nada no se mira' do
      get '/stocks/inventario', headers: auth_headers
      expect(fila['en_mostrador_g'].to_f).to eq(0.0)
      expect(fila['disponible_para_entregar'].to_f).to eq(18.0)
    end
  end

  context 'lo reservado a nombre de un paciente' do
    it 'SÍ baja lo disponible, esté o no sobre la mesa' do
      paciente = create(:paciente, club: club, created_by: admin)
      cargar_mesa(18)
      Reserva.create!(club: club, paciente: paciente, user: admin, stock: stock, cantidad: 5,
                      fecha_entrega_estimada: 3.days.from_now.to_date)

      get '/stocks/inventario', headers: auth_headers
      expect(fila['disponible_para_entregar'].to_f).to eq(13.0)
      expect(json['totales']['total_g'].to_f).to eq(13.0)
      expect(fila['en_mostrador_g'].to_f).to eq(18.0) # sigue habiendo 18 g arriba
    end
  end

  describe 'ordenar por la columna Mostrador' do
    let!(:otro) do
      Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                    unidad: 'g', cantidad: 500, precio_sugerido_ars: 1_000)
    end

    it 'pone arriba lo que más tiene sobre la mesa, no el frasco más grande' do
      cargar_mesa(18)                 # el chico está entero arriba
      cargar_mesa(10, de: otro)       # el grande casi no

      get '/stocks/inventario', params: { orden: 'mostrador', dir: 'desc' }, headers: auth_headers
      expect(json['stocks'].map { |s| s['id'] }.first).to eq(stock.id)
    end
  end
end
