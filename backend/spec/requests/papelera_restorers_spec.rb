require 'rails_helper'

# Fase 3 — restauración de entidades complejas vía Restorer con validación de conflictos.
# Política del proyecto: bloquear con motivos, nunca forzar.
RSpec.describe 'Papelera — restauración con validación (Restorers)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  describe 'CostoLote' do
    let(:lote) { create(:lote, club: club) }

    it 'restaura el costo cuando el lote sigue existiendo' do
      costo = CostoLote.create!(club: club, lote: lote, costo_total: 1500)
      costo.destroy
      sign_in_as(admin)

      post '/papelera/restaurar', params: { tipo: 'costo_lote', id: costo.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(CostoLote.where(id: costo.id)).to exist
    end

    it 'bloquea con motivo si el lote fue eliminado' do
      costo = CostoLote.create!(club: club, lote: lote, costo_total: 1500)
      costo.destroy
      lote.soft_delete!
      sign_in_as(admin)

      post '/papelera/restaurar', params: { tipo: 'costo_lote', id: costo.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['conflictos'].map { |c| c['codigo'] }).to include('lote_inexistente')
      expect(CostoLote.where(id: costo.id)).to be_empty # NO se restauró
    end
  end

  describe 'AriccameRegistro' do
    it 'bloquea si el stock asociado ya no existe' do
      stock = create(:stock, club: club)
      reg = AriccameRegistro.create!(club: club, tipo: 'entrada_producto', estado: 'confirmado', stock: stock, payload: {})
      reg.destroy
      stock.destroy # soft-delete: la fila queda (FK ok) pero el default scope la oculta
      sign_in_as(admin)

      post '/papelera/restaurar', params: { tipo: 'ariccame_registro', id: reg.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['conflictos'].map { |c| c['codigo'] }).to include('stock_inexistente')
    end

    it 'restaura un registro sin referencias colgadas' do
      reg = AriccameRegistro.create!(club: club, tipo: 'entrada_producto', estado: 'confirmado', payload: {})
      reg.destroy
      sign_in_as(admin)

      post '/papelera/restaurar', params: { tipo: 'ariccame_registro', id: reg.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(AriccameRegistro.where(id: reg.id)).to exist
    end
  end
end
