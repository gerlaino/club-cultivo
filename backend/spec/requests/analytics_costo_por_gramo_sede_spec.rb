require 'rails_helper'

# $/gramo producido por sede: numerador = Σ CostoLote.costo_total, denominador =
# Σ Lote.rendimiento_real_g (gramos producidos, NO dispensados), agrupado por sede.
RSpec.describe 'Analytics — costo por gramo por sede', type: :request do
  include AuthHelpers

  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede_a) { create(:sede, club: club, created_by: admin, nombre: 'Sede A') }
  let(:sede_b) { create(:sede, club: club, created_by: admin, nombre: 'Sede B') }

  # Lote finalizado (no exige sala) con costo y rendimiento reales.
  def lote_con_costo(sede:, gramos:, costo:)
    lote = create(:lote, club: club, sede: sede, sala: nil, estado: 'finalizado', rendimiento_real_g: gramos)
    CostoLote.create!(club: club, lote: lote, costo_insumos: costo)
    lote
  end

  before { sign_in_as(admin) }

  describe 'GET /analytics/costo_por_gramo_sede' do
    it 'agrega costo y gramos por sede y calcula el $/g' do
      lote_con_costo(sede: sede_a, gramos: 100, costo: 1000)
      lote_con_costo(sede: sede_a, gramos: 100, costo: 3000) # Sede A: 4000 / 200 = 20 $/g
      lote_con_costo(sede: sede_b, gramos: 50,  costo: 500)  # Sede B: 500 / 50  = 10 $/g

      get '/analytics/costo_por_gramo_sede', headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      fila_a = body['sedes'].find { |s| s['sede_id'] == sede_a.id }
      expect(fila_a['gramos_producidos']).to eq(200.0)
      expect(fila_a['costo_total']).to eq(4000.0)
      expect(fila_a['costo_por_gramo']).to eq(20.0)
      expect(fila_a['lotes_con_costo']).to eq(2)

      # Total del club: (4000 + 500) / (200 + 50) = 18.0
      expect(body['total']['costo_por_gramo']).to eq(18.0)
      expect(body['total']['lotes_con_costo']).to eq(3)
    end

    it 'un lote con costo y sin rendimiento suma el costo con cero gramos (costo real de la sede)' do
      lote_con_costo(sede: sede_a, gramos: 0, costo: 2000)

      get '/analytics/costo_por_gramo_sede', headers: auth_headers
      fila = JSON.parse(response.body)['sedes'].find { |s| s['sede_id'] == sede_a.id }
      expect(fila['costo_total']).to eq(2000.0)
      expect(fila['gramos_producidos']).to eq(0.0)
      expect(fila['costo_por_gramo']).to be_nil # no se divide por cero
      expect(fila['lotes_sin_rendimiento']).to eq(1)
    end

    it 'no incluye lotes ni costos de otro club (aislamiento de tenant)' do
      otro_club  = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      otra_sede = lote_otro = nil
      ActsAsTenant.with_tenant(otro_club) do
        otra_sede  = create(:sede, club: otro_club, created_by: otro_admin)
        lote_otro  = create(:lote, club: otro_club, sede: otra_sede, sala: nil, estado: 'finalizado', rendimiento_real_g: 999)
        CostoLote.create!(club: otro_club, lote: lote_otro, costo_insumos: 99_999)
      end

      lote_con_costo(sede: sede_a, gramos: 100, costo: 1000)

      get '/analytics/costo_por_gramo_sede', headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['total']['lotes_con_costo']).to eq(1)
      expect(body['total']['costo_total']).to eq(1000.0)
      expect(body['sedes'].map { |s| s['sede_id'] }).not_to include(otra_sede.id)
    end

    it 'rechaza a un rol sin acceso a analítica' do
      dispensador = create(:user, :dispensador, club: club)
      sign_in_as(dispensador)
      get '/analytics/costo_por_gramo_sede', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
