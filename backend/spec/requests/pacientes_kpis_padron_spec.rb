require 'rails_helper'

# AC: los contadores del padrón (la fila de tarjetas de /pacientes) cuentan TODO el club, no la
# página cargada.
#
# El bug real que motiva este spec: se cargaron 38 pacientes y la pantalla decía "20 en la
# nómina" y "0 REPROCANN vencido" — 20 es el tamaño de página del backend, y los vencidos
# estaban en la página 2. Un admin lee ese cero y se queda tranquilo.
RSpec.describe 'GET /api/pacientes — KPIs del padrón', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:hoy)   { Time.zone.today }

  def paciente(**attrs)
    create(:paciente, club: club, created_by: admin, **attrs)
  end

  def kpis(params = {})
    get '/api/pacientes', params: params
    JSON.parse(response.body).dig('meta', 'kpis')
  end

  before { sign_in_as(admin) }

  describe 'el conteo NO depende de la paginación' do
    # El caso que reproduce el bug: más pacientes que el tamaño de página, y lo que hay que
    # contar cae FUERA de la primera página.
    it 'cuenta todo el club aunque la página traiga menos' do
      25.times { paciente(reprocann_numero: 'RC-1', reprocann_estado: 'activo', reprocann_vencimiento: hoy + 2.years) }

      body = kpis(limite: 5)

      expect(response).to have_http_status(:ok)
      expect(body['total']).to eq(25)
    end

    it 'cuenta un vencido que quedó fuera de la primera página' do
      # Los 5 sanos se crean primero; el vencido queda último y el orden por defecto es
      # created_at DESC... así que se pide explícitamente la página que NO lo contiene.
      5.times { paciente(reprocann_numero: 'RC-ok', reprocann_estado: 'activo', reprocann_vencimiento: hoy + 1.year) }
      paciente(reprocann_numero: 'RC-vencido', reprocann_estado: 'activo', reprocann_vencimiento: hoy - 10.days)

      get '/api/pacientes', params: { limite: 2, pagina: 3 }
      body = JSON.parse(response.body)

      # En esa página el vencido no viene...
      expect(body['data'].map { |p| p['reprocann_numero'] }).not_to include('RC-vencido')
      # ...y el contador lo cuenta igual.
      expect(body.dig('meta', 'kpis', 'vencidos')).to eq(1)
    end
  end

  describe 'las categorías respetan la precedencia de reprocannCategoria' do
    it 'el trámite pendiente gana sobre la falta de número' do
      paciente(reprocann_numero: nil, reprocann_estado: 'pendiente')

      body = kpis
      expect(body['pendientes']).to eq(1)
      expect(body['sin_rep']).to    eq(0)
    end

    it 'sin número de certificado cuenta como sin REPROCANN' do
      paciente(reprocann_numero: nil, reprocann_estado: 'sin_registro')

      expect(kpis['sin_rep']).to eq(1)
    end

    it 'separa vencido de por vencer usando la fecha' do
      paciente(reprocann_numero: 'RC-1', reprocann_estado: 'activo', reprocann_vencimiento: hoy - 1.day)
      paciente(reprocann_numero: 'RC-2', reprocann_estado: 'activo', reprocann_vencimiento: hoy + 10.days)
      paciente(reprocann_numero: 'RC-3', reprocann_estado: 'activo', reprocann_vencimiento: hoy + 6.months)

      body = kpis
      expect(body['vencidos']).to eq(1)
      expect(body['proximos']).to eq(1)
    end

    it 'un vencimiento a 30 días exactos todavía es "por vencer", no vencido' do
      paciente(reprocann_numero: 'RC-borde', reprocann_estado: 'activo', reprocann_vencimiento: hoy + 30.days)

      body = kpis
      expect(body['proximos']).to eq(1)
      expect(body['vencidos']).to eq(0)
    end
  end

  describe 'la nómina' do
    it 'deja los dados de baja fuera del total y los cuenta aparte' do
      2.times { paciente(es_paciente: true) }
      paciente(es_paciente: false)

      body = kpis
      expect(body['total']).to eq(2)
      expect(body['baja']).to  eq(1)
    end
  end

  describe 'aislamiento de tenant' do
    it 'no cuenta pacientes de otro club' do
      otro = create(:club)
      # Los datos del OTRO club van dentro de with_tenant: con el test_tenant apuntando a
      # `club`, acts_as_tenant se lo reasignaría y el spec pasaría por el motivo equivocado
      # (convención documentada en spec/support/auth_helpers.rb).
      ActsAsTenant.with_tenant(otro) do
        create(:paciente, club: otro, created_by: create(:user, :admin, club: otro))
      end
      paciente

      expect(kpis['total']).to eq(1)
    end
  end
end
