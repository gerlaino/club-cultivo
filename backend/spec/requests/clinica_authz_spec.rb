require 'rails_helper'

# Regresión de seguridad — AZ-01 / AZ-02 / AZ-03 del SECURITY_AUDIT.
# AC: el acceso a datos clínicos (indicaciones médicas, documentos clínicos,
# notas de paciente) está restringido a médico y admin. Cualquier otro rol del
# club recibe 403. Supervisor queda explícitamente afuera (es rol de cultivo).
#
# El gate corre en before_action, antes de cargar registros clínicos, por eso
# no hacen falta factories de los modelos clínicos: basta el #index.
RSpec.describe 'Autorización de datos clínicos', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin,    club: club) }
  let(:medico)   { create(:user, :medico,   club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  # Roles que NO deben tocar datos clínicos.
  ROLES_SIN_ACCESO = %i[cultivador supervisor manicura dispensador delivery abogado].freeze
  # supervisor no tiene trait en la factory (no se usa en otros specs) → role inline.
  def user_con_rol(rol)
    rol == :supervisor ? create(:user, club: club, role: 'supervisor') : create(:user, rol, club: club)
  end

  shared_examples 'endpoint clínico' do |path_proc|
    context 'permitido' do
      it 'médico recibe 200' do
        sign_in_as(medico)
        get instance_exec(&path_proc), as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'admin recibe 200' do
        sign_in_as(admin)
        get instance_exec(&path_proc), as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'denegado' do
      ROLES_SIN_ACCESO.each do |rol|
        it "#{rol} recibe 403" do
          sign_in_as(user_con_rol(rol))
          get instance_exec(&path_proc), as: :json
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET /pacientes/:id/indicaciones (AZ-01)' do
    include_examples 'endpoint clínico', -> { "/api/pacientes/#{paciente.id}/indicaciones" }
  end

  describe 'GET /pacientes/:id/documents (AZ-02)' do
    include_examples 'endpoint clínico', -> { "/api/pacientes/#{paciente.id}/documents" }
  end

  describe 'GET /pacientes/:id/notas (AZ-03)' do
    include_examples 'endpoint clínico', -> { "/api/pacientes/#{paciente.id}/notas" }
  end

  # Aislamiento de tenant: un médico del club B no ve datos clínicos del club A.
  describe 'aislamiento multi-tenant' do
    it 'médico de otro club recibe 404 sobre el paciente ajeno' do
      otro_club   = create(:club)
      otro_medico = create(:user, :medico, club: otro_club)
      sign_in_as(otro_medico)
      get "/api/pacientes/#{paciente.id}/indicaciones", as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
