require 'rails_helper'

RSpec.describe MovimientoContable, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def build_mov(attrs = {})
    club.movimientos_contables.build({
      sede: sede, created_by: admin, tipo: 'egreso',
      descripcion: 'Test', monto_ars: 1000, fecha: Date.today
    }.merge(attrs))
  end

  describe 'sede opcional (fix del 422)' do
    it 'se guarda sin sede' do
      mov = build_mov(sede: nil, categoria: 'otro')
      expect(mov.save).to be(true)
    end
  end

  describe 'derivación desde la categoría editable' do
    let(:unidad)    { club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo') }
    let(:categoria) { club.categorias_contables.create!(nombre: 'Insumo', tipo: 'egreso', clave_sistema: 'insumo', unidad_negocio: unidad) }

    it 'deriva el string legacy `categoria` desde clave_sistema' do
      mov = build_mov(categoria_contable: categoria, categoria: nil)
      mov.save!
      expect(mov.categoria).to eq('insumo')
    end

    it 'hereda la unidad de negocio de la categoría' do
      mov = build_mov(categoria_contable: categoria, categoria: nil)
      mov.save!
      expect(mov.unidad_negocio_id).to eq(unidad.id)
    end

    it 'una categoría propia sin clave_sistema cae en "otro" (válido en el enum)' do
      propia = club.categorias_contables.create!(nombre: 'Mercadería bar', tipo: 'egreso')
      mov = build_mov(categoria_contable: propia, categoria: nil)
      expect(mov.save).to be(true)
      expect(mov.categoria).to eq('otro')
    end

    it 'no pisa una categoría string explícita (movimientos de sistema)' do
      mov = build_mov(categoria_contable: categoria, categoria: 'dispensacion')
      mov.save!
      expect(mov.categoria).to eq('dispensacion')
    end

    it 'no pisa una unidad de negocio ya asignada a mano' do
      otra = club.unidades_negocio.create!(nombre: 'Bar', tipo: 'bar')
      mov = build_mov(categoria_contable: categoria, categoria: nil, unidad_negocio: otra)
      mov.save!
      expect(mov.unidad_negocio_id).to eq(otra.id)
    end
  end
end
