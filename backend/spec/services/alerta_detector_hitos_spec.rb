require 'rails_helper'

# Lo que VIENE en el cultivo (uso personal, sep-2026): los hitos del ciclo se avisan con días de
# anticipación, una sola vez por lote, y salen de los objetivos que el lote ya tiene.
RSpec.describe AlertaDetectorService, '— hitos del cultivo' do
  let(:club) { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:sala) { create(:sala, club: club) }
  let(:user) { create(:user, :admin, club: club) }

  subject(:servicio) { described_class.new(club) }

  def hitos = club.alertas_internas.where(tipo: 'hito_cultivo')

  it 'avisa tres días antes de que el lote llegue a sus días de vegetativo' do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 28.days.ago, dias_vegetativo_objetivo: 30)

    expect { servicio.detectar! }.to change { hitos.count }.by(1)
    expect(hitos.last.mensaje).to include('30 días de vegetativo').and include('floración')
    expect(hitos.last.contexto['hito']).to eq('vege_objetivo')
  end

  it 'no avisa si todavía falta más que eso' do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 10.days.ago, dias_vegetativo_objetivo: 30)

    expect { servicio.detectar! }.not_to change { hitos.count }
  end

  it 'avisa una sola vez por hito y por lote' do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 29.days.ago, dias_vegetativo_objetivo: 30)

    servicio.detectar!
    expect { servicio.detectar! }.not_to change { hitos.count }
  end

  it 'la cosecha estimada se cuenta desde que entró a floración' do
    l = create(:lote, club: club, sala: sala, estado: 'floracion', start_date: 90.days.ago, dias_floracion_objetivo: 60)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
                           registrado_en: 58.days.ago, club: club, user: user)

    expect { servicio.detectar! }.to change { hitos.count }.by(1)
    expect(hitos.last.mensaje).to include('tricomas')
  end

  it 'el curado avisa a las tres semanas' do
    l = create(:lote, club: club, sala: sala, estado: 'curado', start_date: 120.days.ago)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'en_manicura', estado_nuevo: 'curado',
                           registrado_en: 20.days.ago, club: club, user: user)

    expect { servicio.detectar! }.to change { hitos.count }.by(1)
    expect(hitos.last.contexto['hito']).to eq('curado')
  end

  it 'una organización no los recibe salvo que los prenda' do
    org = create(:club, plan: 'basico', features: { 'cultivo' => true })
    # Con el tenant del ejemplo fijado en el otro club, acts_as_tenant pisaría el club_id.
    ActsAsTenant.with_tenant(org) do
      sala_org = create(:sala, club: org)
      create(:lote, club: org, sala: sala_org, estado: 'vegetativo', start_date: 29.days.ago, dias_vegetativo_objetivo: 30)

      expect { described_class.new(org).detectar! }.not_to change { org.alertas_internas.where(tipo: 'hito_cultivo').count }

      org.update!(alertas_config: { 'hitos_cultivo' => true })
      expect { described_class.new(org).detectar! }.to change { org.alertas_internas.where(tipo: 'hito_cultivo').count }.by(1)
    end
  end
end
