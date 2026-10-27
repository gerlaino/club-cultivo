require 'rails_helper'

# AC (27-oct-2026): desde la ficha, administración le manda al paciente el link para entrar a su
# portal: la primera vez y cada vez que pierde la clave. La ficha dice si ya lo activó, cuándo
# entró por última vez y si tiene un link vigente. Nadie de la organización ve su clave.
RSpec.describe 'El acceso al portal, desde la ficha', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Organización', vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club) }
  let(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, nombre: 'Ana', apellido: 'Díaz', dni: '30111222', email: nil,
                        aprobado_at: Time.current, created_by: admin)
    end
  end

  def ficha = get("/api/pacientes/#{paciente.id}")
  def acceso_de_la_ficha = JSON.parse(response.body)['data']['acceso']
  def invitar = post("/api/pacientes/#{paciente.id}/acceso/invitar", as: :json)

  describe 'administración' do
    before { sign_in_as(admin) }

    it 'la ficha dice que nunca lo activó y que no hay link vigente' do
      ficha

      expect(acceso_de_la_ficha).to include('modulo' => true, 'portal_abierto' => true, 'activado' => false,
                                            'link_vigente' => nil, 'tiene_mail' => false)
    end

    it 'le manda el link (y le crea la cuenta si no la tenía)' do
      invitar

      expect(response).to have_http_status(:created), response.body
      body = JSON.parse(response.body)
      expect(body['link']['url']).to include('/portal/entrar/')
      expect(body['data']['link_vigente']['motivo']).to eq('invitacion')
      expect(paciente.reload.user).to be_present
    end

    it 'mandar otro link deja sin efecto el anterior' do
      invitar
      viejo = JSON.parse(response.body)['link']['url'].split('/').last
      invitar

      get "/api/portal_acceso/links/#{viejo}"
      expect(response).to have_http_status(:gone)
    end

    it 'cuando el paciente lo usa, la ficha dice que lo activó y cuándo entró' do
      invitar
      token = JSON.parse(response.body)['link']['url'].split('/').last
      reset!
      post "/api/portal_acceso/links/#{token}/activar",
           params: { dni: '30111222', password: 'clave-de-ana', password_confirmation: 'clave-de-ana' }, as: :json

      sign_in_as(admin)
      ficha
      expect(acceso_de_la_ficha['activado']).to be(true)
      expect(acceso_de_la_ficha['ultimo_ingreso']).to be_present
      expect(acceso_de_la_ficha['link_vigente']).to be_nil
    end

    it 'la ficha nunca trae la clave ni el link (el link se ve sólo al mandarlo)' do
      invitar
      ficha

      expect(response.body).not_to include('/portal/entrar/')
      expect(response.body).not_to include('password')
    end

    it 'a un paciente dado de baja no se le manda' do
      paciente.update_column(:es_paciente, false)
      invitar

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('dado de baja')
    end
  end

  describe 'quién puede' do
    it 'el dispensador no' do
      sign_in_as(create(:user, :dispensador, club: club))
      invitar

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'sin el módulo contratado' do
    let(:club) { create(:club, features: { 'produccion_dispensa' => true }) }

    before { sign_in_as(admin) }

    it 'la ficha no habla del portal' do
      ficha
      expect(acceso_de_la_ficha).to eq('modulo' => false)
    end

    it 'y no se puede mandar ningún link' do
      invitar
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'aislamiento entre organizaciones' do
    it 'el admin de otra organización no puede invitar a este paciente' do
      otra = create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
      paciente
      sign_in_as(create(:user, :admin, club: otra))

      invitar

      expect(response).to have_http_status(:not_found)
      expect(AccesoPortal.unscoped.count).to eq(0)
    end
  end
end
