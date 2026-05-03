require 'rails_helper'

RSpec.describe 'DS-FIX-7 — Flujo aprobación manicura', type: :request do
  include AuthHelpers

  let!(:club)     { create(:club) }
  let!(:admin)    { create(:user, :admin, club: club) }
  let!(:manicura) { create(:user, :manicura, club: club) }
  let!(:sede)     { create(:sede, club: club) }
  let!(:sala_sec) { create(:sala, sede: sede, tipo: 'secado') }

  let!(:lote_secado) do
    create(:lote, club: club, sala: sala_sec, estado: 'secado')
  end
  let!(:lote_mnc_pend) do
    create(:lote, club: club, sala: sala_sec, estado: 'manicura_pendiente')
  end

  let(:auth_headers) { {} }

  # ── Scope manicura ────────────────────────────────────────────
  describe 'GET /lotes — scope manicura' do
    before { sign_in_as(manicura) }

    it 'devuelve secado y manicura_pendiente, no curado ni cosecha' do
      sala_cur  = create(:sala, sede: sede, tipo: 'curado')
      lote_cur  = create(:lote, club: club, sala: sala_cur, estado: 'curado')
      lote_cos  = create(:lote, club: club, sala: sala_sec, estado: 'cosecha')

      get '/lotes', headers: auth_headers
      body   = JSON.parse(response.body)
      estados = body.map { |l| l['estado'] }.sort
      expect(estados).to include('secado', 'manicura_pendiente')
      expect(estados).not_to include('curado', 'cosecha')
    end
  end

  # ── Transicion manicurado → manicura_pendiente ───────────────
  describe 'POST /lotes/:id/transiciones — manicura pesa lote en secado' do
    before { sign_in_as(manicura) }

    it 'transiciona a manicura_pendiente y crea alerta admin' do
      params = {
        nueva_fase:  'manicura_pendiente',
        pesada:      { peso_seco_g: 450, manicurado: true }
      }
      expect {
        post "/lotes/#{lote_secado.id}/transiciones", params: params, headers: auth_headers
      }.to change(AlertaInterna, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['estado']).to eq('manicura_pendiente')

      alerta = AlertaInterna.last
      expect(alerta.tipo).to eq('manicura_aprobacion_pendiente')
      expect(alerta.destinada_a_role).to eq('admin')
    end
  end

  # ── Aprobar manicura ─────────────────────────────────────────
  describe 'POST /lotes/:id/aprobar_manicura' do
    context 'admin aprueba' do
      before do
        sign_in_as(admin)
        # Necesita pesada de manicura previa
        lote_mnc_pend.pesadas.create!(
          fase_origen: 'secado', fase_destino: 'manicura_pendiente',
          manicurado: true, registrado_por: manicura,
          registrado_at: Time.current, peso_seco_g: 400
        )
      end

      it 'transiciona a curado y crea alerta manicura' do
        expect {
          post "/lotes/#{lote_mnc_pend.id}/aprobar_manicura", headers: auth_headers
        }.to change(AlertaInterna, :count).by(1)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['estado']).to eq('curado')
        expect(lote_mnc_pend.reload.estado).to eq('curado')
      end
    end

    context 'manicura intenta aprobar' do
      before { sign_in_as(manicura) }

      it 'devuelve 404 (lote fuera del scope) o 403' do
        post "/lotes/#{lote_mnc_pend.id}/aprobar_manicura", headers: auth_headers
        expect([403, 404]).to include(response.status)
      end
    end
  end

  # ── Rechazar manicura ────────────────────────────────────────
  describe 'POST /lotes/:id/rechazar_manicura' do
    before do
      sign_in_as(admin)
      lote_mnc_pend.pesadas.create!(
        fase_origen: 'secado', fase_destino: 'manicura_pendiente',
        manicurado: true, registrado_por: manicura,
        registrado_at: Time.current, peso_seco_g: 400
      )
    end

    it 'devuelve el lote a secado y crea alerta manicura' do
      expect {
        post "/lotes/#{lote_mnc_pend.id}/rechazar_manicura",
             params: { motivo: 'Peso insuficiente' }, headers: auth_headers
      }.to change(AlertaInterna, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['estado']).to eq('secado')

      alerta = AlertaInterna.last
      expect(alerta.tipo).to eq('manicura_rechazada')
      expect(alerta.destinada_a_role).to eq('manicura')
    end

    it 'sin motivo devuelve 4xx' do
      post "/lotes/#{lote_mnc_pend.id}/rechazar_manicura", headers: auth_headers
      expect(response.status).to be_between(400, 422)
    end
  end

  # ── cerrar_curado solo admin ─────────────────────────────────
  describe 'POST /lotes/:id/cerrar_curado' do
    let!(:sala_cur) { create(:sala, sede: sede, tipo: 'curado') }
    let!(:lote_curado) { create(:lote, club: club, sala: sala_cur, estado: 'curado') }

    context 'manicura' do
      before { sign_in_as(manicura) }
      it 'devuelve 404 (curado fuera del scope de manicura)' do
        post "/lotes/#{lote_curado.id}/cerrar_curado", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
