require 'rails_helper'

# Reversión de compras de insumo, "en ambos lados":
#  - Depósito: DELETE /insumos/:id/compras/:compra_id
#  - Contabilidad: DELETE /movimientos_contables/:id del asiento de la compra
# Ambos revierten el stock y borran el asiento; se bloquean si la mercadería ya se consumió.
RSpec.describe 'Reversión de compras de insumo', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  def crear_insumo_con_compra(cantidad: 10, costo: 1000)
    insumo = club.insumos.create!(nombre: 'Fertilizante', unidad_medida: 'litro')
    compra = insumo.registrar_compra!(cantidad: cantidad, costo_total_ars: costo, created_by: admin)
    [insumo, compra]
  end

  describe 'DELETE /api/insumos/:id/compras/:compra_id' do
    it 'revierte el stock y borra el asiento contable asociado' do
      insumo, compra = crear_insumo_con_compra
      mov_id = compra.movimiento_contable_id
      expect(mov_id).to be_present

      expect {
        delete "/api/insumos/#{insumo.id}/compras/#{compra.id}", headers: auth_headers
      }.to change { insumo.reload.stock_actual }.from(10).to(0)

      expect(response).to have_http_status(:ok)
      expect(InsumoCompra.exists?(compra.id)).to be(false)
      expect(MovimientoContable.exists?(mov_id)).to be(false)
    end

    it 'bloquea con 422 si la mercadería ya se consumió' do
      insumo, compra = crear_insumo_con_compra
      insumo.registrar_consumo!(cantidad: 4, created_by: admin) # queda 6 < 10

      delete "/api/insumos/#{insumo.id}/compras/#{compra.id}", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/consumió|distribuyó/)
      expect(insumo.reload.stock_actual).to eq(6)     # no se tocó
      expect(InsumoCompra.exists?(compra.id)).to be(true)
    end
  end

  describe 'POST /api/insumos/:id/reconteo' do
    it 'corrección ajusta el stock sin tocar contabilidad' do
      insumo, = crear_insumo_con_compra(cantidad: 100)
      expect {
        post "/api/insumos/#{insumo.id}/reconteo",
             params: { nuevo_stock: 10, motivo: 'correccion' }, headers: auth_headers, as: :json
      }.to change { insumo.reload.stock_actual }.from(100).to(10)
      expect(response).to have_http_status(:ok)
    end

    it 'merma baja el stock y lo registra como salida' do
      insumo, = crear_insumo_con_compra(cantidad: 10)
      post "/api/insumos/#{insumo.id}/reconteo",
           params: { nuevo_stock: 7, motivo: 'merma', notas: 'vencido' }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(insumo.reload.stock_actual).to eq(7)
      expect(insumo.insumo_consumos.last.notas).to match(/Merma/)
    end
  end

  describe 'DELETE /api/insumos/:id' do
    it 'elimina el insumo y revierte los asientos de sus compras si no tuvo consumos' do
      insumo, compra = crear_insumo_con_compra
      mov_id = compra.movimiento_contable_id
      delete "/api/insumos/#{insumo.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(Insumo.exists?(insumo.id)).to be(false)
      expect(MovimientoContable.exists?(mov_id)).to be(false)
    end

    it 'bloquea con 422 si el insumo ya tuvo consumos (sugiere desactivar)' do
      insumo, = crear_insumo_con_compra
      insumo.registrar_consumo!(cantidad: 2, created_by: admin)
      delete "/api/insumos/#{insumo.id}", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/[Dd]esactiv/)
      expect(Insumo.exists?(insumo.id)).to be(true)
    end
  end

  describe 'DELETE /api/movimientos_contables/:id (asiento de la compra)' do
    it 'borrar el asiento revierte también el stock del insumo' do
      insumo, compra = crear_insumo_con_compra
      mov_id = compra.movimiento_contable_id

      expect {
        delete "/api/movimientos_contables/#{mov_id}", headers: auth_headers
      }.to change { insumo.reload.stock_actual }.from(10).to(0)

      expect(response).to have_http_status(:no_content)
      expect(MovimientoContable.exists?(mov_id)).to be(false)
      expect(InsumoCompra.exists?(compra.id)).to be(false)
    end

    it 'bloquea el borrado del asiento si la mercadería ya se consumió' do
      insumo, compra = crear_insumo_con_compra
      mov_id = compra.movimiento_contable_id
      insumo.registrar_consumo!(cantidad: 4, created_by: admin)

      delete "/api/movimientos_contables/#{mov_id}", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(insumo.reload.stock_actual).to eq(6)
      expect(MovimientoContable.exists?(mov_id)).to be(true) # el asiento sigue vivo
    end
  end
end
