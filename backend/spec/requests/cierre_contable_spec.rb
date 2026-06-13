require 'rails_helper'

# Cierre de período + auditoría + costos derivados del libro (2026-06)
RSpec.describe 'Cierre contable, auditoría y costos por lote', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  def crear_movimiento(fecha: Date.today, categoria: 'insumo', tipo: 'egreso', monto: 1_000, lote_id: nil)
    post '/movimientos_contables',
         params: { movimiento_contable: {
           tipo: tipo, categoria: categoria, descripcion: 'Test',
           monto_ars: monto, fecha: fecha.to_s, sede_id: sede.id, lote_id: lote_id,
         } },
         headers: auth_headers, as: :json
  end

  describe 'cierre de período' do
    it 'cierra hasta una fecha y lo informa en el dashboard' do
      post '/movimientos_contables/cerrar_periodo',
           params: { hasta: Date.today.to_s }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(club.reload.contabilidad_cerrada_hasta).to eq(Date.today)

      get '/movimientos_contables/dashboard', headers: auth_headers
      expect(response.parsed_body['contabilidad_cerrada_hasta']).to eq(Date.today.to_s)
    end

    it 'rechaza crear movimientos con fecha dentro del período cerrado' do
      club.update!(contabilidad_cerrada_hasta: Date.today)
      crear_movimiento(fecha: Date.today - 1)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rechaza editar y borrar movimientos del período cerrado' do
      crear_movimiento(fecha: Date.today - 10)
      mov = MovimientoContable.last
      club.update!(contabilidad_cerrada_hasta: Date.today - 5)

      patch "/movimientos_contables/#{mov.id}",
            params: { movimiento_contable: { monto_ars: 999 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      expect {
        delete "/movimientos_contables/#{mov.id}", headers: auth_headers, as: :json
      }.not_to change(MovimientoContable, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'permite movimientos posteriores al cierre' do
      club.update!(contabilidad_cerrada_hasta: Date.today - 30)
      crear_movimiento(fecha: Date.today)
      expect(response).to have_http_status(:created)
    end

    it 'reabrir levanta el cierre y queda auditado' do
      club.update!(contabilidad_cerrada_hasta: Date.today)
      expect {
        post '/movimientos_contables/reabrir_periodo', params: {}, headers: auth_headers, as: :json
      }.to change(Auditoria, :count).by(1)
      expect(club.reload.contabilidad_cerrada_hasta).to be_nil
    end

  end

  describe 'auditoría de movimientos' do
    it 'registra crear, actualizar y eliminar con el usuario' do
      expect { crear_movimiento }.to change(Auditoria, :count).by(1)
      mov = MovimientoContable.last

      patch "/movimientos_contables/#{mov.id}",
            params: { movimiento_contable: { monto_ars: 2_000 } }, headers: auth_headers, as: :json

      delete "/movimientos_contables/#{mov.id}", headers: auth_headers, as: :json

      auditorias = Auditoria.de(mov).order(:id)
      expect(auditorias.map(&:accion)).to eq(%w[crear actualizar eliminar])
      expect(auditorias.last.user).to eq(admin)
      expect(auditorias.second.cambios['monto_ars']).to be_present
    end
  end

  describe 'costos del lote derivados del libro' do
    it 'crear un egreso con lote actualiza CostoLote automáticamente' do
      crear_movimiento(categoria: 'insumo', monto: 5_000, lote_id: lote.id)
      crear_movimiento(categoria: 'electricidad', monto: 3_000, lote_id: lote.id)

      costo = lote.reload.costo_lote
      expect(costo).to be_present
      expect(costo.costo_insumos.to_f).to eq(5_000.0)
      expect(costo.costo_energia.to_f).to eq(3_000.0)
      expect(costo.costo_total.to_f).to eq(8_000.0)
    end

    it 'borrar el egreso recalcula el costo' do
      crear_movimiento(categoria: 'insumo', monto: 5_000, lote_id: lote.id)
      mov = MovimientoContable.last
      delete "/movimientos_contables/#{mov.id}", headers: auth_headers, as: :json
      expect(lote.reload.costo_lote.costo_insumos.to_f).to eq(0.0)
    end

    it 'POST /lotes/:id/costo/recalcular deriva desde el libro' do
      crear_movimiento(categoria: 'sueldo', monto: 7_000, lote_id: lote.id)
      post "/lotes/#{lote.id}/costo/recalcular", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['costo_mano_obra']).to eq(7_000.0)
    end
  end
end

# Bloque aparte sin login de admin: los request specs no reemplazan la cookie
# de auth con un segundo sign_in_as dentro del mismo describe (gana el primero).
RSpec.describe 'Cierre contable — autorización', type: :request do
  let(:club)       { create(:club) }
  let(:cultivador) { create(:user, club: club, role: 'cultivador') }
  before { sign_in_as(cultivador) }

  it 'un no-admin no puede cerrar el período' do
    post '/movimientos_contables/cerrar_periodo',
         params: { hasta: Date.today.to_s }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
