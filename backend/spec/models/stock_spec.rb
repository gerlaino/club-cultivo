require 'rails_helper'

RSpec.describe Stock, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  def build_stock(attrs = {})
    build(:stock, { sede: sede, lote: lote }.merge(attrs))
  end

  def create_stock(attrs = {})
    Stock.create!({
      sede: sede, lote: lote,
      origen: 'lote', forma_producto: 'flor_seca',
      unidad: 'g', cantidad: 100,
    }.merge(attrs))
  end

  # ── validaciones ──────────────────────────────────────────────────────────

  describe 'validaciones' do
    it 'es válido con datos correctos' do
      expect(build_stock).to be_valid
    end

    it 'requiere origen válido' do
      expect(build_stock(origen: 'invalido')).not_to be_valid
    end

    it 'requiere forma_producto válido' do
      expect(build_stock(forma_producto: 'invalido')).not_to be_valid
    end

    it 'requiere cantidad >= 0' do
      expect(build_stock(cantidad: -1)).not_to be_valid
    end

    it 'requiere estado válido' do
      expect(build_stock(estado: 'invalido')).not_to be_valid
    end

    context 'origen lote' do
      it 'requiere lote_id' do
        s = build(:stock, sede: sede, lote: nil, origen: 'lote')
        expect(s).not_to be_valid
        expect(s.errors[:lote_id]).not_to be_empty
      end
    end

    context 'origen derivado_lote' do
      it 'requiere lote_id' do
        s = build(:stock, sede: sede, lote: nil, origen: 'derivado_lote',
                  lote_origen_consumido_g: 10, forma_producto: 'hash')
        expect(s).not_to be_valid
        expect(s.errors[:lote_id]).not_to be_empty
      end

      it 'no puede ser flor_seca' do
        s = build(:stock, sede: sede, lote: lote, origen: 'derivado_lote',
                  lote_origen_consumido_g: 10, forma_producto: 'flor_seca')
        expect(s).not_to be_valid
        expect(s.errors[:forma_producto]).not_to be_empty
      end
    end

    context 'origen compra_externa' do
      it 'requiere proveedor' do
        s = build(:stock, sede: sede, lote: nil, origen: 'compra_externa',
                  forma_producto: 'flor_seca', proveedor: nil)
        expect(s).not_to be_valid
        expect(s.errors[:proveedor]).not_to be_empty
      end

      it 'no puede tener lote_id' do
        s = build(:stock, sede: sede, lote: lote, origen: 'compra_externa',
                  proveedor: 'Proveedor', forma_producto: 'flor_seca')
        expect(s).not_to be_valid
        expect(s.errors[:lote_id]).not_to be_empty
      end
    end
  end

  # ── callbacks before_create ───────────────────────────────────────────────

  describe 'callbacks' do
    it 'genera numero_lote_producto único al crear' do
      s = create_stock
      expect(s.numero_lote_producto).to match(/\AST-\d{2}-\d{4}\z/)
    end

    it 'genera codigo_qr al crear' do
      s = create_stock
      expect(s.codigo_qr).to be_present
    end

    it 'asigna club_id desde la sede' do
      s = create_stock
      expect(s.club_id).to eq(club.id)
    end

    context 'origen derivado_lote — descuenta stock flor seca' do
      it 'descuenta lote_origen_consumido_g del stock de flor seca del lote' do
        flor = create_stock(cantidad: 50)
        Stock.create!(
          sede: sede, lote: lote,
          origen: 'derivado_lote', forma_producto: 'hash',
          unidad: 'g', cantidad: 10,
          lote_origen_consumido_g: 10,
        )
        expect(flor.reload.cantidad).to eq(40)
      end

      it 'aborta si no hay stock de flor seca para el lote' do
        expect {
          Stock.create!(
            sede: sede, lote: lote,
            origen: 'derivado_lote', forma_producto: 'hash',
            unidad: 'g', cantidad: 10,
            lote_origen_consumido_g: 10,
          )
        }.to raise_error(ActiveRecord::RecordNotSaved)
      end

      it 'aborta si lote_origen_consumido_g excede el disponible' do
        create_stock(cantidad: 5)
        expect {
          Stock.create!(
            sede: sede, lote: lote,
            origen: 'derivado_lote', forma_producto: 'hash',
            unidad: 'g', cantidad: 10,
            lote_origen_consumido_g: 10,
          )
        }.to raise_error(ActiveRecord::RecordNotSaved)
      end
    end
  end

  # ── scopes ────────────────────────────────────────────────────────────────

  describe 'scopes' do
    describe '.disponibles' do
      it 'incluye stocks con cantidad > 0' do
        s = create_stock(cantidad: 1)
        expect(Stock.disponibles).to include(s)
      end

      it 'excluye stocks agotados (cantidad 0)' do
        s = create_stock(cantidad: 0)
        expect(Stock.disponibles).not_to include(s)
      end
    end

    describe '.regulatorios / .sociales' do
      it 'separa stocks por tipo de origen' do
        reg  = create_stock(origen: 'lote')
        soc  = create_stock(origen: 'compra_externa', lote: nil, proveedor: 'Prov', sede: sede,
                             forma_producto: 'flor_seca', unidad: 'g', cantidad: 10)
        expect(Stock.regulatorios).to include(reg)
        expect(Stock.sociales).to include(soc)
        expect(Stock.regulatorios).not_to include(soc)
      end
    end

    describe '.asignados / .pendientes_asignacion' do
      it 'filtra por estado' do
        pendiente = create_stock(estado: 'pendiente_asignacion')
        asignado  = create_stock(estado: 'asignado')
        expect(Stock.pendientes_asignacion).to include(pendiente)
        expect(Stock.asignados).to include(asignado)
        expect(Stock.asignados).not_to include(pendiente)
      end
    end
  end

  # ── métodos de instancia ──────────────────────────────────────────────────

  describe '#asignar!' do
    it 'actualiza sede y estado a asignado' do
      s = create_stock(estado: 'pendiente_asignacion', sede: nil, lote: lote)
      sede2 = create(:sede, club: club, created_by: admin)
      s.asignar!(sede: sede2, usuario: admin)
      expect(s.reload.estado).to eq('asignado')
      expect(s.reload.sede_id).to eq(sede2.id)
    end

    it 'crea un stock_movimiento de transferencia' do
      s = create_stock(estado: 'pendiente_asignacion', sede: nil, lote: lote)
      sede2 = create(:sede, club: club, created_by: admin)
      expect {
        s.asignar!(sede: sede2, usuario: admin)
      }.to change { s.stock_movimientos.count }.by(1)
    end
  end

  describe '#regulatorio?' do
    it 'es true para origen lote' do
      expect(create_stock(origen: 'lote').regulatorio?).to be true
    end

    it 'es false para compra_externa' do
      s = create_stock(origen: 'compra_externa', lote: nil, proveedor: 'P',
                       forma_producto: 'flor_seca', unidad: 'g', cantidad: 5, sede: sede)
      expect(s.regulatorio?).to be false
    end
  end
end
