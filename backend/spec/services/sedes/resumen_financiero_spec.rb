require 'rails_helper'

RSpec.describe Sedes::ResumenFinanciero, type: :service do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def mov(tipo:, monto:, sede_ref: sede)
    club.movimientos_contables.create!(
      created_by: admin, tipo: tipo, categoria: 'otro', descripcion: "#{tipo} test",
      monto_ars: monto, fecha: Date.current, sede: sede_ref, pagado: true, medio_pago: 'efectivo'
    )
  end

  describe '#call' do
    it 'calcula el resultado del mes por sede (ingresos − egresos)' do
      mov(tipo: 'ingreso', monto: 5000)
      mov(tipo: 'egreso',  monto: 2000)

      fila = described_class.new(club).call[:por_sede].find { |f| f[:id] == sede.id }
      expect(fila[:ingresos_mes]).to eq(5000.0)
      expect(fila[:egresos_mes]).to eq(2000.0)
      expect(fila[:resultado_mes]).to eq(3000.0)
      expect(fila[:margen_pct]).to eq(60.0) # 3000/5000
    end

    it 'valoriza el capital inmovilizado (stock disponible + insumos del depósito)' do
      create(:stock, sede: sede, lote: lote, cantidad: 10, costo_unitario_ars: 100) # 1000
      club.insumos.create!(nombre: 'Fertilizante', unidad_medida: 'litro',
                           sede: sede, stock_actual: 5, costo_promedio_ars: 50)      # 250

      fila = described_class.new(club).call[:por_sede].find { |f| f[:id] == sede.id }
      expect(fila[:stock_ars]).to eq(1000.0)
      expect(fila[:insumos_ars]).to eq(250.0)
      expect(fila[:inventario_ars]).to eq(1250.0)
    end

    it 'consolida sumando las sedes e identifica la de mejor resultado' do
      sede2 = create(:sede, club: club, created_by: admin)
      mov(tipo: 'ingreso', monto: 5000, sede_ref: sede)   # resultado 5000
      mov(tipo: 'ingreso', monto: 1000, sede_ref: sede2)  # resultado 1000

      cons = described_class.new(club).call[:consolidado]
      expect(cons[:resultado_mes]).to eq(6000.0)
      expect(cons[:mejor_resultado][:id]).to eq(sede.id)
    end
  end
end
