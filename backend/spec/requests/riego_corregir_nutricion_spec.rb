require 'rails_helper'

# AC (Germán, 13-oct-2026): «en caso de querer cambiarlo después, se debería poder editar el
# registro de riego y sus parámetros». Editar es DESHACER el riego entero (vuelve al depósito, el
# costo sale de los lotes) y volver a aplicarlo con lo nuevo (`Nutricion::Editar`).
RSpec.describe 'Corregir los nutrientes de un riego guardado', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', codigo: 'L-1') }
  let(:lote2) { create(:lote, club: club, sala: sala, estado: 'vegetativo', codigo: 'L-2') }

  def insumo(nombre, cantidad)
    ActsAsTenant.with_tenant(club) do
      i = club.insumos.create!(nombre: nombre, unidad_medida: 'mililitro', sede: sede, tipo: 'cultivo')
      i.registrar_compra!(cantidad: cantidad, costo_total_ars: cantidad * 10, created_by: admin, generar_egreso: false)
      i
    end
  end
  let!(:vege)   { insumo('Vege', 500) }
  let!(:kawsay) { insumo('Kawsay Vege', 300) }

  def regar(items, lote_obj = lote)
    post "/lotes/#{lote_obj.id}/registros_ambientales",
         params: { registro_ambiental: { fertilizacion: true, tareas_realizadas: ['riego'] }, nutricion: { items: items } }, as: :json
    expect(response).to have_http_status(:created), response.body
    response.parsed_body['id']
  end

  def corregir(registro_id, nutricion, lote_obj = lote)
    patch "/lotes/#{lote_obj.id}/registros_ambientales/#{registro_id}/nutricion", params: { nutricion: nutricion }, as: :json
  end

  def stock(i) = ActsAsTenant.with_tenant(club) { i.reload.stock_actual.to_f }

  before { sign_in_as(admin) }

  it '«vege» era Kawsay: lo de vege vuelve y se descuenta Kawsay' do
    id = regar([{ insumo_id: vege.id, cantidad: 12 }])
    expect(stock(vege)).to eq(488.0)

    corregir(id, { modo: 'sueltos', items: [{ insumo_id: kawsay.id, cantidad: 12 }] })

    expect(response).to have_http_status(:ok), response.body
    expect(stock(vege)).to eq(500.0)
    expect(stock(kawsay)).to eq(288.0)
    reg = ActsAsTenant.with_tenant(club) { RegistroAmbiental.find(id) }
    expect(reg.nutricion['items'].map { |i| i['nombre'] }).to eq(['Kawsay Vege'])
  end

  it 'cambiar sólo la cantidad: vuelve lo de antes y sale lo nuevo' do
    id = regar([{ insumo_id: vege.id, cantidad: 12 }])
    corregir(id, { modo: 'sueltos', items: [{ insumo_id: vege.id, cantidad: 4 }] })
    expect(stock(vege)).to eq(496.0)
  end

  it '«nada del depósito»: deshace lo aplicado y queda un riego con agua sola' do
    id = regar([{ insumo_id: vege.id, cantidad: 12 }])
    corregir(id, { modo: 'ninguno' })
    expect(stock(vege)).to eq(500.0)
    reg = ActsAsTenant.with_tenant(club) { RegistroAmbiental.find(id) }
    expect(reg.nutricion).to be_nil
    expect(reg.fertilizacion).to be false
  end

  it 'abre con lo aplicado, para corregirlo' do
    id = regar([{ insumo_id: vege.id, cantidad: 12 }])
    get "/lotes/#{lote.id}/registros_ambientales/#{id}/nutricion", as: :json
    body = response.parsed_body
    expect(body['bloqueo']).to be_nil
    expect(body['nutricion']['items']).to eq([{ 'insumo_id' => vege.id, 'cantidad' => 12.0, 'modo_faltante' => 'descontar_disponible' }])
  end

  it 'un riego de toda la sala se corrige entero, desde cualquiera de sus lotes' do
    lote; lote2
    post "/salas/#{sala.id}/registrar_sala", params: {
      registro_ambiental: { fertilizacion: true, tareas_realizadas: ['riego'], volumen_l: 10 },
      nutricion: { items: [{ insumo_id: vege.id, cantidad: 20 }] } }, as: :json
    expect(response).to have_http_status(:created), response.body
    expect(stock(vege)).to eq(480.0)
    id2 = ActsAsTenant.with_tenant(club) { lote2.registros_ambientales.last.id }

    corregir(id2, { modo: 'sueltos', items: [{ insumo_id: vege.id, cantidad: 6 }] }, lote2)

    expect(response).to have_http_status(:ok), response.body
    expect(response.parsed_body['registros']).to eq(2)
    expect(stock(vege)).to eq(494.0) # se descontó UNA vez lo nuevo, no una por lote
  end

  it 'no se corrige un riego de un lote ya cosechado: su costo pasó a la cosecha' do
    id = regar([{ insumo_id: vege.id, cantidad: 12 }])
    ActsAsTenant.with_tenant(club) { lote.update_columns(estado: 'cosecha') }

    get "/lotes/#{lote.id}/registros_ambientales/#{id}/nutricion", as: :json
    expect(response.parsed_body['bloqueo']).to include('ya se cosechó')

    corregir(id, { modo: 'sueltos', items: [{ insumo_id: vege.id, cantidad: 1 }] })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(stock(vege)).to eq(488.0)
  end

  it 'un cultivador corrige SU riego, no el de otro' do
    id_admin = regar([{ insumo_id: vege.id, cantidad: 12 }])
    sign_in_as(cultivador)
    corregir(id_admin, { modo: 'sueltos', items: [{ insumo_id: vege.id, cantidad: 1 }] })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('Sólo quien lo registró')
    expect(stock(vege)).to eq(488.0)
  end

  it 'el historial del lote marca qué riegos se pueden corregir' do
    regar([{ insumo_id: vege.id, cantidad: 12 }])
    get "/lotes/#{lote.id}/historial", as: :json
    item = response.parsed_body['historial'].find { |i| i['source'] == 'registro_ambiental' }
    expect(item['nutricion_editable']).to be true
  end

  it 'aislamiento: no se abre ni se corrige un riego de otra organización' do
    otra  = create(:club, features: { 'cultivo' => true })
    otro_admin = create(:user, :admin, club: otra)
    ajeno = ActsAsTenant.with_tenant(otra) do
      s = create(:sala, club: otra, created_by: otro_admin, kind: 'vegetativo')
      l = create(:lote, club: otra, sala: s, estado: 'vegetativo')
      [l, l.registros_ambientales.create!(club: otra, user: otro_admin, registrado_en: Time.current, tareas_realizadas: ['riego'])]
    end
    l, reg = ajeno

    get "/lotes/#{l.id}/registros_ambientales/#{reg.id}/nutricion", as: :json
    expect(response).to have_http_status(:not_found)
    corregir(reg.id, { modo: 'ninguno' }, l)
    expect(response).to have_http_status(:not_found)
  end
end
