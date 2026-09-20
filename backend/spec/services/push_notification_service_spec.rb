require 'rails_helper'

# Antes de encolar un push se mira si la persona lo quiere (`Notificaciones::Catalogo`) y si
# está en «no molestar».
RSpec.describe PushNotificationService do
  include ActiveJob::TestHelper

  let(:club)  { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  before do
    PushSubscription.create!(user: admin, club: club, endpoint: 'https://push.example/a', p256dh_key: 'p', auth_key: 'a')
  end

  def encolados = enqueued_jobs.select { |j| j['job_class'] == 'PushNotificationJob' }

  it 'manda lo que la persona tiene prendido' do
    described_class.notify_admins_async(club, tipo: 'caja_sin_cerrar', title: 'Caja', body: 'x')
    expect(encolados.size).to eq(1)
  end

  it 'NO manda lo que apagó' do
    admin.update!(notificaciones_config: { 'tipos' => { 'caja_sin_cerrar' => false } })
    described_class.notify_admins_async(club, tipo: 'caja_sin_cerrar', title: 'Caja', body: 'x')
    expect(encolados).to be_empty
  end

  it 'NO manda un tipo que a ese rol no se le ofrece, aunque el disparador se lo pida' do
    cultivador = create(:user, :cultivador, club: club)
    PushSubscription.create!(user: cultivador, club: club, endpoint: 'https://push.example/c', p256dh_key: 'p', auth_key: 'a')
    described_class.notify_user_async(cultivador, tipo: 'caja_sin_cerrar', title: 'Caja', body: 'x')
    expect(encolados).to be_empty
  end

  it 'sin tipo (una prueba desde consola) manda siempre' do
    admin.update!(notificaciones_config: { 'tipos' => { 'caja_sin_cerrar' => false } })
    described_class.notify_user_async(admin, title: 'Prueba', body: 'x')
    expect(encolados.size).to eq(1)
  end

  describe 'no molestar (22 a 8)' do
    before { admin.update!(notificaciones_config: { 'no_molestar' => true }) }

    it 'a las 23 se posterga hasta las 8 del día siguiente' do
      travel_to Time.zone.local(2026, 9, 20, 23, 15) do
        described_class.notify_user_async(admin, tipo: 'caja_sin_cerrar', title: 'Caja', body: 'x')
        expect(encolados.size).to eq(1)
        expect(Time.zone.at(encolados.first[:at])).to eq(Time.zone.local(2026, 9, 21, 8, 0))
      end
    end

    it 'a las 7 se posterga hasta las 8 de hoy' do
      travel_to Time.zone.local(2026, 9, 21, 7, 0) do
        described_class.notify_user_async(admin, tipo: 'hitos_cultivo', title: 'Hito', body: 'x')
        expect(Time.zone.at(encolados.first[:at])).to eq(Time.zone.local(2026, 9, 21, 8, 0))
      end
    end

    it 'a las 15 va en el acto' do
      travel_to Time.zone.local(2026, 9, 21, 15, 0) do
        described_class.notify_user_async(admin, tipo: 'hitos_cultivo', title: 'Hito', body: 'x')
        expect(encolados.first[:at]).to be_nil
      end
    end
  end
end
