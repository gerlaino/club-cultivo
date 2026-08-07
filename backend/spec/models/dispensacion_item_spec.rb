require 'rails_helper'

RSpec.describe DispensacionItem, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin)) }
  let(:pac)   { create(:paciente, club: club, created_by: admin, email: 'p@g.com') }
  let(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 10) }
  let(:disp) do
    Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 5,
                         medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 50)
  end

  describe 'asociaciones y validaciones' do
    it 'pertenece a una dispensación y opcionalmente a un stock' do
      item = disp.items.create!(stock: stock, cantidad: 3, precio_unitario_ars: 10)
      expect(item.dispensacion).to eq(disp)
      expect(item.stock).to eq(stock)
    end

    it 'rechaza cantidad <= 0' do
      item = disp.items.build(stock: stock, cantidad: 0)
      expect(item).not_to be_valid
    end
  end

  describe 'cálculos de la línea' do
    it 'calcula subtotal y costo total' do
      item = disp.items.create!(stock: stock, cantidad: 4, precio_unitario_ars: 10, costo_unitario_ars: 3)
      expect(item.subtotal_ars).to eq(40)
      expect(item.costo_total_ars).to eq(12)
    end
  end

  describe 'invariante puente (línea espejo)' do
    it 'una dispensa legacy de un stock genera automáticamente su línea espejo' do
      d = Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 7,
                               medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 70,
                               precio_unitario_ars: 10)
      expect(d.items.count).to eq(1)
      linea = d.items.first
      expect(linea.stock_id).to eq(stock.id)
      expect(linea.cantidad).to eq(7)
      expect(linea.precio_unitario_ars).to eq(10)
      expect(linea.lote_codigo).to eq(d.lote_codigo) # hereda el snapshot de trazabilidad
    end

    it 'cantidad_total y multi_stock? derivan de las líneas' do
      expect(disp.cantidad_total).to eq(5)
      expect(disp.multi_stock?).to be false
    end
  end

  describe 'soft-delete (papelera)' do
    it 'es paranoid: se puede borrar y restaurar' do
      item = disp.items.create!(stock: stock, cantidad: 2, precio_unitario_ars: 10)
      item.destroy
      expect(DispensacionItem.find_by(id: item.id)).to be_nil
      expect(DispensacionItem.with_deleted.find(item.id)).to be_present
      item.restore
      expect(DispensacionItem.find_by(id: item.id)).to be_present
    end

    it 'cascada: borrar la dispensación borra (lógico) sus líneas' do
      disp.items.create!(stock: stock, cantidad: 2, precio_unitario_ars: 10)
      disp.destroy
      expect(disp.items.with_deleted.first.deleted_at).to be_present
    end
  end
end
