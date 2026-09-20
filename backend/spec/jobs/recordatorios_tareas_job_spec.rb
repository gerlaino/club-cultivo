require 'rails_helper'

# «Recordarme» al crear una tarea (Germán, 20-sep-2026): un push a quien está asignada, ese
# día o el día antes a las 8. Reemplaza al resumen genérico de las 8:00.
RSpec.describe RecordatoriosTareasJob do
  include ActiveJob::TestHelper

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:quien) { create(:user, :cultivador, club: club) }
  before do
    ENV['VAPID_PUBLIC_KEY'] = 'pub'
    PushSubscription.create!(user: quien, club: club, endpoint: 'https://push.example/q', p256dh_key: 'p', auth_key: 'a')
  end
  after { ENV.delete('VAPID_PUBLIC_KEY') }

  # Sólo los recordatorios: crear una tarea asignada también encola «Nueva tarea asignada».
  def encolados = enqueued_jobs.select { |j| j['job_class'] == 'PushNotificationJob' && j['arguments'].last['title'].to_s.start_with?('Recordatorio') }
  def tarea(**attrs) = ActsAsTenant.with_tenant(club) { create(:tarea, club: club, asignada_a: quien, **attrs) }

  it 'el mismo día, a las 8, le llega a quien está asignada; y una sola vez' do
    t = tarea(titulo: 'Regar la carpa', fecha_programada: Date.new(2026, 9, 21), recordatorio: 'mismo_dia')

    travel_to Time.zone.local(2026, 9, 21, 7, 50) do
      described_class.perform_now
      expect(encolados).to be_empty
    end
    travel_to Time.zone.local(2026, 9, 21, 8, 5) do
      described_class.perform_now
      expect(encolados.size).to eq(1)
      expect(encolados.first['arguments'].last).to include('title' => 'Recordatorio: Regar la carpa')
      expect(t.reload.recordatorio_enviado_at).to be_present
      described_class.perform_now
      expect(encolados.size).to eq(1)
    end
  end

  it 'el día antes, a las 8 del día anterior' do
    tarea(fecha_programada: Date.new(2026, 9, 22), recordatorio: 'dia_antes')
    travel_to Time.zone.local(2026, 9, 21, 8, 5) do
      described_class.perform_now
      expect(encolados.size).to eq(1)
      expect(encolados.first['arguments'].last['body']).to include('mañana')
    end
  end

  it 'si cambia la fecha, vuelve a contar' do
    t = tarea(fecha_programada: Date.new(2026, 9, 21), recordatorio: 'mismo_dia')
    travel_to(Time.zone.local(2026, 9, 21, 9)) { described_class.perform_now }
    ActsAsTenant.with_tenant(club) { t.reload.update!(fecha_programada: Date.new(2026, 9, 25)) }
    expect(t.reload.recordatorio_enviado_at).to be_nil
    travel_to(Time.zone.local(2026, 9, 25, 9)) { described_class.perform_now }
    expect(encolados.size).to eq(2)
  end

  it 'una tarea completada no recuerda nada' do
    tarea(fecha_programada: Date.new(2026, 9, 21), recordatorio: 'mismo_dia', estado: 'completada')
    travel_to(Time.zone.local(2026, 9, 21, 9)) { described_class.perform_now }
    expect(encolados).to be_empty
  end

  it 'respeta que la persona apagó los recordatorios de tareas' do
    quien.update!(notificaciones_config: { 'tipos' => { 'recordatorio_tarea' => false } })
    tarea(fecha_programada: Date.new(2026, 9, 21), recordatorio: 'mismo_dia')
    travel_to(Time.zone.local(2026, 9, 21, 9)) { described_class.perform_now }
    expect(encolados).to be_empty
  end
end
