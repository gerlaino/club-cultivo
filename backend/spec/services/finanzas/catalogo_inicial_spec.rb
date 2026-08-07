require 'rails_helper'

# AC (Germán): "el tema categoría y demás es para que sea más fácil el ingreso de movimientos
# para después poder filtrar y ver, mismo informes, siento que no está pasando eso".
#
# No estaba pasando porque el club arrancaba SIN NINGUNA categoría: el primer gasto se cargaba
# contra un combo vacío, había que inventar una taxonomía contable en el momento, y cada
# persona la inventaba distinta. Con eso no se puede filtrar nada ni sacar un informe que
# cierre — que es exactamente para lo que existen las categorías.
RSpec.describe Finanzas::SembrarCatalogo do
  let(:club) { create(:club) }

  before { described_class.new(club).call }

  def cats = ActsAsTenant.with_tenant(club) { CategoriaContable.where(club_id: club.id) }

  it 'el club arranca con categorías para elegir, no con un combo vacío' do
    expect(cats.count).to be > 0
  end

  it 'tiene de las dos clases: dónde se va la plata y de dónde entra' do
    expect(cats.where(tipo: 'egreso').count).to be > 0
    expect(cats.where(tipo: 'ingreso').count).to be > 0
  end

  it 'cubre los gastos de todo club: insumos, servicios, personal' do
    nombres = cats.pluck(:nombre).map(&:downcase)

    expect(nombres).to include('insumos', 'servicios', 'personal')
  end

  it 'y de dónde entra la plata de un club de cannabis' do
    nombres = cats.pluck(:nombre).map(&:downcase)

    expect(nombres).to include('aportes de socios')
  end

  # Las madres agrupan y las subcategorías son lo que se elige al cargar: sin subcategorías,
  # filtrar por "Insumos" no dice nada.
  it 'las categorías tienen subcategorías, que es lo que se elige al cargar' do
    madres = cats.where(parent_id: nil)

    expect(madres.count).to be > 0
    expect(cats.where.not(parent_id: nil).count).to be > 0
  end

  # El `comportamiento` es lo que decide si una compra entra al depósito. Sin eso puesto, el
  # inventario no se entera de nada.
  it 'las de insumos y mercadería saben que entran a un inventario' do
    con_stock = cats.where(comportamiento: %w[insumo insumo_general mercaderia])

    expect(con_stock.count).to be > 0
  end

  it 'cada categoría cuelga de un sector, que es lo que arma el P&L' do
    con_sector = cats.where(parent_id: nil).where.not(unidad_negocio_id: nil)

    expect(con_sector.count).to be > 0
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
