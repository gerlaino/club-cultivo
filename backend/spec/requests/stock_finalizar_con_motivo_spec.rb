require 'rails_helper'

# AC (Germán): un club que sólo contrató la parte productiva no tiene a quién dispensarle, y su
# única salida era descartar — que lo anotaba como MERMA. O sea: entregarle producto a otra
# organización quedaba declarado como producto destruido.
#
# Ahora el cierre pregunta QUÉ PASÓ, y sólo "destruido" es una pérdida. El resto son salidas: el
# producto existe, está en otro lado.
RSpec.describe 'POST /stocks/:id/descartar — finalizar diciendo qué pasó', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:stock) { create(:stock, club: club, sede: sede, cantidad: 500, estado: 'asignado') }

  before { sign_in_as(admin) }

  def finalizar(motivo:, detalle: nil)
    post "/stocks/#{stock.id}/descartar",
         params: { motivo: motivo, detalle: detalle }.compact, headers: auth_headers
  end

  def movimiento
    stock.stock_movimientos.order(:id).last
  end

  describe 'lo que salió entero' do
    it 'una entrega a otra organización NO es merma' do
      finalizar(motivo: 'entregado')

      expect(response).to have_http_status(:ok), response.body
      expect(movimiento.tipo).to eq('salida')
    end

    %w[vendido regalado uso_interno].each do |motivo|
      it "#{motivo} tampoco" do
        finalizar(motivo: motivo)

        expect(movimiento.tipo).to eq('salida')
      end
    end

    it 'guarda qué fue, en texto, para que se entienda sin conocer el código' do
      finalizar(motivo: 'entregado', detalle: 'Club Los Andes · remito 0012')

      expect(movimiento.notas).to include('Entregado a otra organización')
      expect(movimiento.notas).to include('remito 0012')
    end
  end

  describe 'lo que se perdió' do
    it 'destruido sí es merma' do
      finalizar(motivo: 'destruido', detalle: 'hongos')

      expect(movimiento.tipo).to eq('merma')
    end
  end

  describe 'en los dos casos' do
    it 'el stock queda en cero y agotado' do
      finalizar(motivo: 'entregado')

      expect(stock.reload.cantidad).to eq(0)
      expect(stock.estado).to eq('agotado')
    end

    it 'descuenta lo que había' do
      finalizar(motivo: 'vendido')

      expect(movimiento.gramos.to_f).to eq(-500.0)
    end
  end

  # El motivo era texto libre y todo caía en merma. Que sea obligatorio y de una lista es lo que
  # permite que el informe de Pérdidas cuente sólo lo que de verdad se perdió.
  describe 'el motivo' do
    it 'es obligatorio' do
      post "/stocks/#{stock.id}/descartar", params: {}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(stock.reload.cantidad).to eq(500)
    end

    it 'no acepta cualquier texto: tiene que ser uno de la lista' do
      finalizar(motivo: 'se terminó')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/qué pasó/i)
    end
  end

  # La consecuencia que importa: el lote se finaliza cuando su stock llega a cero. Sin una salida
  # legítima, los lotes de un club sólo productivo quedaban abiertos para siempre.
  describe 'el lote' do
    it 'se finaliza cuando se cierra su último stock' do
      # En 'curado', que es donde está un lote que ya produjo: cultivo → cosecha → manicura →
      # curado → stock. `finalizar_si_stock_agotado!` sólo cierra desde ahí.
      lote = create(:lote, club: club, sede: sede, estado: 'curado', sala: nil)
      suyo = create(:stock, club: club, sede: sede, lote: lote, cantidad: 100, estado: 'asignado')

      post "/stocks/#{suyo.id}/descartar", params: { motivo: 'entregado' }, headers: auth_headers

      expect(response).to have_http_status(:ok), response.body
      expect(lote.reload.estado).to eq('finalizado')
    end
  end

  # El informe de Pérdidas cuenta `merma`. Si una entrega entrara ahí, declararía destruido algo
  # que está intacto en otro lado.
  describe 'el informe de Pérdidas' do
    it 'no cuenta lo que salió entero' do
      finalizar(motivo: 'entregado')

      merma = StockMovimiento.where(stock_id: stock.id, tipo: 'merma').sum(:gramos).to_f
      expect(merma).to eq(0.0)
    end
  end
end
