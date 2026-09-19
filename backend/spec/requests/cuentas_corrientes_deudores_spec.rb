require 'rails_helper'

# AC (Germán, 16-sep-2026): el KPI «Por cobrar» de Contabilidad lleva a una solapa Deudores con
# la lista completa de pacientes con cuenta corriente, ordenable por mayor deudor y con buscador.
# El total tiene que ser el MISMO que el KPI.
RSpec.describe 'Deudores (cuentas corrientes)', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def paciente_con_cc(nombre, saldo, limite: 50_000)
    ActsAsTenant.with_tenant(club) do
      p = create(:paciente, club: club, nombre: nombre, apellido: 'Test', created_by: admin)
      p.cuenta_corriente!.tap { |c| c.update!(saldo_disponible: saldo, limite_credito: limite) }
      p
    end
  end

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  it 'lista todos los con cuenta corriente, mayor deudor primero, con el total igual al KPI' do
    paciente_con_cc('Chico', -1_500)
    paciente_con_cc('Grande', -20_000)
    paciente_con_cc('AFavor', 3_000)

    get '/api/cuentas_corrientes'

    expect(response).to have_http_status(:ok)
    expect(json['cuentas'].map { |c| c['nombre'] }).to eq(['Grande Test', 'Chico Test', 'AFavor Test'])
    expect(json['cuentas'].first['deuda']).to eq(20_000.0)
    expect(json['cuentas'].last['deuda']).to  eq(0.0)
    expect(json['deudores']).to    eq(2)
    expect(json['total_deuda']).to eq(21_500.0)

    get '/api/movimientos_contables/dashboard'
    expect(json['por_cobrar']).to eq(21_500.0)
  end

  it 'trae cuándo se movió por última vez la cuenta' do
    p = paciente_con_cc('Ana', -500)
    ActsAsTenant.with_tenant(club) do
      p.cuenta_corriente.movimientos.create!(tipo: 'debito', monto: 500, saldo_anterior: 0, saldo_nuevo: -500,
                                             descripcion: 'x', created_by: admin)
    end

    get '/api/cuentas_corrientes'

    expect(json['cuentas'].first['ultimo_movimiento']).to be_present
  end

  it 'no muestra las de otra organización' do
    otro = create(:club)
    ActsAsTenant.with_tenant(otro) do
      p = create(:paciente, club: otro, created_by: create(:user, :admin, club: otro))
      p.cuenta_corriente!.tap { |c| c.update!(saldo_disponible: -9_999) }
    end

    get '/api/cuentas_corrientes'

    expect(json['cuentas']).to be_empty
    expect(json['total_deuda']).to eq(0)
  end

  it 'el dispensador no la ve' do
    sign_in_as(create(:user, :dispensador, club: club))

    get '/api/cuentas_corrientes'

    expect(response).to have_http_status(:forbidden)
  end
end
