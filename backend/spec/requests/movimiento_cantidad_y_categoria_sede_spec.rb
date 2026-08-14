require 'rails_helper'

# AC (Germán), alta de movimiento contable:
#   "…monto total → cantidad → unidad → … → se calcula costo unitario"
# y alta de categoría:
#   "Categoría → indicar sede → definir de qué sector → definir tipo de movimiento → indicar si
#    va a depósito".
#
# La cantidad vivía sólo adentro del bloque de inventario, así que un gasto que no entra a ningún
# depósito no tenía dónde decir "100.000 por 10 horas" y se quedaba sin costo unitario.
RSpec.describe 'Contabilidad: cantidad del movimiento y sede de la categoría', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  describe 'cantidad y unidad del movimiento' do
    def crear(attrs = {})
      post '/movimientos_contables', params: { movimiento_contable: {
        tipo: 'egreso', categoria: 'otro', descripcion: 'Electricista', monto_ars: 100_000,
        fecha: Time.zone.today.to_s,
      }.merge(attrs) }, headers: auth_headers
      JSON.parse(response.body)
    end

    it 'se guardan aunque el gasto no entre a ningún depósito' do
      datos = crear(cantidad: 10, unidad: 'hora')

      expect(response).to have_http_status(:created), response.body
      expect(datos['cantidad']).to eq(10.0)
      expect(datos['unidad']).to eq('hora')
    end

    it 'y de ahí sale el costo unitario' do
      expect(crear(cantidad: 10, unidad: 'hora')['costo_unitario_ars']).to eq(10_000.0)
    end

    # Es opcional: un alquiler no se compra por unidades.
    it 'sin cantidad el movimiento se guarda igual, sin unitario' do
      datos = crear

      expect(response).to have_http_status(:created), response.body
      expect(datos['costo_unitario_ars']).to be_nil
    end

    # Un 0 haría explotar la división; un negativo daría el unitario al revés.
    it 'rechaza una cantidad que no sea positiva' do
      crear(cantidad: 0)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # El unitario NO se guarda: se deriva. Si se guardara, corregir el monto dejaría un unitario
    # viejo que no se corresponde con ninguno de los dos números.
    it 'el unitario sigue al monto cuando se corrige' do
      id = crear(cantidad: 10, unidad: 'hora')['id']

      patch "/movimientos_contables/#{id}",
            params: { movimiento_contable: { monto_ars: 50_000 } }, headers: auth_headers

      expect(JSON.parse(response.body)['costo_unitario_ars']).to eq(5_000.0)
    end
  end

  describe 'sede de la categoría' do
    let(:unidad) { club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo') }

    def crear_categoria(attrs = {}, extras = {})
      post '/categorias_contables', params: {
        categoria_contable: { nombre: 'Maceta', tipo: 'egreso', unidad_negocio_id: unidad.id }.merge(attrs),
      }.merge(extras), headers: auth_headers
      JSON.parse(response.body)
    end

    it 'se puede acotar a una sede' do
      datos = crear_categoria(sede_id: sede.id)

      expect(response).to have_http_status(:created), response.body
      expect(datos['sede']['nombre']).to eq(sede.nombre)
    end

    it 'sin sede vale para toda la organización' do
      expect(crear_categoria['sede_id']).to be_nil
    end

    # La sede se hereda igual que el sector: una subcategoría es de la sede de su madre.
    it 'la subcategoría hereda la sede de la madre' do
      madre_id = crear_categoria(sede_id: sede.id)['id']

      sub = crear_categoria({ nombre: 'Maceta 5 L', parent_id: madre_id, unidad_negocio_id: nil })

      expect(sub['sede_id']).to eq(sede.id)
    end
  end

  describe '"va a depósito"' do
    let(:cultivo) { club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo') }
    let(:salon)   { club.unidades_negocio.create!(nombre: 'Buffet',  tipo: 'bar') }

    def crear(unidad, va)
      post '/categorias_contables', params: {
        categoria_contable: { nombre: "Cat #{unidad.nombre} #{va}", tipo: 'egreso',
                              unidad_negocio_id: unidad.id },
        va_a_deposito: va,
      }, headers: auth_headers
      JSON.parse(response.body)
    end

    # A QUÉ depósito va lo decide el SECTOR: elegido el sector no hay una segunda decisión, y no
    # puede contradecirlo.
    it 'una categoría de Cultivo que stockea va al depósito de cultivo' do
      datos = crear(cultivo, true)

      expect(datos['va_a_deposito']).to be(true)
      expect(datos['familia_deposito']).to eq('cultivo')
    end

    it 'una del Buffet va al salón' do
      expect(crear(salon, true)['familia_deposito']).to eq('salon')
    end

    it 'si no stockea, es puro gasto y no tiene depósito' do
      datos = crear(cultivo, false)

      expect(datos['va_a_deposito']).to be(false)
      expect(datos['familia_deposito']).to be_nil
    end
  end

  # Un sector "Cultivo" en una organización que no compró esa suite no tiene con qué llenarse.
  # Se INFORMA, no se filtra: sus movimientos históricos siguen existiendo y su columna del P&L
  # tiene que seguir cuadrando.
  describe 'sectores según el pack contratado' do
    def sectores
      get '/unidades_negocio', headers: auth_headers
      JSON.parse(response.body).index_by { |u| u['nombre'] }
    end

    before do
      club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo')
      club.unidades_negocio.create!(nombre: 'Buffet',  tipo: 'bar')
      club.unidades_negocio.create!(nombre: 'General', tipo: 'general')
    end

    it 'marca como no disponible el sector cuyo pack no está contratado' do
      club.update!(features: { 'cultivo' => true })

      expect(sectores['Cultivo']['disponible']).to be(true)
      expect(sectores['Buffet']['disponible']).to be(false)
    end

    it 'los que no dependen de ningún pack están siempre disponibles' do
      club.update!(features: {})

      expect(sectores['General']['disponible']).to be(true)
    end

    it 'pero sigue apareciendo en la lista: su historial no se esconde' do
      club.update!(features: {})

      expect(sectores.keys).to include('Cultivo', 'Buffet')
    end
  end
end
