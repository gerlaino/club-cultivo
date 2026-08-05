require 'rails_helper'

# AC: el dispensador está en el mostrador y es quien recibe la mercadería, así que puede
# CARGARLA con su costo (queda el egreso a su nombre) y vender algo que todavía no está en el
# catálogo. Lo que NO puede es subir stock sin plata ni tocar precios del catálogo.
RSpec.describe 'Stock del Buffet desde el mostrador', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:bar)         { club.bares.create!(nombre: 'Buffet', sede: sede) }
  let!(:producto) do
    bar.bar_productos.create!(club: club, nombre: 'Gaseosa', categoria: 'bebida',
                              precio_ars: 1000, stock: 5, costo_ars: 400)
  end

  before { club.update!(features: (club.features || {}).merge('bar' => true)) }

  describe 'comprar (cantidad + gasto)' do
    it 'el dispensador carga la compra: sube stock, costo promedio y deja el egreso' do
      sign_in_as(dispensador)

      expect {
        post "/api/bares/#{bar.id}/productos/#{producto.id}/comprar",
             params: { cantidad: 5, costo_total_ars: 3000 }, as: :json
      }.to change { club.movimientos_contables.where(tipo: 'egreso').count }.by(1)

      expect(response).to have_http_status(:created)
      producto.reload
      expect(producto.stock).to eq(10)
      # (5 × 400 + 3000) / 10 = 500
      expect(producto.costo_ars).to eq(500)

      egreso = club.movimientos_contables.where(tipo: 'egreso').last
      expect(egreso.monto_ars).to eq(3000)
      expect(egreso.created_by_id).to eq(dispensador.id), 'el egreso queda a nombre de quien lo cargó'
    end

    it 'rechaza una compra sin costo' do
      sign_in_as(dispensador)

      post "/api/bares/#{bar.id}/productos/#{producto.id}/comprar",
           params: { cantidad: 5, costo_total_ars: 0 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(producto.reload.stock).to eq(5)
    end
  end

  describe 'reponer sin costo' do
    it 'el dispensador NO puede subir stock sin plata' do
      sign_in_as(dispensador)

      post "/api/bares/#{bar.id}/productos/#{producto.id}/reponer", params: { cantidad: 10 }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(producto.reload.stock).to eq(5)
    end
  end

  describe 'catálogo' do
    it 'el dispensador no puede cambiar el precio de un producto' do
      sign_in_as(dispensador)

      patch "/api/bares/#{bar.id}/productos/#{producto.id}",
            params: { bar_producto: { precio_ars: 1 } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(producto.reload.precio_ars).to eq(1000)
    end

    it 'pero sí puede ponerle el código de barras' do
      sign_in_as(dispensador)

      patch "/api/bares/#{bar.id}/productos/#{producto.id}/codigo_barras",
            params: { codigo_barras: '779123456789' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(producto.reload.codigo_barras).to eq('779123456789')
      expect(producto.precio_ars).to eq(1000)
    end
  end

  describe 'venta suelta (producto fuera del listado)' do
    it 'registra la venta y su ingreso sin tocar el inventario' do
      sign_in_as(dispensador)

      expect {
        post "/api/bares/#{bar.id}/ventas",
             params: { lineas: [{ nombre: 'Alfajor', cantidad: 2, precio_unitario_ars: 900 }],
                       medio_pago: 'efectivo' }, as: :json
      }.to change { club.movimientos_contables.where(tipo: 'ingreso').count }.by(1)

      expect(response).to have_http_status(:created)
      venta = bar.bar_ventas.last
      expect(venta.total_ars).to eq(1800)

      item = venta.items.last
      expect(item.nombre).to eq('Alfajor')
      expect(item.vendible).to be_nil, 'la línea suelta no sale de ningún depósito'
      expect(producto.reload.stock).to eq(5)
    end

    it 'exige precio' do
      sign_in_as(dispensador)

      post "/api/bares/#{bar.id}/ventas",
           params: { lineas: [{ nombre: 'Alfajor', cantidad: 1 }] }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'convive con una línea normal en la misma venta', :aggregate_failures do
      sign_in_as(dispensador)

      post "/api/bares/#{bar.id}/ventas",
           params: { lineas: [
             { vendible_type: 'BarProducto', vendible_id: producto.id, cantidad: 1 },
             { nombre: 'Alfajor', cantidad: 1, precio_unitario_ars: 900 },
           ] }, as: :json

      expect(response).to have_http_status(:created)
      venta = bar.bar_ventas.last
      expect(venta.total_ars).to eq(1900)
      expect(producto.reload.stock).to eq(4), 'la línea con producto sí descuenta'
    end
  end
end
