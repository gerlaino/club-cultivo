require 'rails_helper'

# AC: cambiar la FASE de una sala arrastra a los lotes de adentro, así que no puede pasar
# por accidente al editar la sala. La acción dedicada "Cambiar fase" ya avisaba; editar el
# `kind` hacía lo mismo en silencio.
RSpec.describe 'PATCH /api/salas/:id — cambio de fase', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }

  before { sign_in_as(admin) }

  def patch_sala(attrs)
    patch "/api/salas/#{sala.id}", params: { sala: { nombre: sala.nombre }.merge(attrs) }, as: :json
  end

  context 'con lotes en la fase que se abandona' do
    let!(:lote) { create(:lote, club: club, sala: sala, estado: 'floracion') }

    it 'NO guarda y devuelve los lotes afectados' do
      patch_sala(kind: 'vegetativo')

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['requiere_confirmacion']).to be(true)
      expect(body['lotes_afectados'].first).to include(
        'codigo' => lote.codigo, 'estado_actual' => 'floracion', 'estado_nuevo' => 'vegetativo'
      )
      expect(sala.reload.kind).to eq('floracion')
      expect(lote.reload.estado).to eq('floracion')
    end

    it 'con la confirmación explícita guarda y arrastra los lotes' do
      patch "/api/salas/#{sala.id}",
            params: { sala: { nombre: sala.nombre, kind: 'vegetativo' }, confirmar_cambio_fase: true },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(sala.reload.kind).to eq('vegetativo')
      expect(lote.reload.estado).to eq('vegetativo')
    end

    it 'informa cuántos días de fase pierde el lote' do
      lote.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club,
                               user: admin, registrado_en: 12.days.ago, descripcion: 'a floración')

      patch_sala(kind: 'vegetativo')

      expect(JSON.parse(response.body)['lotes_afectados'].first['dias_en_fase']).to eq(12)
    end
  end

  context 'sin lotes que cambien de fase' do
    it 'guarda directo' do
      patch_sala(kind: 'vegetativo')

      expect(response).to have_http_status(:ok)
      expect(sala.reload.kind).to eq('vegetativo')
    end

    it 'no pide confirmación por cambios que no son de fase' do
      create(:lote, club: club, sala: sala, estado: 'floracion')

      patch_sala(nombre: 'Sala renombrada')

      expect(response).to have_http_status(:ok)
      expect(sala.reload.nombre).to eq('Sala renombrada')
    end
  end

  context 'lotes enraizando' do
    # La misma guarda que ya tenía la acción "Cambiar fase": en 12/12 un esqueje no prende.
    it 'no deja pasar la sala a floración' do
      sala_veg = create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo')
      create(:lote, club: club, sala: sala_veg, estado: 'enraizado')

      patch "/api/salas/#{sala_veg.id}",
            params: { sala: { nombre: sala_veg.nombre, kind: 'floracion' }, confirmar_cambio_fase: true },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/enraizando/i)
      expect(sala_veg.reload.kind).to eq('vegetativo')
    end
  end
end
