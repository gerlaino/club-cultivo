require 'rails_helper'

# AC (9-oct-2026, Germán): en autocultivo, el registro por voz también CREA plantas. «Una semilla de
# tal genética», «un esqueje de tal genética de tantos días en maceta de tanto» o «en un vaso» (=
# maceta de 0,335 L). Usa la misma alta que el formulario, así que las plantas se llaman por su
# genética. En una organización el dictado NO crea lotes.
RSpec.describe 'Asistente: crear plantas dictando (autocultivo)', type: :request do
  let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true, 'ia' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let!(:carpa) { create(:sala, club: club, sede: sede, nombre: 'Carpa chica', kind: 'vegetativo', created_by: admin) }
  let!(:ananda) { create(:genetica, club: club, nombre: 'Ananda') }
  let!(:gorilla) { create(:genetica, club: club, nombre: 'Gorilla Glue') }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  def ejecutar(acciones)
    post '/api/asistente/ejecutar', params: { acciones: acciones }, as: :json
    response.parsed_body
  end

  def plantas = Plant.joins(:lote).where(lotes: { club_id: club.id })

  it 'dos semillas de una genética: dos plantas germinando, con el nombre de la genética' do
    r = ejecutar([{ tipo: 'nueva_planta', sala_nombre: 'Carpa chica',
                    datos: { genetica_nombre: 'Ananda', cantidad: 2, origen: 'semilla', en_maceta: false } }])

    expect(r['ejecutadas']).to eq(1), r.inspect
    expect(plantas.order(:id).pluck(:nombre, :state)).to eq([['Ananda 1', 'enraizado'], ['Ananda 2', 'enraizado']])
    expect(plantas.first.lote).to have_attributes(origen: 'semilla', estado: 'enraizado', sala_id: carpa.id)
  end

  it 'un esqueje de 10 días en un vaso: ya en maceta (0,335 L), en vegetativo desde hace 10 días' do
    r = ejecutar([{ tipo: 'nueva_planta', sala_nombre: 'Carpa chica',
                    datos: { genetica_nombre: 'Gorilla Glue', cantidad: 1, origen: 'esqueje', en_maceta: true,
                             maceta_litros: 0.335, dias: 10 } }])

    expect(r['ejecutadas']).to eq(1), r.inspect
    lote = plantas.first.lote
    expect(lote).to have_attributes(origen: 'esqueje', estado: 'vegetativo', start_date: 10.days.ago.to_date)
    expect(lote.tamanio_maceta.to_f).to eq(0.335)
    expect(plantas.first.nombre).to eq('Gorilla Glue 1')
  end

  it 'con un solo espacio, no hace falta nombrarlo' do
    r = ejecutar([{ tipo: 'nueva_planta', datos: { genetica_nombre: 'ananda', cantidad: 1 } }])
    expect(r['ejecutadas']).to eq(1), r.inspect
    expect(plantas.first.lote.sala).to eq(carpa)
  end

  it 'un espacio nombrado que no existe no se cae al único: se avisa' do
    r = ejecutar([{ tipo: 'nueva_planta', sala_nombre: 'Balcón', datos: { genetica_nombre: 'Ananda' } }])
    expect(r['ejecutadas']).to eq(0)
    expect(r['errores_detalle'].first['error']).to include('espacio')
    expect(plantas).to be_empty
  end

  it 'una genética que no está cargada no se inventa: se avisa' do
    r = ejecutar([{ tipo: 'nueva_planta', sala_nombre: 'Carpa chica', datos: { genetica_nombre: 'Kosher Kush' } }])
    expect(r['ejecutadas']).to eq(0)
    expect(r['errores_detalle'].first['error']).to include('Kosher Kush')
    expect(plantas).to be_empty
  end

  it 'el prompt de autocultivo explica el vaso y la genética llega en el mapa' do
    enviado = nil
    http = double('http', 'use_ssl=': true, 'read_timeout=': 30)
    allow(http).to receive(:request) { |req| enviado = JSON.parse(req.body); double(code: '200', body: { content: [{ text: '{"resumen":"ok","acciones":[]}' }], usage: {} }.to_json) }
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('clave-de-prueba')

    post '/api/asistente/parsear', params: { texto: 'puse una semilla de Ananda en un vaso' }, as: :json
    expect(response).to have_http_status(:ok), response.body
    sistema = enviado['system'].map { |b| b['text'] }.join
    expect(sistema).to include('nueva_planta', '0.335', 'GENÉTICAS: Ananda, Gorilla Glue')
  end

  context 'en una organización' do
    let(:org)   { create(:club, plan: 'total', features: { 'cultivo' => true, 'ia' => true }) }
    let(:jefe)  { create(:user, :admin, club: org) }

    it 'el dictado no crea lotes' do
      ActsAsTenant.with_tenant(org) do
        s = create(:sala, club: org, nombre: 'Vege 1', kind: 'vegetativo', created_by: jefe)
        create(:genetica, club: org, nombre: 'Ananda')
        sign_in_as(jefe)
        post '/api/asistente/ejecutar', params: { acciones: [{ tipo: 'nueva_planta', sala_nombre: s.nombre, datos: { genetica_nombre: 'Ananda' } }] }, as: :json
        expect(response.parsed_body['ejecutadas']).to eq(0)
        expect(Lote.where(club_id: org.id)).to be_empty
      end
    end
  end
end
