require 'rails_helper'

RSpec.describe CategoriaContable, type: :model do
  let(:club) { create(:club) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def cat(attrs = {})
    club.categorias_contables.create!({ nombre: 'X', tipo: 'egreso', comportamiento: 'general' }.merge(attrs))
  end

  describe '#familia_deposito / #tipo_insumo' do
    it 'mapea cada comportamiento a su depósito' do
      expect(cat(nombre: 'A', comportamiento: 'insumo').familia_deposito).to eq('cultivo')
      expect(cat(nombre: 'B', comportamiento: 'insumo_general').familia_deposito).to eq('general')
      expect(cat(nombre: 'C', comportamiento: 'mercaderia').familia_deposito).to eq('salon')
      expect(cat(nombre: 'D', comportamiento: 'general').familia_deposito).to be_nil
    end

    it 'tipo_insumo solo para depósitos de insumos (cultivo/general)' do
      expect(cat(nombre: 'A', comportamiento: 'insumo').tipo_insumo).to eq('cultivo')
      expect(cat(nombre: 'B', comportamiento: 'insumo_general').tipo_insumo).to eq('general')
      expect(cat(nombre: 'C', comportamiento: 'mercaderia').tipo_insumo).to be_nil
    end

    it 'la subcategoría hereda el comportamiento de la madre' do
      madre = cat(nombre: 'Insumos generales', comportamiento: 'insumo_general')
      sub   = club.categorias_contables.create!(nombre: 'Limpieza', tipo: 'egreso', comportamiento: 'general', parent: madre)
      expect(sub.comportamiento_efectivo).to eq('insumo_general')
      expect(sub.familia_deposito).to eq('general')
    end
  end
end
