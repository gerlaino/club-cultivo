require 'rails_helper'

# AC (Germán, 12-oct-2026): «al detectar una acción repetida, deberíamos preguntar si se quieren
# hacer dos registros de la misma, quizás fue un error». El dictado devolvió dos veces «un pulso
# por planta» y el riego ya estaba registrado ese día. El backend marca cada tarjeta (no la
# quita: dos riegos en un día pueden ser a propósito) y la pantalla pregunta antes de guardar.
RSpec.describe 'Asistente: acciones repetidas', type: :request do
  let(:club)  { create(:club, plan: 'total', features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club, first_name: 'Germán', last_name: 'L') }
  let(:carpa) { create(:sala, club: club, nombre: 'Carpa', kind: 'mixta', created_by: admin) }
  let!(:lote) { create(:lote, club: club, sala: carpa, codigo: 'L-26-001', estado: 'vegetativo') }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  RIEGO = { 'tipo' => 'registro_ambiental', 'lote_codigo' => 'L-26-001',
            'datos' => { 'tareas_realizadas' => ['riego'], 'observaciones' => 'Un pulso por planta' } }.freeze

  def parsear_con(acciones)
    http = double('http', 'use_ssl=': true, 'read_timeout=': 30)
    cuerpo = { content: [{ text: { resumen: 'Riego', acciones: acciones }.to_json }], usage: {} }.to_json
    allow(http).to receive(:request).and_return(double(code: '200', body: cuerpo))
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('clave-de-prueba')

    post '/api/asistente/parsear', params: { texto: 'regué con un pulso por planta' }, as: :json
    expect(response).to have_http_status(:ok), response.body
    response.parsed_body['acciones']
  end

  it 'la misma acción dos veces en el mismo dictado: la segunda queda marcada' do
    a = parsear_con([RIEGO, RIEGO])

    expect(a[0]['repetida']).to be_nil
    expect(a[1]['repetida']).to eq('Está dos veces en lo que dictaste.')
  end

  it 'si hoy ya se registró un riego en ese lote, lo dice con la hora y quién' do
    create(:registro_ambiental, lote: lote, user: admin, tareas_realizadas: ['riego'], registrado_en: Time.zone.now.change(hour: 10, min: 32))

    a = parsear_con([RIEGO])

    expect(a[0]['ya_registrado']).to eq('Hoy ya se registró un riego en el lote L-26-001 a las 10:32 (Germán L).')
  end

  it 'lo de ayer no cuenta, ni otra cosa distinta de hoy' do
    create(:registro_ambiental, lote: lote, user: admin, tareas_realizadas: ['riego'], registrado_en: 1.day.ago)
    create(:registro_ambiental, lote: lote, user: admin, tareas_realizadas: ['poda'], registrado_en: Time.zone.now)

    a = parsear_con([RIEGO])

    expect(a[0]['ya_registrado']).to be_nil
  end

  it 'dos acciones distintas no son repetidas' do
    otra = RIEGO.merge('datos' => { 'tareas_realizadas' => ['riego'], 'observaciones' => 'Dos pulsos' })

    a = parsear_con([RIEGO, otra])

    expect(a.map { |x| x['repetida'] }).to eq([nil, nil])
  end
end
