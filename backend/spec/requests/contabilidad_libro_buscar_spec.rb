require 'rails_helper'

# BUSCAR EN EL LIBRO ES BUSCAR EN EL LIBRO ENTERO.
#
# El libro está paginado en el servidor y el buscador filtraba en el navegador los renglones de la
# página a la vista: un gasto que estaba en la página 2 no aparecía nunca y la pantalla contestaba
# "Probá ajustando los filtros" sobre un movimiento que existe. Lo reportó el socio de Germán
# junto con la paginación, que tampoco avanzaba.
RSpec.describe 'GET /movimientos_contables — buscar y paginar', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def json = JSON.parse(response.body)

  def gasto(descripcion, proveedor: nil, categoria_contable: nil)
    MovimientoContable.create!(club: club, created_by: admin, tipo: 'egreso', categoria: 'insumo',
                               categoria_contable: categoria_contable, descripcion: descripcion,
                               proveedor: proveedor, monto_ars: 1_000, fecha: Time.zone.today,
                               pagado: true)
  end

  before do
    sign_in_as(admin)
    25.times { |i| gasto("Gasto de relleno #{i}") }
  end

  describe 'el buscador' do
    it 'encuentra un movimiento que NO está en la primera página' do
      gasto('Calentador de Agua')

      get '/movimientos_contables', params: { q: 'calentador', per_page: 10 }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json['movimientos'].map { |m| m['descripcion'] }).to eq(['Calentador de Agua'])
      expect(json['pagination']['total']).to eq(1)
    end

    it 'busca también por proveedor' do
      gasto('Compra sin nombre propio', proveedor: 'Kawsay SRL')
      get '/movimientos_contables', params: { q: 'kawsay' }, headers: auth_headers
      expect(json['movimientos'].map { |m| m['descripcion'] }).to eq(['Compra sin nombre propio'])
    end

    it 'busca por el nombre de la categoría, y por la MADRE trae lo de sus hijas' do
      madre = CategoriaContable.create!(club: club, nombre: 'Bienes de Uso', tipo: 'egreso')
      hija  = CategoriaContable.create!(club: club, nombre: 'Herramientas', tipo: 'egreso', parent: madre)
      gasto('Red scrog', categoria_contable: hija)

      get '/movimientos_contables', params: { q: 'Bienes de Uso' }, headers: auth_headers
      expect(json['movimientos'].map { |m| m['descripcion'] }).to eq(['Red scrog'])
    end

    it 'los TOTALES responden a lo buscado, no al período entero' do
      gasto('Calentador de Agua')
      get '/movimientos_contables', params: { q: 'calentador' }, headers: auth_headers
      expect(json['totales']['egresos'].to_f).to eq(1_000.0)
    end

    it 'sin resultados devuelve la lista vacía, no el libro entero' do
      get '/movimientos_contables', params: { q: 'no existe este gasto' }, headers: auth_headers
      expect(json['movimientos']).to be_empty
      expect(json['pagination']['total']).to eq(0)
    end
  end

  describe 'la paginación' do
    it 'la página 2 trae renglones distintos de la 1' do
      get '/movimientos_contables', params: { page: 1, per_page: 10 }, headers: auth_headers
      primera = json['movimientos'].map { |m| m['id'] }
      expect(json['pagination']['total_pages']).to eq(3)

      get '/movimientos_contables', params: { page: 2, per_page: 10 }, headers: auth_headers
      segunda = json['movimientos'].map { |m| m['id'] }

      expect(segunda).not_to be_empty
      expect(segunda & primera).to be_empty
    end
  end

  # SE BAJA LO QUE SE ESTÁ MIRANDO. El export respetaba SÓLO las fechas: buscabas "Calentador",
  # veías una fila, apretabas Exportar y te bajabas las 27 del período. Los filtros salen ahora
  # del mismo método que los del libro.
  describe 'el export' do
    it 'respeta la búsqueda' do
      gasto('Calentador de Agua')

      get '/movimientos_contables/export_csv.csv', params: { q: 'calentador' }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      filas = response.body.lines.grep(/Gasto de relleno|Calentador/)
      expect(filas.size).to eq(1)
      expect(filas.first).to include('Calentador de Agua')
    end

    it 'respeta el tipo' do
      MovimientoContable.create!(club: club, created_by: admin, tipo: 'ingreso',
                                 categoria: 'aporte_socio', descripcion: 'Un aporte',
                                 monto_ars: 5_000, fecha: Time.zone.today, pagado: true)

      get '/movimientos_contables/export_csv.csv', params: { tipo: 'ingreso' }, headers: auth_headers
      expect(response.body).to include('Un aporte')
      expect(response.body).not_to include('Gasto de relleno')
    end

    it 'sin filtros los baja todos, como antes' do
      get '/movimientos_contables/export_csv.csv', headers: auth_headers
      expect(response.body.lines.grep(/Gasto de relleno/).size).to eq(25)
    end
  end
end