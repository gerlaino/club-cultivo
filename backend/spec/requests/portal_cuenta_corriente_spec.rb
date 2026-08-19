require 'rails_helper'

# AC: el paciente ve su cuenta corriente en el portal, y SÓLO si la organización se la abrió.
#
# Un paciente que paga siempre al contado no tiene cuenta: mostrarle una sección con "saldo $0" le
# hace creer que debe algo o que le falta cargar plata.
RSpec.describe 'Portal — cuenta corriente del paciente', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin)    { create(:user, :admin, club: club) }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) } }

  def con_cuenta
    ActsAsTenant.with_tenant(club) do
      user = Pacientes::Acceso.crear!(paciente).user
      user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      user
    end
  end

  def ver = get '/api/portal/cuenta_corriente'
  def datos = JSON.parse(response.body)['data']

  it 'sin cuenta abierta, lo dice y no inventa un saldo en cero' do
    sign_in_as(con_cuenta)
    ver

    expect(response).to have_http_status(:ok), response.body
    expect(datos['tiene']).to be(false)
    expect(datos).not_to have_key('saldo')
  end

  context 'con cuenta abierta' do
    let!(:cc) do
      ActsAsTenant.with_tenant(club) do
        CuentaCorriente.create!(paciente: paciente, club: club, limite_credito: 10_000, saldo_disponible: -2_500)
      end
    end

    it 'muestra cuánto debe, sin obligarlo a interpretar un número negativo' do
      sign_in_as(con_cuenta)
      ver

      expect(datos['tiene']).to be(true)
      expect(datos['debe']).to eq(2500.0)
      expect(datos['limite']).to eq(10_000.0)
    end

    it 'trae sus movimientos' do
      ActsAsTenant.with_tenant(club) do
        cc.movimientos.create!(tipo: 'carga', monto: 5_000, saldo_anterior: 0, saldo_nuevo: 5_000,
                               created_by: admin)
      end

      sign_in_as(con_cuenta)
      ver

      expect(datos['movimientos'].first['label']).to eq('Carga de crédito')
    end

    # Quién cargó el movimiento es del funcionamiento interno de la organización.
    it 'no expone quién hizo cada movimiento' do
      ActsAsTenant.with_tenant(club) do
        cc.movimientos.create!(tipo: 'carga', monto: 5_000, saldo_anterior: 0, saldo_nuevo: 5_000,
                               created_by: admin)
      end

      sign_in_as(con_cuenta)
      ver

      expect(datos['movimientos'].first.keys).to contain_exactly('id', 'fecha', 'tipo', 'label', 'monto', 'saldo', 'suma')
    end

    it 'la de otro paciente no se ve: no hay id en la URL que cambiar' do
      ajeno = ActsAsTenant.with_tenant(club) do
        otro = create(:paciente, club: club, created_by: admin)
        CuentaCorriente.create!(paciente: otro, club: club, limite_credito: 99_999, saldo_disponible: 0)
      end

      sign_in_as(con_cuenta)
      ver

      expect(datos['limite']).to eq(10_000.0)
      expect(datos['limite']).not_to eq(ajeno.limite_credito.to_f)
    end
  end
end
