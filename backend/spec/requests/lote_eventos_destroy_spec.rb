require 'rails_helper'

RSpec.describe 'DELETE /api/lotes/:lote_id/lote_eventos/:id', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  def crear_evento(tipo: 'nota', lote_de: lote, club_de: club, user: admin)
    lote_de.lote_eventos.create!(
      tipo: tipo, descripcion: "ev-#{SecureRandom.hex(2)}",
      user: user, club: club_de, registrado_en: Time.current,
      estado_nuevo: (tipo == 'cambio_estado' ? 'floracion' : nil)
    )
  end

  context 'como admin' do
    before { sign_in_as(admin) }

    it 'borra un evento informativo (nota)' do
      ev = crear_evento(tipo: 'nota')
      delete "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}", as: :json
      expect(response).to have_http_status(:no_content)
      expect(LoteEvento.exists?(ev.id)).to be(false)
    end

    it 'NO borra el cambio_estado de la fase ACTUAL (protege la fase vigente)' do
      lote.update!(estado: 'floracion')
      ev = crear_evento(tipo: 'cambio_estado')             # estado_nuevo: 'floracion' == actual
      delete "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}", as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(LoteEvento.exists?(ev.id)).to be(true)
    end

    it 'SÍ borra un cambio_estado que NO es la fase actual (transición accidental)' do
      lote.update!(estado: 'cosecha')
      ev = crear_evento(tipo: 'cambio_estado')             # estado_nuevo: 'floracion' != cosecha
      delete "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}", as: :json
      expect(response).to have_http_status(:no_content)
      expect(LoteEvento.exists?(ev.id)).to be(false)
    end
  end

  context 'como cultivador' do
    it 'responde 403 (solo admin borra)' do
      cult = create(:user, :cultivador, club: club)
      ev   = crear_evento(tipo: 'nota')
      sign_in_as(cult)
      delete "/api/lotes/#{lote.id}/lote_eventos/#{ev.id}", as: :json
      expect(response).to have_http_status(:forbidden)
      expect(LoteEvento.exists?(ev.id)).to be(true)
    end
  end

  context 'aislamiento de tenant' do
    it 'no permite borrar un evento de otro club' do
      otro_club  = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      otra_sala  = create(:sala, club: otro_club)
      otro_lote  = create(:lote, club: otro_club, sala: otra_sala)
      ev = crear_evento(tipo: 'nota', lote_de: otro_lote, club_de: otro_club, user: otro_admin)

      sign_in_as(admin)
      delete "/api/lotes/#{otro_lote.id}/lote_eventos/#{ev.id}", as: :json

      expect(response).to have_http_status(:not_found)
      expect(LoteEvento.exists?(ev.id)).to be(true)
    end
  end
end
