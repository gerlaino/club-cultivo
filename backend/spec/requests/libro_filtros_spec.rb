require 'rails_helper'

# El club arma sectores → categorías → subcategorías justamente para poder leer su plata por
# esos cortes. El libro no ofrecía el filtro por sector, y filtrar por una categoría MADRE
# devolvía vacío porque los movimientos cuelgan de las hijas.
RSpec.describe 'Libro contable — filtros por sector y jerarquía', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  let(:cultivo) { club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo') }
  let(:buffet)  { club.unidades_negocio.create!(nombre: 'Buffet',  tipo: 'bar') }

  let(:insumos) do
    club.categorias_contables.create!(nombre: 'Insumos', tipo: 'egreso', unidad_negocio: cultivo)
  end
  let(:fertilizante) do
    club.categorias_contables.create!(nombre: 'Fertilizante', tipo: 'egreso', parent: insumos)
  end

  def mov(descripcion:, unidad: nil, categoria_contable: nil)
    club.movimientos_contables.create!(
      sede: sede, created_by: admin, tipo: 'egreso', categoria: 'insumo',
      descripcion: descripcion, monto_ars: 1000, fecha: Time.zone.today,
      pagado: true, medio_pago: 'efectivo',
      unidad_negocio: unidad, categoria_contable: categoria_contable,
    )
  end

  before { sign_in_as(admin) }

  def descripciones(params)
    get '/api/movimientos_contables', params: params
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)['movimientos'].map { |m| m['descripcion'] }
  end

  describe 'por sector' do
    before do
      mov(descripcion: 'Sustrato', unidad: cultivo)
      mov(descripcion: 'Vasos',    unidad: buffet)
    end

    it 'trae sólo lo del sector pedido' do
      expect(descripciones(unidad_negocio_id: cultivo.id)).to eq(['Sustrato'])
    end

    it 'sin filtro trae todo' do
      expect(descripciones({})).to contain_exactly('Sustrato', 'Vasos')
    end
  end

  describe 'por categoría' do
    before do
      mov(descripcion: 'Compra de fertilizante', categoria_contable: fertilizante)
      mov(descripcion: 'Gasto suelto')
    end

    # Lo que rompía: los movimientos cuelgan de la subcategoría, así que pedir la madre no
    # devolvía nada — y la madre es justo por donde uno quiere mirar primero.
    it 'la categoría madre trae lo de sus subcategorías' do
      expect(descripciones(categoria_contable_id: insumos.id)).to eq(['Compra de fertilizante'])
    end

    it 'la subcategoría filtra sólo por ella' do
      expect(descripciones(categoria_contable_id: fertilizante.id)).to eq(['Compra de fertilizante'])
    end
  end

  describe 'por tipo' do
    before do
      mov(descripcion: 'Un egreso')
      club.movimientos_contables.create!(
        sede: sede, created_by: admin, tipo: 'recupero_costo', categoria: 'dispensacion',
        descripcion: 'Recupero de dispensación', monto_ars: 500, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo',
      )
    end

    it 'separa el recupero de dispensación del resto' do
      expect(descripciones(tipo: 'recupero_costo')).to eq(['Recupero de dispensación'])
      expect(descripciones(tipo: 'egreso')).to eq(['Un egreso'])
    end
  end
end
