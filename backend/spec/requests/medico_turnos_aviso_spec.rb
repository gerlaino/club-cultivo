require 'rails_helper'

# AC (Javi, 6-oct-2026): al médico le llegan notificaciones y mails cuando le asignan turnos, y
# confirma que vio el turno asignado.
RSpec.describe 'Turnos que administración le da al médico: aviso y «Lo vi»', type: :request do
  include ActiveJob::TestHelper

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:medico)   { create(:user, :medico, club: club, email: 'dra.lopez@ejemplo.com') }
  let(:paciente) { create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Paz') }

  before do
    allow(PushNotificationService).to receive(:notify_user_async)
    MedicoPaciente.vincular!(medico: medico, paciente: paciente)
  end

  def dar_turno(fecha: 2.days.from_now)
    post "/api/admin/medicos/#{medico.id}/crear_turno",
         params: { turno: { paciente_id: paciente.id, fecha_hora: fecha, duracion_minutos: 30, tipo: 'seguimiento' } },
         as: :json
    Turno.find(JSON.parse(response.body)['id'])
  end

  describe 'administración le da un turno' do
    before { sign_in_as(admin) }

    it 'le manda una push al médico, con el tipo del catálogo' do
      dar_turno
      expect(PushNotificationService).to have_received(:notify_user_async)
        .with(medico, hash_including(tipo: 'turno_asignado', title: 'Turno nuevo'))
    end

    it 'le manda un mail a su casilla' do
      expect { dar_turno }.to have_enqueued_mail(TurnosMailer, :aviso_medico)
    end

    it 'el turno queda sin ver, y administración lo ve así' do
      turno = dar_turno
      expect(turno.visto_at).to be_nil
      get "/api/admin/medicos/#{medico.id}/turnos"
      expect(JSON.parse(response.body).find { |t| t['id'] == turno.id }['visto_at']).to be_nil
    end

    it 'si se lo mueve de día, le avisa y vuelve a quedar sin ver' do
      turno = dar_turno
      turno.update_columns(visto_at: 1.hour.ago)
      patch "/api/admin/turnos/#{turno.id}", params: { turno: { fecha_hora: 5.days.from_now } }, as: :json
      expect(turno.reload.visto_at).to be_nil
      expect(PushNotificationService).to have_received(:notify_user_async)
        .with(medico, hash_including(title: 'Te movieron un turno'))
    end

    it 'si se lo cancela, le avisa' do
      turno = dar_turno
      delete "/api/admin/turnos/#{turno.id}"
      expect(PushNotificationService).to have_received(:notify_user_async)
        .with(medico, hash_including(title: 'Te cancelaron un turno'))
    end

    it 'cambiar sólo el motivo no lo molesta' do
      turno = dar_turno
      expect(PushNotificationService).to have_received(:notify_user_async).once
      patch "/api/admin/turnos/#{turno.id}", params: { turno: { motivo: 'control' } }, as: :json
      expect(PushNotificationService).to have_received(:notify_user_async).once
    end
  end

  describe 'el mail' do
    it 'va a la casilla del médico, con el paciente y la hora, y sin el motivo de la consulta' do
      turno = ActsAsTenant.with_tenant(club) do
        Turno.create!(club: club, paciente: paciente, medico: medico, fecha_hora: Time.zone.parse('2026-10-14 15:30'),
                      duracion_minutos: 30, tipo: 'seguimiento', estado: 'programado', motivo: 'dolor crónico')
      end
      mail = TurnosMailer.aviso_medico(turno: turno, cambio: 'nuevo')
      expect(mail.to).to eq(['dra.lopez@ejemplo.com'])
      cuerpo = mail.text_part.body.to_s
      expect(cuerpo).to include('Ana Paz', '15:30', 'Lo vi')
      expect(mail.html_part.body.to_s).not_to include('dolor crónico')
      expect(cuerpo).not_to include('dolor crónico')
    end
  end

  describe '«Lo vi»' do
    it 'el médico confirma que lo vio y administración lo ve' do
      sign_in_as(admin)
      turno = dar_turno

      sign_in_as(medico)
      patch "/api/medico/turnos/#{turno.id}/visto"
      expect(response).to have_http_status(:ok)
      expect(turno.reload.visto_at).to be_present

      sign_in_as(admin)
      get "/api/admin/medicos/#{medico.id}/turnos"
      expect(JSON.parse(response.body).find { |t| t['id'] == turno.id }['visto_at']).to be_present
    end

    it 'no puede marcar como visto el turno de otro médico' do
      otro = create(:user, :medico, club: club)
      turno = ActsAsTenant.with_tenant(club) do
        Turno.create!(club: club, paciente: paciente, medico: otro, fecha_hora: 2.days.from_now,
                      duracion_minutos: 30, tipo: 'seguimiento', estado: 'programado')
      end
      sign_in_as(medico)
      patch "/api/medico/turnos/#{turno.id}/visto"
      expect(response).to have_http_status(:not_found)
      expect(turno.reload.visto_at).to be_nil
    end
  end

  describe 'el turno que se da el propio médico' do
    it 'nace visto y no se avisa a sí mismo' do
      sign_in_as(medico)
      post '/api/medico/turnos', params: { turno: { paciente_id: paciente.id, fecha_hora: 2.days.from_now,
                                                     duracion_minutos: 30, tipo: 'seguimiento' } }, as: :json
      expect(response).to have_http_status(:created)
      expect(Turno.last.visto_at).to be_present
      expect(PushNotificationService).not_to have_received(:notify_user_async)
    end
  end

  describe 'aislamiento de tenant' do
    it 'administración no le puede dar un turno con un paciente de otra organización' do
      otro_club = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro_club) do
        create(:paciente, club: otro_club, created_by: create(:user, :admin, club: otro_club))
      end
      sign_in_as(admin)
      post "/api/admin/medicos/#{medico.id}/crear_turno",
           params: { turno: { paciente_id: ajeno.id, fecha_hora: 2.days.from_now, duracion_minutos: 30, tipo: 'seguimiento' } },
           as: :json
      expect(response.status).to be >= 400
      expect(ActsAsTenant.without_tenant { Turno.where(paciente_id: ajeno.id).count }).to eq(0)
    end
  end
end
