require 'rails_helper'

RSpec.describe Insumo, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def insumo(attrs = {})
    club.insumos.create!({ nombre: 'Fertilizante', unidad_medida: 'litro' }.merge(attrs))
  end

  describe '#registrar_compra!' do
    it 'suma stock y fija el costo promedio' do
      i = insumo
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1000, created_by: admin, generar_egreso: false)
      expect(i.stock_actual).to eq(10)
      expect(i.costo_promedio_ars).to eq(100) # 1000/10
    end

    it 'recalcula el promedio ponderado móvil en una segunda compra a otro precio' do
      i = insumo
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1000, created_by: admin, generar_egreso: false) # $100/u
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1400, created_by: admin, generar_egreso: false) # $140/u
      # (10*100 + 10*140) / 20 = 120
      expect(i.stock_actual).to eq(20)
      expect(i.costo_promedio_ars).to eq(120)
    end

    it 'genera un egreso contable por la compra' do
      i = insumo
      expect {
        i.registrar_compra!(cantidad: 5, costo_total_ars: 500, created_by: admin)
      }.to change { club.movimientos_contables.where(categoria: 'insumo', tipo: 'egreso').count }.by(1)
    end
  end

  describe '#registrar_consumo!' do
    it 'descuenta stock e imputa el costo al promedio del momento' do
      i = insumo
      i.registrar_compra!(cantidad: 20, costo_total_ars: 2400, created_by: admin, generar_egreso: false) # $120/u
      consumo = i.registrar_consumo!(cantidad: 3, lote: lote, created_by: admin)
      expect(i.stock_actual).to eq(17)
      expect(consumo.costo_imputado_ars).to eq(360) # 3 * 120
    end

    it 'lanza si no hay stock suficiente' do
      i = insumo
      i.registrar_compra!(cantidad: 2, costo_total_ars: 100, created_by: admin, generar_egreso: false)
      expect { i.registrar_consumo!(cantidad: 5, created_by: admin) }.to raise_error(ArgumentError, /insuficiente/)
    end

    it 'refleja el costo imputado en el CostoLote del lote' do
      i = insumo
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1000, created_by: admin, generar_egreso: false)
      i.registrar_consumo!(cantidad: 4, lote: lote, created_by: admin) # 4 * 100 = 400
      expect(lote.reload.costo_lote.costo_insumos.to_f).to be >= 400.0
    end
  end

  describe '#registrar_consumo_repartido!' do
    let(:sala2) { create(:sala, club: club, created_by: admin) }
    let(:lote2) { create(:lote, club: club, sala: sala2) }

    it 'reparte la cantidad en partes iguales entre los lotes' do
      i = insumo
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1000, created_by: admin, generar_egreso: false)
      consumos = i.registrar_consumo_repartido!(cantidad: 3, lotes: [lote, lote2], created_by: admin)
      expect(consumos.size).to eq(2)
      expect(consumos.sum(&:cantidad)).to eq(3)          # suma exacta (el último absorbe redondeo)
      expect(i.reload.stock_actual).to eq(7)
      expect(consumos.map(&:lote_id)).to match_array([lote.id, lote2.id])
    end
  end

  describe '#avisar_reposicion!' do
    it 'crea una alerta stock_bajo cuando el consumo deja el stock en el mínimo' do
      i = insumo(stock_minimo: 5)
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1000, created_by: admin, generar_egreso: false)
      expect { i.registrar_consumo!(cantidad: 6, lote: lote, created_by: admin) } # queda 4 <= 5
        .to change { club.alertas_internas.where(tipo: 'stock_bajo').count }.by(1)
    end

    it 'no duplica el aviso dentro de la ventana anti-spam' do
      i = insumo(stock_minimo: 5)
      i.registrar_compra!(cantidad: 10, costo_total_ars: 1000, created_by: admin, generar_egreso: false)
      i.registrar_consumo!(cantidad: 6, lote: lote, created_by: admin)
      expect { i.registrar_consumo!(cantidad: 1, lote: lote, created_by: admin) }
        .not_to change { club.alertas_internas.where(tipo: 'stock_bajo').count }
    end
  end
end
