require 'rails_helper'

# Stock bajo = poca FLOR SECA, por TOTAL y por SEDE (no por contenedor, sin derivados).
RSpec.describe StockBajoJob, type: :job do
  let(:club)   { create(:club, umbral_stock_g: 100) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede_a) { create(:sede, club: club, created_by: admin) }
  let(:sede_b) { create(:sede, club: club, created_by: admin) }

  def flor(sede, cant)
    create(:stock, :externo, club: club, sede: sede,
           forma_producto: 'flor_seca', cantidad: cant, estado: 'asignado')
  end

  it 'alerta una vez por sede cuyo TOTAL de flor seca está bajo el umbral' do
    flor(sede_a, 40); flor(sede_a, 30) # total A = 70 < 100 → alerta
    flor(sede_b, 150)                  # total B = 150 ≥ 100 → sin alerta

    expect { described_class.perform_now }
      .to change { AlertaInterna.where(tipo: 'stock_bajo').count }.by(1)

    a = AlertaInterna.where(tipo: 'stock_bajo').last
    expect(a.contexto['sede_id']).to eq(sede_a.id)
    expect(a.contexto['total_g']).to eq(70.0)
  end

  it 'no alerta por derivados bajos (solo cuenta flor seca)' do
    create(:stock, :externo, club: club, sede: sede_a,
           forma_producto: 'hash', cantidad: 5, estado: 'asignado')
    expect { described_class.perform_now }
      .not_to change { AlertaInterna.where(tipo: 'stock_bajo').count }
  end

  it 'no duplica la alerta de una sede dentro de las 24h' do
    flor(sede_a, 10)
    described_class.perform_now
    expect { described_class.perform_now }
      .not_to change { AlertaInterna.where(tipo: 'stock_bajo').count }
  end
end
