require 'rails_helper'

RSpec.describe Ambiente::EvaluadorReglas do
  let(:club)  { create(:club) }
  let(:sala)  { create(:sala, club: club) }
  let(:regla) { create(:regla_ambiental, club: club, tipo_lectura: 'temperatura', condicion: 'gt', umbral_a: 30, duracion_minutos: 5) }

  def create_lectura(valor, fuente: 'webhook', ago: 1.minute)
    create(:lectura_ambiental,
      sala:     sala,
      club_id:  club.id,
      tipo:     'temperatura',
      valor:    valor,
      unidad:   '°C',
      fuente:   fuente,
      medido_at: ago.ago
    )
  end

  describe '.call' do
    it 'creates an alert when all recent readings violate the rule' do
      regla
      create_lectura(32)
      create_lectura(33, ago: 2.minutes)
      expect { described_class.call(sala) }.to change(Alerta, :count).by(1)
    end

    it 'does not create a duplicate alert if one already exists' do
      regla
      create_lectura(32)
      create(:alerta, regla: regla, sala: sala, club_id: club.id, estado: 'activa')
      expect { described_class.call(sala) }.not_to change(Alerta, :count)
    end

    it 'does not create an alert when readings do not violate the rule' do
      regla
      create_lectura(28)
      expect { described_class.call(sala) }.not_to change(Alerta, :count)
    end

    it 'ignores backfill readings' do
      regla
      create_lectura(35, fuente: 'backfill', ago: 3.minutes)
      expect { described_class.call(sala) }.not_to change(Alerta, :count)
    end

    it 'does not alert when no readings exist' do
      regla
      expect { described_class.call(sala) }.not_to change(Alerta, :count)
    end
  end
end
