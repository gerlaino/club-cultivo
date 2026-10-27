require 'rails_helper'

# EL CATÁLOGO DEL PORTAL (27-oct-2026): lo que hay hoy sobre la mesa de cada sede.
#
# AC: el paciente ve, por sede, los productos de la mesa con su precio y si hay («hay», «pocos»,
# «no hay hoy»), nunca cuántos. Sólo los de genéticas que la organización publica para el
# paciente. Lo que no está sobre la mesa (el depósito) no aparece. Nada de otra organización.
RSpec.describe 'Portal — el catálogo', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, nombre: 'Sede Centro', tipo: 'mixta') }
  let(:visible) { create(:genetica, club: club, nombre: 'Northern Lights', visible_paciente: true) }
  let(:oculta)  { create(:genetica, club: club, nombre: 'Secreta', visible_paciente: false) }

  def stock!(genetica, cantidad: 500, precio: 1000)
    Stock.create!(sede: sede, genetica: genetica, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: cantidad, precio_sugerido_ars: precio)
  end

  def a_la_mesa!(stock, gramos)
    Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga', cambios: [{ stock_id: stock.id, cantidad: gramos }])
  end

  let(:cuenta) do
    p = create(:paciente, club: club, created_by: admin, aprobado_at: Time.current)
    u = Pacientes::Acceso.crear!(p).user
    u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    u
  end

  def catalogo
    sign_in_as(cuenta)
    get '/api/portal/catalogo'
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)['data']
  end

  it 'muestra lo de la mesa, por sede, con precio y si hay — sin la cantidad' do
    a_la_mesa!(stock!(visible), 100)

    sede_json = catalogo.first
    expect(sede_json['sede']).to eq('Sede Centro')
    producto = sede_json['productos'].first
    expect(producto).to include('nombre' => 'Northern Lights', 'forma' => 'Flor seca', 'precio' => 1000.0, 'disponibilidad' => 'hay')
    expect(producto.keys).not_to include('cantidad')
    expect(response.body).not_to include('"100')
  end

  it 'con poco sobre la mesa dice «pocos»' do
    a_la_mesa!(stock!(visible), 8)
    expect(catalogo.first['productos'].first['disponibilidad']).to eq('pocos')
  end

  it 'no muestra genéticas que la organización no publica' do
    a_la_mesa!(stock!(visible), 100)
    a_la_mesa!(stock!(oculta), 100)

    nombres = catalogo.flat_map { |s| s['productos'].map { |p| p['nombre'] } }
    expect(nombres).to eq(['Northern Lights'])
  end

  it 'lo que está en el depósito y no en la mesa no aparece' do
    stock!(visible)
    expect(catalogo).to eq([])
  end

  it 'el equipo no entra al catálogo del portal (es del paciente)' do
    sign_in_as(admin)
    get '/api/portal/catalogo'
    expect(response).to have_http_status(:forbidden)
  end
end
