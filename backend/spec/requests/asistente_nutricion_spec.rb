require 'rails_helper'

# AC (Germán, 13-oct-2026): «hice un registro por voz en autocultivo… no me tomó el vege del
# depósito, no hizo el cálculo para descontar lo usado… un pulso a cada planta». El dictado
# propone cuánto (`Nutricion::DesdeDictado`), se muestra y se corrige, y al guardar lo confirmado
# se descuenta del depósito como un riego cargado a mano (`Nutricion::Aplicar`).
RSpec.describe 'Asistente: los nutrientes dictados se descuentan', type: :request do
  let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true, 'ia' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:carpa) { create(:sala, club: club, sede: sede, nombre: 'Carpa', kind: 'vegetativo', created_by: admin) }
  let!(:lote) { create(:lote, club: club, sala: carpa, codigo: 'L-26-001', estado: 'vegetativo') }
  let!(:vege) do
    i = club.insumos.create!(nombre: 'Vege', unidad_medida: 'mililitro', sede: sede, tipo: 'cultivo',
                             medida_casera: 'pulso', medida_casera_cantidad: 2)
    i.registrar_compra!(cantidad: 500, costo_total_ars: 5_000, created_by: admin, generar_egreso: false)
    i
  end

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before do
    6.times { create(:plant, lote: lote, state: 'vegetativo') }
    sign_in_as(admin)
  end

  def parsear_con(respuesta_ia)
    enviado = nil
    http = double('http', 'use_ssl=': true, 'read_timeout=': 30)
    allow(http).to receive(:request) do |req|
      enviado = JSON.parse(req.body)
      double(code: '200', body: { content: [{ text: respuesta_ia.to_json }], usage: {} }.to_json)
    end
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('clave-de-prueba')
    post '/api/asistente/parsear', params: { texto: 'le puse vege, un pulso a cada planta' }, as: :json
    expect(response).to have_http_status(:ok), response.body
    [response.parsed_body, enviado]
  end

  def ejecutar(acciones)
    post '/api/asistente/ejecutar', params: { acciones: acciones }, as: :json
    response.parsed_body
  end

  let(:dictado) do
    { 'resumen' => 'Riego con vege', 'acciones' => [{ 'tipo' => 'registro_ambiental_sala', 'sala_nombre' => 'Carpa',
      'datos' => { 'tareas_realizadas' => ['riego'], 'notas_fertilizacion' => 'vege, un pulso a cada planta',
                   'nutrientes' => [{ 'nombre' => 'Vege', 'cantidad' => 1, 'medida' => 'medida', 'por' => 'planta' }] } }] }
  end

  it 'la IA recibe los nutrientes por su nombre exacto, con su medida casera' do
    _, enviado = parsear_con({ 'resumen' => 'ok', 'acciones' => [] })
    sistema = enviado['system'].map { |b| b['text'] }.join
    expect(sistema).to include('NUTRIENTES: Vege (se mide en pulso)')
  end

  it 'el dictado vuelve con la cuenta hecha: 1 pulso (2 ml) × 6 plantas = 12 ml' do
    body, = parsear_con(dictado)
    n = body['acciones'].first['datos']['nutricion']

    expect(n['items'].first).to include('insumo_id' => vege.id, 'cantidad' => 12.0, 'detalle' => '1 pulso × 6 plantas')
    expect(body['acciones'].first['datos']['fertilizacion']).to be true
  end

  it 'al guardar, lo confirmado sale del depósito y queda en el registro' do
    body, = parsear_con(dictado)
    r = ejecutar(body['acciones'])

    expect(r['ejecutadas']).to eq(1), r.inspect
    expect(vege.reload.stock_actual.to_f).to eq(488.0)
    reg = lote.registros_ambientales.last
    expect(reg.nutricion['items'].first).to include('nombre' => 'Vege', 'descontado' => 12.0)
    expect(r['resultados'].first['mensaje']).to include('Se descontó del depósito: Vege 12 ml')
  end

  it 'si la persona corrigió la cantidad antes de guardar, se descuenta lo corregido' do
    body, = parsear_con(dictado)
    body['acciones'].first['datos']['nutricion']['items'].first['cantidad'] = 4
    ejecutar(body['acciones'])
    expect(vege.reload.stock_actual.to_f).to eq(496.0)
  end

  it 'los litros dictados quedan en el riego' do
    accion = dictado['acciones'].first.deep_dup
    accion['datos']['volumen_l'] = 3
    accion['tipo'] = 'registro_ambiental'
    accion['lote_codigo'] = 'L-26-001'
    ejecutar([accion])
    expect(lote.registros_ambientales.last.volumen_l.to_f).to eq(3.0)
  end

  it 'un insumo de otra organización en lo confirmado se ignora (no descuenta nada ajeno)' do
    otra = create(:club)
    ajeno = ActsAsTenant.with_tenant(otra) do
      i = otra.insumos.create!(nombre: 'Ajeno', unidad_medida: 'mililitro', tipo: 'cultivo')
      i.update_columns(stock_actual: 100)
      i
    end
    accion = dictado['acciones'].first.deep_dup
    accion['datos']['nutricion'] = { 'modo' => 'sueltos', 'items' => [{ 'insumo_id' => ajeno.id, 'cantidad' => 50 }] }
    r = ejecutar([accion])

    expect(r['ejecutadas']).to eq(1), r.inspect
    expect(ActsAsTenant.without_tenant { ajeno.reload.stock_actual.to_f }).to eq(100.0)
  end

  it 'un riego dictado sin nutrientes no toca el depósito' do
    ejecutar([{ 'tipo' => 'registro_ambiental_sala', 'sala_nombre' => 'Carpa', 'datos' => { 'tareas_realizadas' => ['riego'] } }])
    expect(vege.reload.stock_actual.to_f).to eq(500.0)
  end
end
