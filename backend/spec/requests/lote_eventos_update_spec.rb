require 'rails_helper'

RSpec.describe 'PATCH /api/lotes/:lote_id/lote_eventos/:id', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  def crear_evento(tipo: 'nota')
    lote.lote_eventos.create!(
      tipo: tipo, descripcion: "ev-#{SecureRandom.hex(2)}",
      user: admin, club: club, registrado_en: Time.current,
      estado_nuevo: (tipo == 'cambio_estado' ? 'floracion' : nil)
    )
  end

  context 'como admin' do
    before { sign_in_as(admin) }

    it 'edita la descripción y la fecha de una nota' do
      ev = crear_evento(tipo: 'nota')
      nueva_fecha = 5.days.ago.to_date
      patch "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}",
            params: { lote_evento: { descripcion: '📝 Nota: corregida', registrado_en: "#{nueva_fecha}T12:00:00" } },
            as: :json
      expect(response).to have_http_status(:ok)
      ev.reload
      expect(ev.descripcion).to eq('📝 Nota: corregida')
      expect(ev.registrado_en.to_date).to eq(nueva_fecha)
    end

    it 'NO edita un evento cambio_estado (protege la historia de fases)' do
      ev = crear_evento(tipo: 'cambio_estado')
      patch "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}",
            params: { lote_evento: { descripcion: 'hackeo' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ev.reload.descripcion).not_to eq('hackeo')
    end

    it 'no permite cambiar el tipo ni el estado_nuevo (solo descripción/fecha)' do
      ev = crear_evento(tipo: 'nota')
      patch "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}",
            params: { lote_evento: { tipo: 'cambio_estado', estado_nuevo: 'floracion', descripcion: 'x' } },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(ev.reload.tipo).to eq('nota')
      expect(ev.estado_nuevo).to be_nil
    end
  end

  context 'como cultivador' do
    it 'responde 403 (solo admin edita)' do
      cult = create(:user, :cultivador, club: club)
      ev   = crear_evento(tipo: 'nota')
      sign_in_as(cult)
      patch "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}",
            params: { lote_evento: { descripcion: 'x' } }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
