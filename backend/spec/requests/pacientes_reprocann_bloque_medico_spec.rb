require 'rails_helper'

# AC (Javi y Germán, 6-oct-2026):
# · REPROCANN: falta «Vencido» → se puede guardar a mano, aunque no haya fecha.
# · El médico puede actualizar el estado: «Inicié el trámite», y el cambio se ve en cada parte de
#   la app donde corresponde (es el mismo dato) y administración se entera.
# · Adherente (paciente nuevo con REPRO vigente, vinculado a otra organización) / Vinculado (su
#   REPRO está con la organización).
# · Apodo opcional.
RSpec.describe 'Pacientes: REPROCANN vencido, trámite, vínculo y apodo', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:medico)      { create(:user, :medico, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin, reprocann_estado: 'sin_registro', reprocann_numero: nil) }

  before { MedicoPaciente.vincular!(medico: medico, paciente: paciente) }

  describe 'REPROCANN «Vencido» guardado a mano' do
    before { sign_in_as(admin) }

    it 'se guarda aunque no haya fecha ni número, y la categoría que manda el backend es vencido' do
      patch "/api/pacientes/#{paciente.id}", params: { paciente: { reprocann_estado: 'vencido' } }, as: :json
      expect(response).to have_http_status(:ok)
      get "/api/pacientes/#{paciente.id}"
      data = JSON.parse(response.body)['data']
      expect(data['reprocann_estado_efectivo']).to eq('vencido')
      expect(data['reprocann_categoria']).to eq('vencido')
    end

    it 'cuenta en «vencidos» del padrón, y no en «sin REPROCANN»' do
      paciente.update!(reprocann_estado: 'vencido')
      get '/api/pacientes'
      kpis = JSON.parse(response.body)['meta']['kpis']
      expect(kpis['vencidos']).to eq(1)
      expect(kpis['sin_rep']).to eq(0)
    end

    it 'también se ve vencido en la lista del médico' do
      paciente.update!(reprocann_estado: 'vencido')
      sign_in_as(medico)
      get '/api/medico/pacientes', params: { filtro: 'vencidos' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] }).to eq([paciente.id])
    end

    it 'con el trámite iniciado no cuenta como vencido en la lista del médico aunque la fecha haya pasado' do
      paciente.update!(reprocann_estado: 'pendiente', reprocann_numero: 'RC-1', reprocann_vencimiento: 10.days.ago.to_date)
      sign_in_as(medico)
      get '/api/medico/pacientes'
      expect(JSON.parse(response.body)['meta']['kpis']['vencidos']).to eq(0)
    end

    it 'un estado inventado se sigue rechazando' do
      patch "/api/pacientes/#{paciente.id}", params: { paciente: { reprocann_estado: 'inactivo' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe '«Inicié el trámite»' do
    it 'el médico lo marca: queda en trámite con la fecha y administración recibe un aviso' do
      sign_in_as(medico)
      post "/api/pacientes/#{paciente.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:ok)
      paciente.reload
      expect(paciente.reprocann_estado).to eq('pendiente')
      expect(paciente.reprocann_tramite_iniciado_el).to eq(Time.zone.today)
      alerta = ActsAsTenant.with_tenant(club) { AlertaInterna.find_by(tipo: 'reprocann_tramite_iniciado') }
      expect(alerta.destinada_a_role).to eq('admin')
      expect(alerta.contexto['paciente_id']).to eq(paciente.id)
    end

    it 'el cambio se ve en la ficha que abre administración (el mismo dato para toda la app)' do
      sign_in_as(medico)
      post "/api/pacientes/#{paciente.id}/iniciar_tramite_reprocann"
      sign_in_as(admin)
      get "/api/pacientes/#{paciente.id}"
      data = JSON.parse(response.body)['data']
      expect(data['reprocann_categoria']).to eq('pendiente')
      expect(data['reprocann_tramite_iniciado_el']).to eq(Time.zone.today.iso8601)
    end

    it 'si lo marca administración no se avisa a sí misma' do
      sign_in_as(admin)
      post "/api/pacientes/#{paciente.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:ok)
      expect(ActsAsTenant.with_tenant(club) { AlertaInterna.where(tipo: 'reprocann_tramite_iniciado').count }).to eq(0)
    end

    it 'un médico no lo puede marcar en un paciente que no atiende' do
      ajeno = create(:paciente, club: club, created_by: admin)
      sign_in_as(medico)
      post "/api/pacientes/#{ajeno.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:not_found)
      expect(ajeno.reload.reprocann_tramite_iniciado_el).to be_nil
    end

    it 'el mostrador no lo puede marcar' do
      sign_in_as(dispensador)
      post "/api/pacientes/#{paciente.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'Adherente / Vinculado' do
    before { sign_in_as(admin) }

    { 'organizacion' => 'Vinculado', 'otra_organizacion' => 'Adherente' }.each do |valor, nombre|
      it "guarda #{nombre}" do
        patch "/api/pacientes/#{paciente.id}", params: { paciente: { reprocann_vinculo: valor } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(paciente.reload.reprocann_vinculo).to eq(valor)
      end
    end

    it 'se puede dejar sin dato' do
      paciente.update!(reprocann_vinculo: 'organizacion')
      patch "/api/pacientes/#{paciente.id}", params: { paciente: { reprocann_vinculo: '' } }, as: :json
      expect(paciente.reload.reprocann_vinculo).to be_blank
    end

    it 'rechaza un valor que no es ninguno de los dos' do
      patch "/api/pacientes/#{paciente.id}", params: { paciente: { reprocann_vinculo: 'cualquiera' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'el mostrador no lo ve, como el resto del REPROCANN' do
      paciente.update!(reprocann_vinculo: 'otra_organizacion')
      sign_in_as(dispensador)
      get "/api/pacientes/#{paciente.id}"
      expect(JSON.parse(response.body)['data']).not_to have_key('reprocann_vinculo')
    end
  end

  describe 'Apodo' do
    it 'es opcional y se guarda' do
      sign_in_as(admin)
      patch "/api/pacientes/#{paciente.id}", params: { paciente: { apodo: 'Tano' } }, as: :json
      expect(paciente.reload.apodo).to eq('Tano')
    end

    it 'busca por apodo en el padrón y en la lista del médico' do
      paciente.update!(apodo: 'Tano', apellido: 'Rossi')
      create(:paciente, club: club, created_by: admin, apellido: 'Otro')

      sign_in_as(admin)
      get '/api/pacientes', params: { query: 'tan' }
      expect(JSON.parse(response.body)['data'].map { |p| p['apellido'] }).to eq(['Rossi'])

      sign_in_as(medico)
      get '/api/medico/pacientes', params: { query: 'tan' }
      expect(JSON.parse(response.body)['data'].map { |p| p['apodo'] }).to eq(['Tano'])
    end
  end
end
