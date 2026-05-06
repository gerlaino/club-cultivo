require 'rails_helper'

RSpec.describe 'CuentaCorriente — crédito en gramos', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(
      paciente: paciente, club: club,
      saldo_disponible: 0, limite_credito: 0,
      credito_gramos_activo: false
    )
  end

  before { sign_in_as(admin) }

  # ── toggle_gramos ──────────────────────────────────────────────────────────

  describe 'PATCH /cuenta_corriente/toggle_gramos' do
    it 'activa el crédito en gramos si estaba inactivo' do
      patch "/pacientes/#{paciente.id}/cuenta_corriente/toggle_gramos", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(cc.reload.credito_gramos_activo).to eq(true)
    end

    it 'desactiva el crédito en gramos si estaba activo' do
      cc.update!(credito_gramos_activo: true)
      patch "/pacientes/#{paciente.id}/cuenta_corriente/toggle_gramos", headers: auth_headers
      expect(cc.reload.credito_gramos_activo).to eq(false)
    end

    it 'responde con el campo credito_gramos_activo actualizado' do
      patch "/pacientes/#{paciente.id}/cuenta_corriente/toggle_gramos", headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['credito_gramos_activo']).to eq(true)
    end
  end

  # ── set_limite_g ───────────────────────────────────────────────────────────

  describe 'PATCH /cuenta_corriente/set_limite_g' do
    it 'establece el límite en gramos' do
      patch "/pacientes/#{paciente.id}/cuenta_corriente/set_limite_g",
            params: { limite_credito_g: 50 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(cc.reload.limite_credito_g.to_f).to eq(50.0)
    end

    it 'rechaza límite <= 0' do
      patch "/pacientes/#{paciente.id}/cuenta_corriente/set_limite_g",
            params: { limite_credito_g: 0 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ── cargar_g ───────────────────────────────────────────────────────────────

  describe 'POST /cuenta_corriente/cargar_g' do
    before { cc.update!(credito_gramos_activo: true, limite_credito_g: 100) }

    it 'carga gramos en el saldo disponible' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 30 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(30.0)
      body = JSON.parse(response.body)
      expect(body['saldo_disponible_g']).to eq(30.0)
    end

    it 'rechaza si gramos <= 0' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 0 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rechaza si el crédito en gramos no está activo' do
      cc.update!(credito_gramos_activo: false)
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 20 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/activá/i)
    end

    it 'rechaza si la carga excede el límite' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 150 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/límite/i)
    end

    it 'permite cargar hasta el límite exacto' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 100 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(100.0)
    end

    it 'carga acumulativa sin exceder el límite' do
      cc.update!(saldo_disponible_g: 60)
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 30 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(90.0)
    end

    it 'rechaza carga acumulativa que supera el límite' do
      cc.update!(saldo_disponible_g: 80)
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 30 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no aplica la restricción de límite si no hay límite configurado' do
      cc.update!(limite_credito_g: nil)
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar_g",
           params: { gramos: 999 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible_g.to_f).to eq(999.0)
    end
  end
end
