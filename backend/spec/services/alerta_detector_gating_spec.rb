require 'rails_helper'

# El detector es MIXTO: los cuatro detectores por lote son de la suite Cultivo y el de saldo
# de cuenta corriente es de Producción y dispensa. Un club que compró una sola de las dos
# recibía igual las alertas de la otra — de un módulo que ni siquiera ve en el menú.
RSpec.describe AlertaDetectorService, 'gating por suite' do
  let(:features) { Club::FEATURES_POR_DEFECTO.dup }
  let(:club)     { create(:club, features: features) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sala)     { create(:sala, club: club, created_by: admin) }

  # Lote viejo sin ningún registro ambiental → dispara 'sin_registro_ambiental'.
  let!(:lote) do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 30.days.ago)
  end

  # Paciente que agotó el crédito → dispara 'saldo_cc_bajo'. El margen que mira el detector es
  # `saldo_disponible + limite_credito`; con disponible en -límite queda en cero (pct <= 0).
  let!(:paciente) do
    create(:paciente, club: club, created_by: admin).tap do |p|
      cc = p.cuenta_corriente || create(:cuenta_corriente, paciente: p, club: club)
      cc.update!(limite_credito: 10_000, saldo_disponible: -10_000)
    end
  end

  def tipos_generados
    described_class.new(club).detectar!
    club.alertas_internas.pluck(:tipo).uniq
  end

  context 'club con las dos suites' do
    it 'genera alertas de cultivo y de cuenta corriente' do
      tipos = tipos_generados
      expect(tipos).to include('sin_registro_ambiental')
      expect(tipos).to include('saldo_cc_bajo')
    end
  end

  context 'club de SÓLO producción y dispensa (Cultivo apagado)' do
    let(:features) { Club::FEATURES_POR_DEFECTO.merge('cultivo' => false) }

    it 'no genera alertas de cultivo, pero sí la de cuenta corriente' do
      tipos = tipos_generados
      expect(tipos).not_to include('sin_registro_ambiental')
      expect(tipos).to include('saldo_cc_bajo')
    end
  end

  context 'club de SÓLO cultivo (Producción y dispensa apagado)' do
    let(:features) { Club::FEATURES_POR_DEFECTO.merge('produccion_dispensa' => false) }

    it 'genera las de cultivo, pero no la de cuenta corriente' do
      tipos = tipos_generados
      expect(tipos).to include('sin_registro_ambiental')
      expect(tipos).not_to include('saldo_cc_bajo')
    end
  end

  context 'club sin ninguna de las dos suites' do
    let(:features) { Club::FEATURES_POR_DEFECTO.merge('cultivo' => false, 'produccion_dispensa' => false) }

    it 'no genera ninguna alerta' do
      expect(tipos_generados).to be_empty
    end
  end
end
