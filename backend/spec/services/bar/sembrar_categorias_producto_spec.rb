require 'rails_helper'

RSpec.describe Bar::SembrarCategoriasProducto, type: :service do
  let(:club) { create(:club) }
  def con_tenant(&blk) = ActsAsTenant.with_tenant(club, &blk)

  it 'siembra las categorías default (Bebidas, Cocina, Merch, Otros)' do
    described_class.new(club).call
    con_tenant do
      nombres = club.categorias_producto.ordenadas.pluck(:nombre)
      expect(nombres).to eq(['Bebidas', 'Cocina', 'Merchandising', 'Otros'])
      expect(club.categorias_producto.first).to be_es_sistema
    end
  end

  it 'backfillea el producto del bar a su categoría editable según el enum' do
    prod = con_tenant { create(:bar_producto, club: club, categoria: 'cocina') }
    described_class.new(club).call
    con_tenant do
      expect(prod.reload.categoria_producto.clave_sistema).to eq('cocina')
    end
  end

  it 'cuelga el producto del bar del depósito Salón si existe' do
    club.update!(features: club.features.merge('bar' => true))
    Finanzas::SembrarDepositos.new(club).call # crea el depósito Salón
    prod = con_tenant { create(:bar_producto, club: club) }
    described_class.new(club).call
    con_tenant do
      expect(prod.reload.deposito.clave_sistema).to eq('salon')
    end
  end

  it 'es idempotente: no duplica ni pisa el nombre editado' do
    described_class.new(club).call
    con_tenant { club.categorias_producto.find_by(clave_sistema: 'bebida').update!(nombre: 'Tragos') }
    expect { described_class.new(club).call }.not_to change { con_tenant { club.categorias_producto.count } }
    con_tenant { expect(club.categorias_producto.find_by(clave_sistema: 'bebida').nombre).to eq('Tragos') }
  end
end
