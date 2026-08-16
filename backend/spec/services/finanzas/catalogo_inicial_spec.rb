require 'rails_helper'

# CAMBIO DE CRITERIO (Germán, 16-ago-2026): "no entiendo por qué los clubes tienen categorías
# precargadas que no pueden eliminar... sólo quiero sectores predeterminados con sus respectivos
# depósitos, pero las categorías que cada admin las cree".
#
# Se habían sembrado (Fertilizante, Sueldos, Alquiler…) para que el primer gasto no se cargara
# contra un combo vacío. En la práctica cada organización gasta en cosas distintas, y una lista
# ajena que además no se puede borrar —eran `es_sistema`— ocupa el selector con cosas que no usan
# y esconde las suyas.
RSpec.describe Finanzas::SembrarCatalogo do
  let(:club) { create(:club) }

  before { described_class.new(club).call }

  def cats = ActsAsTenant.with_tenant(club) { CategoriaContable.where(club_id: club.id) }
  def sectores = ActsAsTenant.with_tenant(club) { club.unidades_negocio }

  it 'siembra los sectores, que son lo único predeterminado' do
    expect(sectores.pluck(:nombre)).to include('General', 'Cultivo', 'Dispensario', 'Otro')
  end

  it 'y NINGUNA categoría: las crea el admin de cada organización' do
    expect(cats.count).to eq(0)
  end

  # `con_arbol: true` queda sólo para los specs que necesitan un catálogo de ejemplo.
  describe 'con el árbol de ejemplo pedido explícitamente' do
    before { described_class.new(club).call(con_arbol: true) }

    it 'las categorías son de un solo nivel' do
      expect(cats.count).to be > 0
      expect(cats.where.not(parent_id: nil).count).to eq(0)
    end

    it 'y las que stockean saben a qué inventario entran' do
      expect(cats.where(comportamiento: %w[insumo insumo_general mercaderia]).count).to be > 0
    end
  end

  it 'cada categoría de ejemplo cuelga de un sector, que es lo que arma el P&L' do
    described_class.new(club).call(con_arbol: true)

    expect(cats.where(unidad_negocio_id: nil).pluck(:nombre)).to eq([])
  end

  # Sembrar dos veces no puede duplicar: el catálogo se re-asegura cuando alguien entra a
  # Finanzas o crea un depósito.
  it 'sembrar de nuevo no duplica nada' do
    antes = cats.count

    described_class.new(club).call

    expect(cats.count).to eq(antes)
  end

  it 'los sectores también quedan puestos' do
    unidades = ActsAsTenant.with_tenant(club) { UnidadNegocio.where(club_id: club.id) }

    expect(unidades.pluck(:nombre)).to include('Cultivo', 'Dispensario', 'General')
  end
end
