require 'rails_helper'

# LA RENOVACIÓN DEL REPROCANN DESDE EL PORTAL (27-oct-2026).
#
# AC:
#   - El paciente sube la constancia (foto o PDF) y queda «en revisión»: no cambia nada solo.
#   - Administración la ve en la ficha del paciente y le llega el aviso; la aprueba cargando el
#     vencimiento nuevo (el REPROCANN queda al día y activo) o la rechaza con el motivo.
#   - El paciente ve en qué quedó: aprobada con la fecha nueva, o rechazada con el motivo, y le
#     llega el aviso.
#   - Una sola en revisión: si sube otra, reemplaza a la pendiente.
#   - Nada ajeno: el paciente ve lo suyo; otra organización no aprueba lo de este paciente.
RSpec.describe 'Portal — la renovación del REPROCANN', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club) }
  let(:lucia) do
    create(:paciente, club: club, nombre: 'Lucía', created_by: admin, aprobado_at: Time.current,
                      reprocann_numero: 'R-1', reprocann_vencimiento: 5.days.from_now.to_date)
  end
  let!(:cuenta) do
    u = Pacientes::Acceso.crear!(lucia).user
    u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    u
  end

  def pdf(nombre = 'constancia.pdf') = Rack::Test::UploadedFile.new(StringIO.new('%PDF-1.4'), 'application/pdf', original_filename: nombre)
  def subir(archivo = pdf) = post('/api/portal/papeles/renovacion', params: { constancia: archivo })
  def json = JSON.parse(response.body)['data']

  it 'el paciente la sube y queda en revisión, sin tocar su REPROCANN' do
    sign_in_as(cuenta)
    expect(PushNotificationService).to receive(:notify_roles_async).with(club, 'admin', hash_including(tipo: 'renovacion_subida'))
    subir

    expect(response).to have_http_status(:created), response.body
    expect(json).to include('estado' => 'en_tramite')
    expect(lucia.reload.reprocann_vencimiento).to eq(5.days.from_now.to_date)

    get '/api/portal/papeles'
    expect(json['renovacion']['estado']).to eq('en_tramite')
    expect(json['reprocann']).to include('numero' => 'R-1', 'dias_para_vencer' => 5)
  end

  it 'sólo una foto o un PDF' do
    sign_in_as(cuenta)
    subir(Rack::Test::UploadedFile.new(StringIO.new('MZ'), 'application/x-msdownload', original_filename: 'x.exe'))
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'si sube otra, reemplaza a la que estaba en revisión' do
    sign_in_as(cuenta)
    subir(pdf('primera.pdf'))
    subir(pdf('segunda.pdf'))

    pendientes = lucia.reprocann_renovaciones.del_portal.where(estado: 'en_tramite')
    expect(pendientes.count).to eq(1)
    expect(pendientes.first.constancia.filename.to_s).to eq('segunda.pdf')
  end

  describe 'administración la revisa' do
    before do
      sign_in_as(cuenta)
      subir
      sign_in_as(admin)
    end

    let(:renovacion) { lucia.reprocann_renovaciones.del_portal.first }
    def revisar(params) = put("/api/pacientes/#{lucia.id}/reprocann_renovaciones/#{renovacion.id}", params: params, as: :json)

    it 'la ficha la muestra con la constancia' do
      get "/api/pacientes/#{lucia.id}"
      r = JSON.parse(response.body)['data']['renovacion_portal']
      expect(r['id']).to eq(renovacion.id)
      expect(r['constancia_nombre']).to eq('constancia.pdf')
    end

    it 'aprobarla carga el vencimiento nuevo y el REPROCANN queda activo; el paciente lo ve' do
      expect(PushNotificationService).to receive(:notify_user_async).with(cuenta, hash_including(tipo: 'renovacion_revisada'))
      revisar(accion: 'aprobar', fecha_vencimiento_nueva: 1.year.from_now.to_date.iso8601, reprocann_numero_nuevo: 'R-2')

      expect(response).to have_http_status(:ok), response.body
      lucia.reload
      expect(lucia.reprocann_vencimiento).to eq(1.year.from_now.to_date)
      expect(lucia.reprocann_numero).to eq('R-2')
      expect(lucia.reprocann_estado).to eq('activo')

      get "/api/pacientes/#{lucia.id}"
      expect(JSON.parse(response.body)['data']['renovacion_portal']).to be_nil

      sign_in_as(cuenta)
      get '/api/portal/papeles'
      expect(json['renovacion']).to include('estado' => 'aprobada', 'vencimiento_nuevo' => 1.year.from_now.to_date.iso8601)
    end

    it 'sin fecha nueva no se aprueba, y una fecha que ya pasó tampoco' do
      revisar(accion: 'aprobar')
      expect(response).to have_http_status(:unprocessable_entity)

      revisar(accion: 'aprobar', fecha_vencimiento_nueva: 2.days.ago.to_date.iso8601)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(lucia.reload.reprocann_vencimiento).to eq(5.days.from_now.to_date)
    end

    it 'rechazarla deja el motivo, que el paciente ve' do
      revisar(accion: 'rechazar', observaciones: 'La foto no se lee, subila de nuevo.')

      sign_in_as(cuenta)
      get '/api/portal/papeles'
      expect(json['renovacion']).to include('estado' => 'rechazada', 'observaciones' => 'La foto no se lee, subila de nuevo.')
    end
  end

  it 'el admin de otra organización no la ve ni la aprueba' do
    sign_in_as(cuenta)
    subir
    otra = create(:club, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
    sign_in_as(create(:user, :admin, club: otra))
    renov = ActsAsTenant.without_tenant { lucia.reprocann_renovaciones.first }

    put "/api/pacientes/#{lucia.id}/reprocann_renovaciones/#{renov.id}",
        params: { accion: 'aprobar', fecha_vencimiento_nueva: 1.year.from_now.to_date.iso8601 }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(ActsAsTenant.without_tenant { lucia.reload.reprocann_vencimiento }).to eq(5.days.from_now.to_date)
  end
end
