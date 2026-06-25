require 'rails_helper'

# Flujo unificado de manicura. El estado legacy `manicura_pendiente` ya no se usa:
# el manicura carga pesajes (PesajeManicura) y el admin los confirma en Manicura.
# La aprobación/rechazo legacy (aprobar_manicura / rechazar_manicura) fue retirada.
RSpec.describe 'Scope de manicura (flujo unificado)', type: :request,
  skip: 'Flujo viejo (secado + cerrar_curado). Reemplazado por PesajeManicura; scope cubierto por specs nuevos.' do
  include AuthHelpers

  let!(:club)     { create(:club) }
  let!(:admin)    { create(:user, :admin, club: club) }
  let!(:manicura) { create(:user, :manicura, club: club) }
  let!(:sede)     { create(:sede, club: club) }
  let!(:sala_sec) { create(:sala, sede: sede, tipo: 'secado') }

  let!(:lote_secado) do
    create(:lote, club: club, sala: sala_sec, estado: 'secado')
  end
  let!(:lote_en_manicura) do
    create(:lote, club: club, sala: sala_sec, estado: 'en_manicura', manicurador: manicura)
  end

  let(:auth_headers) { {} }

  # ── Scope manicura ────────────────────────────────────────────
  describe 'GET /lotes — scope manicura' do
    before { sign_in_as(manicura) }

    it 'devuelve secado y en_manicura propios, no curado ni cosecha' do
      sala_cur = create(:sala, sede: sede, tipo: 'curado')
      create(:lote, club: club, sala: sala_cur, estado: 'curado')
      create(:lote, club: club, sala: sala_sec, estado: 'cosecha')

      get '/lotes', headers: auth_headers
      body    = JSON.parse(response.body)
      estados = body.map { |l| l['estado'] }.sort
      expect(estados).to include('secado', 'en_manicura')
      expect(estados).not_to include('curado', 'cosecha')
    end
  end

  # ── cerrar_curado solo admin ─────────────────────────────────
  describe 'POST /lotes/:id/cerrar_curado' do
    let!(:sala_cur)    { create(:sala, sede: sede, tipo: 'curado') }
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
