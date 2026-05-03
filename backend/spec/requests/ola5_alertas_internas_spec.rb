require 'rails_helper'

RSpec.describe 'Ola 5 — AlertasInternas', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin,  club: club) }
  let(:medico) { create(:user, :medico, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }

  let!(:alerta) do
    create(:alerta_interna, club: club, creada_por: dispensador,
           tipo: 'paciente_creado_por_dispensador',
           mensaje: 'Dispensador Lucía creó al paciente Test')
  end

  context 'admin GET /alertas_internas' do
    before { sign_in_as(admin) }

    it 'devuelve 200 con las alertas del club' do
      get '/alertas_internas', headers: auth_headers
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data.map { |a| a['id'] }).to include(alerta.id)
    end

    it 'devuelve meta con count de no leídas' do
      get '/alertas_internas', headers: auth_headers
      meta = JSON.parse(response.body)['meta']
      expect(meta['no_leidas']).to be >= 1
    end
  end

  context 'médico GET /alertas_internas' do
    before { sign_in_as(medico) }

    it 'devuelve 403' do
      get '/alertas_internas', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'admin PATCH /alertas_internas/:id/marcar_leida' do
    before { sign_in_as(admin) }

    it 'marca la alerta como leída' do
      patch "/alertas_internas/#{alerta.id}/marcar_leida", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(alerta.reload.leida_at).to be_present
    end
  end
end
