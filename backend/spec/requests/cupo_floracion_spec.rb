require 'rails_helper'

# AC (6-oct-2026, Germán): el tope de plantas del plan es de plantas EN FLORACIÓN (el vegetativo
# es libre) y es un CANDADO, también en el autocultivo (9). Las automáticas cuentan todo el ciclo.
# Al cupo se entra por varias puertas; acá se prueban por la API las que se usan todos los días.
RSpec.describe 'Cupo de plantas en floración', type: :request do
  let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club, kind: 'vegetativo', created_by: admin) }
  let(:flora) { create(:sala, club: club, kind: 'floracion', created_by: admin) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  def lote_en_vege(n)
    lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: n)
    n.times { |i| create(:plant, lote: lote, club: club, state: 'vegetativo', nombre: "#{lote.codigo}-#{i}") }
    lote
  end

  describe 'avanzar un lote a floración' do
    it 'con 10 plantas en el autocultivo, no: dice el tope y cuántas hay' do
      lote = lote_en_vege(10)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { sala_id: flora.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors'].join).to include('9 plantas en floración')
      expect(lote.reload.estado).to eq('vegetativo')
      expect(lote.plants.pluck(:state).uniq).to eq(%w[vegetativo])
    end

    it 'con 9, sí' do
      lote = lote_en_vege(9)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { sala_id: flora.id }, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(lote.reload.estado).to eq('floracion')
    end
  end

  # «Florece el espacio»: la puerta del teléfono. Las plantas se mueven antes que el lote.
  describe 'dar vuelta la fase del espacio' do
    it 'no deja florecer más de lo que entra, y no deja nada a medias' do
      lote = lote_en_vege(10)

      post "/api/salas/#{sala.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('9 plantas en floración')
      expect(sala.reload.kind).to eq('vegetativo')
      expect(lote.plants.reload.pluck(:state).uniq).to eq(%w[vegetativo])
    end
  end

  describe 'crear un lote' do
    it 'en vegetativo, libre' do
      post "/api/salas/#{sala.id}/lotes", params: { lote: { estado: 'vegetativo', plants_count: 30, start_date: Time.zone.today } }, as: :json

      expect(response).to have_http_status(:created), response.body
    end

    it 'directo en floración con más de lo que entra, no: 402 con el motivo' do
      post "/api/salas/#{flora.id}/lotes", params: { lote: { estado: 'floracion', plants_count: 12, start_date: Time.zone.today } }, as: :json

      expect(response).to have_http_status(:payment_required)
      expect(response.parsed_body['mensaje']).to include('9 plantas en floración')
    end
  end

  # El tope sigue al plan: la misma organización en «Hasta 50 pacientes» florece 450.
  it 'en una organización, el tope es el del escalón' do
    club.update!(plan: 'basico')
    lote = lote_en_vege(10)

    post "/api/lotes/#{lote.id}/avanzar_fase", params: { sala_id: flora.id }, as: :json

    expect(response).to have_http_status(:ok), response.body
  end
end
