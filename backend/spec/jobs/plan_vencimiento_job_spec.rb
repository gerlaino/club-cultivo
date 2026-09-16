require 'rails_helper'

# AC (sep-2026): la organización se entera de que su plan vence. Siete días antes y el día que
# vence: campana para el admin, push y mail por la casilla de la plataforma. Informativo — no
# corta nada.
RSpec.describe PlanVencimientoJob do
  let(:hoy)   { Time.zone.today }
  let(:club)  { create(:club, plan_activo_hasta: hoy + 7) }
  let!(:admin) { create(:user, :admin, club: club, email_personal: 'admin@gmail.com') }

  def alertas(c) = ActsAsTenant.with_tenant(c) { AlertaInterna.where(club: c).to_a }

  it 'siete días antes avisa al admin, con push y mail' do
    expect(PushNotificationService).to receive(:notify_admins_async).with(club, hash_including(title: 'Tu plan vence en una semana'))

    expect { described_class.perform_now(hoy: hoy) }
      .to have_enqueued_mail(AccesoMailer, :plan_vence)

    a = alertas(club).find { |x| x.tipo == 'plan_por_vencer' }
    expect(a).to be_present
    expect(a.destinada_a_role).to eq('admin')
    expect(a.mensaje).to include('en 7 días')
  end

  it 'el día que vence avisa distinto' do
    club.update!(plan_activo_hasta: hoy)
    allow(PushNotificationService).to receive(:notify_admins_async)

    described_class.perform_now(hoy: hoy)

    expect(alertas(club).map(&:tipo)).to include('plan_vencido')
  end

  it 'en cualquier otro día no hace nada' do
    club.update!(plan_activo_hasta: hoy + 3)

    described_class.perform_now(hoy: hoy)

    expect(alertas(club)).to be_empty
  end

  it 'no repite el aviso si corre dos veces el mismo día' do
    allow(PushNotificationService).to receive(:notify_admins_async)

    2.times { described_class.perform_now(hoy: hoy) }

    expect(alertas(club).size).to eq(1)
  end

  it 'una organización sin vencimiento o demo no recibe nada' do
    club.update!(plan_activo_hasta: nil)
    demo = create(:club, demo: true, plan_activo_hasta: hoy + 7)

    described_class.perform_now(hoy: hoy)

    expect(alertas(club)).to be_empty
    expect(alertas(demo)).to be_empty
  end
end
