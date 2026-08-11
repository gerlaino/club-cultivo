require 'rails_helper'

# Dos cosas que se veían mal en pantalla y eran del backend:
#   1. El panel "Por categoría" decía "Otro" para TODO, porque agrupaba por el string legacy
#      `categoria` en vez de por la categoría contable que la organización creó.
#   2. El detalle de un movimiento mostraba el nombre de la SUBcategoría bajo el rótulo
#      "Categoría", sin la madre ni el sector.
RSpec.describe 'Contabilidad: categorías en resúmenes y detalle', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  let(:sector) { UnidadNegocio.create!(club: club, nombre: 'Cultivo', tipo: 'cultivo') }
  let(:madre) do
    CategoriaContable.create!(club: club, nombre: 'Fertilizantes', tipo: 'egreso',
                              unidad_negocio: sector, comportamiento: 'general')
  end
  let(:sub) do
    CategoriaContable.create!(club: club, nombre: 'Kawsay', tipo: 'egreso',
                              parent: madre, comportamiento: 'general')
  end

  def crear_movimiento(categoria, monto)
    MovimientoContable.create!(
      club: club, created_by: admin, tipo: 'egreso', descripcion: 'Base A',
      monto_ars: monto, fecha: Time.zone.today, categoria_contable: categoria
    )
  end

  before { sign_in_as(admin) }

  describe 'el resumen por categoría' do
    it 'agrupa por la categoría de la organización, no por "Otro"' do
      crear_movimiento(sub, 120_000)

      get '/movimientos_contables/dashboard', headers: auth_headers
      fila = JSON.parse(response.body).dig('mes_actual', 'por_categoria').first

      expect(fila['categoria']).to eq('Fertilizantes')
      expect(fila['categoria']).not_to eq('otro')
      expect(fila['total']).to eq(120_000.0)
    end

    # Un panel de un mes se lee por categoría; el desglose por subcategoría es otra pregunta y
    # vive en el libro diario. Si cada sub fuera su propia fila, "Fertilizantes" nunca aparecería.
    it 'suma las subcategorías dentro de su madre' do
      otra_sub = CategoriaContable.create!(club: club, nombre: 'Compost', tipo: 'egreso',
                                           parent: madre, comportamiento: 'general')
      crear_movimiento(sub, 100_000)
      crear_movimiento(otra_sub, 20_000)

      get '/movimientos_contables/dashboard', headers: auth_headers
      filas = JSON.parse(response.body).dig('mes_actual', 'por_categoria')

      expect(filas.size).to eq(1)
      expect(filas.first).to include('categoria' => 'Fertilizantes', 'total' => 120_000.0)
    end
  end

  describe 'el detalle de un movimiento' do
    it 'separa categoría, subcategoría y sector en vez de mostrar la sub como si fuera la madre' do
      mov = crear_movimiento(sub, 120_000)

      get "/movimientos_contables/#{mov.id}", headers: auth_headers
      json = JSON.parse(response.body)['data'] || JSON.parse(response.body)

      expect(json['categoria_madre']).to eq('Fertilizantes')
      expect(json['subcategoria']).to   eq('Kawsay')
      expect(json['categoria_ruta']).to eq('Fertilizantes › Kawsay')
      # El sector se hereda de la madre aunque la sub no lo tenga propio.
      expect(json.dig('unidad_negocio', 'nombre')).to eq('Cultivo')
    end

    it 'un movimiento colgado de la madre no inventa una subcategoría' do
      mov = crear_movimiento(madre, 50_000)

      get "/movimientos_contables/#{mov.id}", headers: auth_headers
      json = JSON.parse(response.body)['data'] || JSON.parse(response.body)

      expect(json['categoria_madre']).to eq('Fertilizantes')
      expect(json['subcategoria']).to   be_nil
      expect(json['categoria_ruta']).to eq('Fertilizantes')
    end
  end
end
