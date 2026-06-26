require 'rails_helper'

RSpec.describe 'Papelera — restauración de Stock y Reserva', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  describe 'Stock' do
    let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

    it 'restaura el stock con sus movimientos' do
      stock.stock_movimientos.create!(tipo: 'produccion', gramos: 100, usuario: admin)
      stock.destroy
      expect(Stock.where(id: stock.id)).to be_empty

      post '/papelera/restaurar', params: { tipo: 'stock', id: stock.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(Stock.where(id: stock.id)).to exist
      expect(stock.reload.stock_movimientos.count).to eq(1) # volvió el movimiento (recursive)
    end

    it 'reabre el lote a curado si se había finalizado por stock agotado' do
      lote.update!(estado: 'curado')
      stock.destroy
      lote.update!(estado: 'finalizado') # como si el resto del stock se hubiera agotado

      post '/papelera/restaurar', params: { tipo: 'stock', id: stock.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(lote.reload.estado).to eq('curado') # reabierto
    end

    it 'bloquea si la sede fue eliminada' do
      stock.destroy
      sede.soft_delete!

      post '/papelera/restaurar', params: { tipo: 'stock', id: stock.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['conflictos'].map { |c| c['codigo'] }).to include('sede_inexistente')
    end
  end

  describe 'Reserva' do
    let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

    def crear_reserva(cantidad)
      Reserva.create!(club: club, paciente: paciente, stock: stock, user: admin, cantidad: cantidad, estado: 'pendiente', fecha_entrega_estimada: Date.tomorrow)
    end

    it 'restaura una reserva cuando hay stock libre' do
      r = crear_reserva(20)
      r.destroy

      post '/papelera/restaurar', params: { tipo: 'reserva', id: r.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(Reserva.where(id: r.id)).to exist
    end

    it 'bloquea si el stock libre ya no alcanza para re-reservar' do
      r = crear_reserva(80)
      r.destroy
      crear_reserva(60) # otra reserva consume gran parte del stock libre

      post '/papelera/restaurar', params: { tipo: 'reserva', id: r.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['conflictos'].map { |c| c['codigo'] }).to include('stock_insuficiente')
      expect(Reserva.where(id: r.id)).to be_empty
    end
  end
end
