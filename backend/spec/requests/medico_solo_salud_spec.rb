require 'rails_helper'

# AC (Germán, 15-oct-2026): el médico «ni altas ni bajas ni editar, nada, sólo se ocupa de la
# salud». Puede escribir REPROCANN e historia clínica; no crea, no aprueba, no elimina, no toca los
# datos personales ni el acceso al portal.
RSpec.describe 'El médico sólo se ocupa de la salud', type: :request do
  let(:club)     { create(:club, features: { 'produccion_dispensa' => true, 'medico' => true, 'vista_paciente' => true }) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:medico)   { create(:user, club: club, role: 'medico') }
  let!(:paciente) do
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, nombre: 'Ana', con_seguimiento_medico: true) }
  end

  before do
    ActsAsTenant.with_tenant(club) { MedicoPaciente.vincular!(medico: medico, paciente: paciente) }
    sign_in_as(medico)
  end

  def editar(attrs) = put("/api/pacientes/#{paciente.id}", params: { paciente: attrs }, as: :json)

  it 'escribe la historia clínica y el REPROCANN' do
    editar(anamnesis: 'Dolor lumbar crónico', reprocann_estado: 'activo', reprocann_vencimiento: Time.zone.today + 200)
    expect(response).to have_http_status(:ok), response.body
    expect(paciente.reload.anamnesis).to eq('Dolor lumbar crónico')
  end

  it 'no edita los datos personales' do
    editar(nombre: 'Otra', telefono: '1155550000')
    expect(response).to have_http_status(:forbidden)
    expect(paciente.reload.nombre).to eq('Ana')
  end

  it 'si mezcla salud con datos personales, no guarda nada' do
    editar(anamnesis: 'X', dni: '99888777')
    expect(response).to have_http_status(:forbidden)
    expect(paciente.reload.anamnesis).not_to eq('X')
  end

  it 'no elimina pacientes' do
    delete "/api/pacientes/#{paciente.id}"
    expect(response).to have_http_status(:forbidden)
    expect(ActsAsTenant.with_tenant(club) { Paciente.exists?(paciente.id) }).to be(true)
  end

  it 'no da altas' do
    post '/api/pacientes', params: { paciente: { nombre: 'Beto', apellido: 'Paz', dni: '30999888', fecha_nacimiento: '1990-01-01' } }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'no aprueba altas del mostrador' do
    ActsAsTenant.with_tenant(club) { paciente.update_columns(aprobado_at: nil) }
    post "/api/pacientes/#{paciente.id}/aprobar"
    expect(response).to have_http_status(:forbidden)
  end

  it 'no gestiona el acceso al portal' do
    post "/api/pacientes/#{paciente.id}/acceso"
    expect(response).to have_http_status(:forbidden)
  end

  describe 'administración sigue pudiendo todo' do
    before { sign_in_as(admin) }

    it 'edita los datos personales y elimina' do
      editar(nombre: 'Ana María')
      expect(response).to have_http_status(:ok)
      delete "/api/pacientes/#{paciente.id}"
      expect(response).to have_http_status(:no_content)
    end
  end

  it 'el dispensador tampoco elimina ni edita (antes no había chequeo)' do
    sign_in_as(create(:user, club: club, role: 'dispensador'))
    delete "/api/pacientes/#{paciente.id}"
    expect(response).to have_http_status(:forbidden)
    editar(nombre: 'Otra')
    expect(response).to have_http_status(:forbidden)
  end
end
