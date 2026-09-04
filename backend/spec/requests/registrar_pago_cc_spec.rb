require 'rails_helper'

# Registrar pago de socio: crea asiento de ingreso (aporte_socio) que aparece
# en el libro y acredita la cuenta corriente (salda deuda / deja saldo a favor).
RSpec.describe 'Registrar pago en cuenta corriente', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(paciente: paciente, club: club,
                            saldo_disponible: -5_000, limite_credito: 10_000)
  end

  before { sede; sign_in_as(admin) }

  def registrar(monto:, medio: 'efectivo')
    post "/pacientes/#{paciente.id}/cuenta_corriente/registrar_pago",
         params: { monto: monto, medio_pago: medio }, headers: auth_headers, as: :json
  end

  it 'crea un movimiento contable de ingreso (aporte_socio)' do
    expect { registrar(monto: 5_000) }.to change(MovimientoContable, :count).by(1)
    mov = MovimientoContable.last
    expect(mov.categoria).to eq('aporte_socio')
    expect(mov.tipo).to eq('ingreso')
    expect(mov.paciente_id).to eq(paciente.id)
    expect(mov.pagado).to be(true)
  end

  it 'salda la deuda (acredita la cuenta corriente)' do
    registrar(monto: 5_000)
    expect(cc.reload.saldo_disponible.to_f).to eq(0.0)
  end

  it 'pagar de más deja saldo a favor' do
    registrar(monto: 7_000)
    expect(cc.reload.saldo_disponible.to_f).to eq(2_000.0)
  end

  it 'suma a los ingresos del libro' do
    registrar(monto: 5_000)
    expect(MovimientoContable.ingresos.sum(:monto_ars).to_f).to eq(5_000.0)
  end

  it 'rechaza monto <= 0' do
    registrar(monto: 0)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end

# Dispensador puede registrar pagos (rol de mostrador), sin login de admin
RSpec.describe 'Registrar pago — dispensador', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(paciente: paciente, club: club,
                            saldo_disponible: -3_000, limite_credito: 10_000)
  end

  before do
    sede
    dispensador.user_sedes.create!(sede: sede)
    sign_in_as(dispensador)
  end

  it 'el dispensador puede registrar un pago' do
    post "/pacientes/#{paciente.id}/cuenta_corriente/registrar_pago",
         params: { monto: 3_000, medio_pago: 'efectivo' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(cc.reload.saldo_disponible.to_f).to eq(0.0)
  end
end

# El pago de una deuda es plata REAL que entra al cajón, aunque no venga de una dispensa. Antes
# de esto, era invisible para el arqueo del mostrador: MovimientoContable no se ataba a ninguna
# caja, y quien contaba esa noche encontraba un sobrante que no podía explicar.
RSpec.describe 'Registrar pago — se ata a la caja del mostrador abierta', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'social') }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(paciente: paciente, club: club,
                            saldo_disponible: -5_000, limite_credito: 10_000)
  end

  def registrar(monto:, medio: 'efectivo')
    sign_in_as(admin)
    post "/pacientes/#{paciente.id}/cuenta_corriente/registrar_pago",
         params: { monto: monto, medio_pago: medio, sede_id: sede.id }, headers: auth_headers, as: :json
  end

  it 'con la caja abierta, se ata sola y entra al esperado del arqueo' do
    turno = abrir_mostrador!(sede, usuario: admin, fondo: 10_000)

    registrar(monto: 5_000)

    mov = MovimientoContable.last
    expect(mov.caja_turno_id).to eq(turno.caja_turno_id)
    expect(turno.caja_turno.reload.total_otros_ingresos_efectivo_ars).to eq(5_000.0)
    expect(turno.caja_turno.reload.efectivo_esperado_ars).to eq(15_000.0) # 10.000 de fondo + 5.000 pagados
  end

  it 'sin caja abierta, no rompe: queda sin atar' do
    registrar(monto: 5_000)

    expect(response).to have_http_status(:created)
    expect(MovimientoContable.last.caja_turno_id).to be_nil
  end

  it 'pagado por transferencia no cuenta como efectivo esperado' do
    turno = abrir_mostrador!(sede, usuario: admin, fondo: 10_000)

    registrar(monto: 5_000, medio: 'transferencia')

    expect(turno.caja_turno.reload.total_otros_ingresos_efectivo_ars).to eq(0.0)
  end
end
