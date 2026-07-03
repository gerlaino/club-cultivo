require 'rails_helper'

# Blindaje AZ-01/02: la historia clínica (campos de salud) NO debe filtrarse a roles no
# clínicos vía pacientes#show ni #index. Allowlist: admin/medico/supervisor ven lo clínico;
# dispensador y super_admin NO.
RSpec.describe 'Pacientes — no filtrar historia clínica a roles no clínicos', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, club: club, role: 'admin') }
  let(:medico)      { create(:user, club: club, role: 'medico') }
  let(:supervisor)  { create(:user, club: club, role: 'supervisor') }
  let(:dispensador) { create(:user, club: club, role: 'dispensador') }

  CAMPOS_CLINICOS = %w[
    notas_clinicas motivo_consulta anamnesis antecedentes_personales antecedentes_familiares
    diagnostico_principal diagnostico_secundario evolucion_clinica alergias
    medicacion_habitual grupo_sanguineo
  ].freeze

  let!(:paciente) do
    create(:paciente, club: club, created_by: admin, es_paciente: true,
      notas_clinicas:          'Epilepsia refractaria',
      motivo_consulta:         'Dolor crónico',
      anamnesis:               'Anamnesis confidencial',
      antecedentes_personales: 'HTA',
      antecedentes_familiares: 'Diabetes',
      diagnostico_principal:   'Diagnóstico confidencial',
      diagnostico_secundario:  'Secundario',
      evolucion_clinica:       'Evolución favorable',
      alergias:                'Penicilina',
      medicacion_habitual:     'Enalapril',
      grupo_sanguineo:         'O+')
  end

  describe 'GET /pacientes/:id (show)' do
    it 'el dispensador NO recibe ningún campo clínico, pero sí los no clínicos' do
      sign_in_as(dispensador)
      get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      CAMPOS_CLINICOS.each { |campo| expect(data).not_to have_key(campo), "filtró el campo clínico #{campo}" }
      expect(data['nombre']).to be_present         # no clínico: sí lo ve
      expect(data).to have_key('reprocann_estado') # no clínico: sí lo ve
    end

    %i[admin medico supervisor].each do |rol|
      it "el #{rol} SÍ recibe la historia clínica" do
        sign_in_as(send(rol))
        get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']
        expect(data['notas_clinicas']).to eq('Epilepsia refractaria')
        expect(data['anamnesis']).to eq('Anamnesis confidencial')
        expect(data['diagnostico_principal']).to eq('Diagnóstico confidencial')
      end
    end

    it 'super_admin (rol de plataforma) queda bloqueado por ROL, aun en el mismo club' do
      super_admin = create(:user, club: club, role: 'super_admin')
      sign_in_as(super_admin)
      get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /pacientes (index)' do
    it 'la lista NO expone campos clínicos (tampoco para dispensador)' do
      sign_in_as(dispensador)
      get "/pacientes", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      items = JSON.parse(response.body)['data']
      expect(items).to be_present
      items.each do |item|
        CAMPOS_CLINICOS.each { |campo| expect(item).not_to have_key(campo), "la lista filtró #{campo}" }
      end
    end
  end
end
