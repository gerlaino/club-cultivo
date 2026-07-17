require 'rails_helper'

RSpec.describe 'CuentaCorrientes API', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin,       club: club) }
  let(:otro_rol) { create(:user, :cultivador,  club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  # ── GET /pacientes/:id/cuenta_corriente ─────────────────────────────────────

  describe 'GET /pacientes/:id/cuenta_corriente' do
    context 'admin autenticado' do
      before { sign_in_as(admin) }

      it 'devuelve 200 con saldo 0 cuando el paciente no tiene CC' do
        get "/pacientes/#{paciente.id}/cuenta_corriente", headers: auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['saldo_disponible']).to eq(0.0)
        expect(body['movimientos']).to eq([])
      end

      it 'devuelve el saldo real cuando existe la CC' do
        create(:cuenta_corriente, paciente: paciente, club: club,
               saldo_disponible: 750, limite_credito: 1000)
        get "/pacientes/#{paciente.id}/cuenta_corriente", headers: auth_headers
        body = JSON.parse(response.body)
        expect(body['saldo_disponible']).to eq(750.0)
        expect(body['limite_credito']).to eq(1000.0)
      end

      it 'incluye los últimos movimientos' do
        cc = create(:cuenta_corriente, paciente: paciente, club: club,
                    saldo_disponible: 500, limite_credito: 500)
        CuentaCorrienteMovimiento.create!(
          cuenta_corriente: cc, tipo: 'carga', monto: 500,
          saldo_anterior: 0, saldo_nuevo: 500,
          descripcion: 'Carga test', created_by: admin
        )
        get "/pacientes/#{paciente.id}/cuenta_corriente", headers: auth_headers
        body = JSON.parse(response.body)
        expect(body['movimientos'].length).to eq(1)
        expect(body['movimientos'].first['tipo']).to eq('carga')
      end
    end

    context 'rol sin permiso' do
      it 'devuelve 403' do
        sign_in_as(otro_rol)
        get "/pacientes/#{paciente.id}/cuenta_corriente", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'paciente de otro club' do
      it 'devuelve 404' do
        otro_club    = create(:club)
        otro_paciente = ActsAsTenant.with_tenant(otro_club) { create(:paciente, club: otro_club, created_by: create(:user, :admin, club: otro_club)) }
        sign_in_as(admin)
        get "/pacientes/#{otro_paciente.id}/cuenta_corriente", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /pacientes/:id/cuenta_corriente/cargar ──────────────────────────────

  describe 'POST /pacientes/:id/cuenta_corriente/cargar' do
    before { sign_in_as(admin) }

    it 'crea la CC si no existe y carga el crédito' do
      expect {
        post "/pacientes/#{paciente.id}/cuenta_corriente/cargar",
             params: { monto: 500, descripcion: 'Carga inicial' },
             headers: auth_headers
      }.to change { CuentaCorriente.count }.by(1)
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['saldo_disponible']).to eq(500.0)
    end

    it 'acumula sobre un saldo existente' do
      create(:cuenta_corriente, paciente: paciente, club: club,
             saldo_disponible: 300, limite_credito: 300)
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar",
           params: { monto: 200 }, headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['saldo_disponible']).to eq(500.0)
    end

    it 'crea un movimiento tipo carga' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar",
           params: { monto: 100, descripcion: 'Desc test' }, headers: auth_headers
      cc = paciente.cuenta_corriente
      mov = cc.movimientos.first
      expect(mov.tipo).to eq('carga')
      expect(mov.monto.to_f).to eq(100.0)
      expect(mov.descripcion).to eq('Desc test')
    end

    it 'rechaza monto <= 0' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar",
           params: { monto: 0 }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rechaza monto negativo' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/cargar",
           params: { monto: -50 }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ── POST /pacientes/:id/cuenta_corriente/ajuste ──────────────────────────────

  describe 'POST /pacientes/:id/cuenta_corriente/ajuste' do
    before { sign_in_as(admin) }

    let!(:cc) { create(:cuenta_corriente, paciente: paciente, club: club,
                        saldo_disponible: 1000, limite_credito: 1000) }

    it 'aplica ajuste positivo' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/ajuste",
           params: { monto: 200 }, headers: auth_headers
      expect(response).to have_http_status(:created)
      expect(cc.reload.saldo_disponible).to eq(1200.0)
    end

    it 'aplica ajuste negativo' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/ajuste",
           params: { monto: -300 }, headers: auth_headers
      expect(cc.reload.saldo_disponible).to eq(700.0)
    end

    it 'el movimiento registra saldo anterior y nuevo correctamente' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/ajuste",
           params: { monto: -100 }, headers: auth_headers
      mov = cc.movimientos.first
      expect(mov.tipo).to eq('ajuste')
      expect(mov.saldo_anterior.to_f).to eq(1000.0)
      expect(mov.saldo_nuevo.to_f).to eq(900.0)
    end

    it 'rechaza monto == 0' do
      post "/pacientes/#{paciente.id}/cuenta_corriente/ajuste",
           params: { monto: 0 }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
