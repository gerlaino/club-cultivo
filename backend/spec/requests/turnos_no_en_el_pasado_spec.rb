require 'rails_helper'

# AC (Germán, 12-oct-2026): «cuando damos turnos está bien el aviso de no poder crear turnos en el
# pasado, pero cuando reprogramamos el sistema nos permite una fecha y horario que ya pasó». Ni
# crear ni reprogramar a un momento que ya pasó, por ninguno de los dos caminos (administración y
# médico). Lo que NO cambia la fecha —cerrar como realizado un turno de ayer— sigue andando.
RSpec.describe 'Un turno no se agenda ni se reprograma en el pasado', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:medico)   { create(:user, :medico, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let(:hace_una_hora) { 1.hour.ago.iso8601 }

  before do
    allow(PushNotificationService).to receive(:notify_user_async)
    MedicoPaciente.vincular!(medico: medico, paciente: paciente)
  end

  def json = JSON.parse(response.body)

  def turno!(fecha_hora: 2.days.from_now, estado: 'programado')
    ActsAsTenant.with_tenant(club) do
      Turno.create!(club: club, paciente: paciente, medico: medico, fecha_hora: fecha_hora,
                    duracion_minutos: 30, tipo: 'seguimiento', estado: estado)
    end
  end

  describe 'administración' do
    before { sign_in_as(admin) }

    it 'no da un turno en una hora de hoy que ya pasó' do
      post "/api/admin/medicos/#{medico.id}/crear_turno",
           params: { turno: { paciente_id: paciente.id, fecha_hora: hace_una_hora, duracion_minutos: 30, tipo: 'seguimiento' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('ya pasó')
    end

    it 'no reprograma a una fecha y hora que ya pasó' do
      t = turno!
      patch "/api/admin/turnos/#{t.id}", params: { turno: { fecha_hora: hace_una_hora } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('ya pasó')
      expect(t.reload.fecha_hora).to be > Time.current
    end

    it 'reprograma a otro momento que todavía no llegó' do
      t = turno!
      nueva = 5.days.from_now.change(sec: 0)
      patch "/api/admin/turnos/#{t.id}", params: { turno: { fecha_hora: nueva.iso8601 } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(t.reload.fecha_hora).to be_within(1.second).of(nueva)
    end

    it 'cerrar como realizado un turno de ayer, sin tocar la fecha, sigue andando' do
      t = turno!(fecha_hora: 1.day.ago)
      patch "/api/admin/turnos/#{t.id}", params: { turno: { estado: 'realizado', fecha_hora: t.fecha_hora.iso8601 } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(t.reload.estado).to eq('realizado')
    end
  end

  describe 'el médico' do
    before { sign_in_as(medico) }

    it 'no se da un turno en el pasado' do
      post '/api/medico/turnos',
           params: { turno: { paciente_id: paciente.id, fecha_hora: hace_una_hora, duracion_minutos: 30, tipo: 'seguimiento' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no reprograma a una fecha y hora que ya pasó' do
      t = turno!
      patch "/api/medico/turnos/#{t.id}", params: { turno: { fecha_hora: hace_una_hora } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(t.reload.fecha_hora).to be > Time.current
    end
  end
end
