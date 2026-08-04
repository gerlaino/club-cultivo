require 'rails_helper'

# El REPROCANN no es asunto del dispensador. Su regla es simple y no admite criterio: si el paciente
# está en la lista, dispensa; si no está, avisa al admin. Mostrarle vencimientos lo pone a decidir
# sobre un caso que no le toca, y a discutirlo en el mostrador con el paciente enfrente.
RSpec.describe 'Pacientes — lo que ve el dispensador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Pérez',
                        reprocann_estado: 'vencido', reprocann_vencimiento: 10.days.ago,
                        reprocann_numero: 'RC-123')
    end
  end

  context 'como dispensador' do
    before { sign_in_as(create(:user, club: club, role: 'dispensador')) }

    it 'no recibe ningún dato de REPROCANN en el listado' do
      get '/api/pacientes'

      fila = JSON.parse(response.body)['data'].first
      expect(fila['nombre']).to eq('Ana')
      expect(fila).not_to have_key('reprocann_estado')
      expect(fila).not_to have_key('reprocann_vencimiento')
      expect(fila).not_to have_key('reprocann_numero')
      expect(fila).not_to have_key('reprocann_estado_efectivo')
    end

    it 'tampoco en la ficha' do
      get "/api/pacientes/#{paciente.id}"

      json = JSON.parse(response.body)['data']
      expect(json).not_to have_key('reprocann_estado')
      expect(json).not_to have_key('reprocann_vencimiento')
    end

    # Si está en la lista, dispensa. El REPROCANN vencido no lo saca: eso lo resuelve el admin.
    it 've al paciente aunque tenga el REPROCANN vencido' do
      get '/api/pacientes'
      expect(JSON.parse(response.body)['data'].map { |p| p['nombre'] }).to include('Ana')
    end
  end

  context 'como admin' do
    before { sign_in_as(admin) }

    it 'sí ve el REPROCANN: es quien mira los casos especiales' do
      get '/api/pacientes'

      fila = JSON.parse(response.body)['data'].first
      expect(fila['reprocann_estado']).to eq('vencido')
      expect(fila['reprocann_estado_efectivo']).to be_present
    end
  end
  # Escanear el carnet en el mostrador tiene que traer AL PACIENTE, no la página pública del
  # carnet: esa es para el socio, no para quien atiende.
  describe 'escanear el carnet' do
    before { sign_in_as(create(:user, club: club, role: 'dispensador')) }

    it 'resuelve el token a su paciente' do
      get "/api/pacientes/por_carnet/#{paciente.carnet_token}"

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data['id']).to eq(paciente.id)
      expect(data['nombre']).to eq('Ana')
      # Sigue sin ver REPROCANN: escanear no es una puerta de atrás a lo que no le corresponde.
      expect(data).not_to have_key('reprocann_estado')
    end

    it 'no resuelve el carnet de un paciente de otro club' do
      ajeno = ActsAsTenant.without_tenant do
        otro = create(:club)
        ActsAsTenant.with_tenant(otro) do
          create(:paciente, club: otro, created_by: create(:user, :admin, club: otro))
        end
      end

      get "/api/pacientes/por_carnet/#{ajeno.carnet_token}"
      expect(response).to have_http_status(:not_found)
    end

    it 'avisa si el token no existe' do
      get '/api/pacientes/por_carnet/inventado-123'
      expect(response).to have_http_status(:not_found)
    end
  end

end
