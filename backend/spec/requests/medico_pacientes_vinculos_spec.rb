require 'rails_helper'

# AC (Javi y Germán, 6-oct-2026):
# · El médico ve SÓLO a los pacientes vinculados a él; un paciente puede tener más de un médico.
# · Administración le vincula pacientes al médico (y los desvincula).
# · Si se le da un turno a un paciente no vinculado a ese médico, se vincula directo.
RSpec.describe 'Médico: sólo ve a sus pacientes vinculados', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:medico)   { create(:user, :medico, club: club) }
  let(:otro_med) { create(:user, :medico, club: club) }

  let!(:suyo)       { create(:paciente, club: club, created_by: admin, apellido: 'Suyo') }
  let!(:del_otro)   { create(:paciente, club: club, created_by: admin, apellido: 'DelOtro') }
  let!(:compartido) { create(:paciente, club: club, created_by: admin, apellido: 'Compartido') }

  before do
    MedicoPaciente.vincular!(medico: medico,   paciente: suyo)
    MedicoPaciente.vincular!(medico: otro_med, paciente: del_otro)
    MedicoPaciente.vincular!(medico: medico,   paciente: compartido)
    MedicoPaciente.vincular!(medico: otro_med, paciente: compartido)
  end

  def apellidos(path)
    get path
    JSON.parse(response.body)['data'].map { |p| p['apellido'] }
  end

  describe 'las listas' do
    it 'su lista de médico trae a sus vinculados y no a los del otro médico' do
      sign_in_as(medico)
      expect(apellidos('/api/medico/pacientes')).to match_array(%w[Suyo Compartido])
    end

    it 'el padrón (/pacientes) tampoco le muestra al del otro médico' do
      sign_in_as(medico)
      expect(apellidos('/api/pacientes')).to match_array(%w[Suyo Compartido])
    end

    it 'un paciente con dos médicos lo ven los dos' do
      sign_in_as(otro_med)
      expect(apellidos('/api/medico/pacientes')).to match_array(%w[DelOtro Compartido])
    end

    it 'un médico sin pacientes vinculados no ve a nadie' do
      sign_in_as(create(:user, :medico, club: club))
      expect(apellidos('/api/medico/pacientes')).to eq([])
    end

    it 'administración sigue viendo a todos' do
      sign_in_as(admin)
      expect(apellidos('/api/pacientes')).to match_array(%w[Suyo DelOtro Compartido])
    end
  end

  describe 'por URL, el paciente de otro médico no se abre' do
    before { sign_in_as(medico) }

    {
      'la ficha'        => ->(id) { "/api/pacientes/#{id}" },
      'el timeline'     => ->(id) { "/api/pacientes/#{id}/timeline" },
      'sus indicaciones'=> ->(id) { "/api/pacientes/#{id}/indicaciones" },
      'sus documentos'  => ->(id) { "/api/pacientes/#{id}/documents" },
      'sus notas'       => ->(id) { "/api/pacientes/#{id}/notas" },
      'sus turnos'      => ->(id) { "/api/pacientes/#{id}/turnos" },
    }.each do |que, ruta|
      it "no abre #{que} del paciente del otro médico" do
        get ruta.call(del_otro.id)
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'sí abre la ficha de su paciente' do
      get "/api/pacientes/#{suyo.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'no le puede dar un turno a un paciente que no es suyo' do
      post '/api/medico/turnos', params: { turno: { paciente_id: del_otro.id, fecha_hora: 2.days.from_now,
                                                     duracion_minutos: 30, tipo: 'seguimiento' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Turno.where(paciente: del_otro, medico: medico)).to be_empty
    end
  end

  describe 'administración vincula y desvincula' do
    it 'al vincularlo, el médico lo empieza a ver' do
      sign_in_as(admin)
      post "/api/pacientes/#{del_otro.id}/medicos", params: { medico_id: medico.id }, as: :json
      expect(response).to have_http_status(:created)

      sign_in_as(medico)
      expect(apellidos('/api/medico/pacientes')).to include('DelOtro')
    end

    it 'al desvincularlo, deja de verlo' do
      sign_in_as(admin)
      delete "/api/pacientes/#{suyo.id}/medicos/#{medico.id}"
      expect(response).to have_http_status(:no_content)

      sign_in_as(medico)
      expect(apellidos('/api/medico/pacientes')).not_to include('Suyo')
    end

    it 'la ficha dice qué médicos lo atienden' do
      sign_in_as(admin)
      get "/api/pacientes/#{compartido.id}"
      ids = JSON.parse(response.body)['data']['medicos'].map { |m| m['medico_id'] }
      expect(ids).to match_array([medico.id, otro_med.id])
    end

    it 'el médico no puede vincularse pacientes solo' do
      sign_in_as(medico)
      post "/api/pacientes/#{suyo.id}/medicos", params: { medico_id: otro_med.id }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'no vincula a alguien que no es médico' do
      sign_in_as(admin)
      dispensador = create(:user, :dispensador, club: club)
      post "/api/pacientes/#{suyo.id}/medicos", params: { medico_id: dispensador.id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'dar un turno vincula directo' do
    it 'administración le da un turno con un paciente no vinculado: queda vinculado y lo ve' do
      sign_in_as(admin)
      post "/api/admin/medicos/#{medico.id}/crear_turno",
           params: { turno: { paciente_id: del_otro.id, fecha_hora: 2.days.from_now, duracion_minutos: 30, tipo: 'primera_vez' } },
           as: :json
      expect(response).to have_http_status(:created)
      expect(MedicoPaciente.exists?(medico: medico, paciente: del_otro)).to be(true)

      sign_in_as(medico)
      expect(apellidos('/api/medico/pacientes')).to include('DelOtro')
    end
  end

  describe 'el médico que da de alta a un paciente lo atiende' do
    it 'lo crea y lo sigue viendo' do
      sign_in_as(medico)
      post '/api/pacientes', params: { paciente: { nombre: 'Nueva', apellido: 'Alta', dni: '30111222',
                                                   fecha_nacimiento: '1990-01-01' } }, as: :json
      expect(response).to have_http_status(:created)
      expect(apellidos('/api/medico/pacientes')).to include('Alta')
    end
  end

  describe 'aislamiento de tenant' do
    let(:otro_club)  { create(:club) }
    let(:admin_otro) { create(:user, :admin, club: otro_club) }

    it 'administración no puede vincular un médico de otra organización' do
      medico_ajeno = create(:user, :medico, club: otro_club)
      sign_in_as(admin)
      post "/api/pacientes/#{suyo.id}/medicos", params: { medico_id: medico_ajeno.id }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(ActsAsTenant.without_tenant { MedicoPaciente.where(medico: medico_ajeno).count }).to eq(0)
    end

    it 'administración de otra organización no ve ni toca los vínculos de esta' do
      sign_in_as(admin_otro)
      get "/api/pacientes/#{suyo.id}/medicos"
      expect(response).to have_http_status(:not_found)
      delete "/api/pacientes/#{suyo.id}/medicos/#{medico.id}"
      expect(response).to have_http_status(:not_found)
      # Sin tenant: después del request, ActsAsTenant queda apuntando a la otra organización.
      expect(ActsAsTenant.without_tenant { MedicoPaciente.exists?(medico: medico, paciente: suyo) }).to be(true)
    end
  end
end
