require 'rails_helper'

# AC (Germán, 7-oct-2026): «la parte de estado mucho más simple e intuitiva… tiene que poder ser
# usado por alguien que no tiene idea de programación, ver dónde hay lentitud, para detectarla».
# Cuatro preguntas en castellano con semáforo, y lo más lento de hoy: qué, dónde y cuánto.
RSpec.describe 'Estado: las cuatro preguntas y la lentitud', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club) { create(:club, name: 'Organización Lenta') }

  before do
    Rails.cache.clear
    sign_in_as(create(:user, role: 'super_admin', club: nil))
  end

  def estado!
    get '/super_admin/estado', headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    json
  end

  it 'contesta las cuatro preguntas, cada una con semáforo y una frase' do
    preguntas = estado!['preguntas']
    expect(preguntas.map { |p| p['clave'] }).to eq(%w[entra rapida copias avisos])
    expect(preguntas).to all(include('titulo', 'estado', 'etiqueta', 'frase'))
    expect(preguntas.map { |p| p['titulo'] }).to all(start_with('¿'))
  end

  it 'sin pedidos lentos, la pregunta de la velocidad está en verde' do
    10.times { Metricas::Respuesta.registrar(endpoint: 'LotesController#show', ms: 120, club_id: club.id) }
    rapida = estado!['preguntas'].find { |p| p['clave'] == 'rapida' }
    expect(rapida['estado']).to eq('ok')
  end

  it 'una pantalla lenta se nombra en castellano, con la organización y el tiempo' do
    10.times { Metricas::Respuesta.registrar(endpoint: 'DispensacionesController#index', ms: 2_400, club_id: club.id) }
    10.times { Metricas::Respuesta.registrar(endpoint: 'LotesController#show', ms: 120, club_id: club.id) }

    e = estado!
    peor = e['lentitud']['lentas'].first
    expect(peor).to include('que' => 'Lista de dispensas', 'donde' => 'Organización Lenta', 'veces' => 10)
    expect(peor['ms']).to be >= 1_500

    rapida = e['preguntas'].find { |p| p['clave'] == 'rapida' }
    expect(rapida['estado']).to eq('atencion')
    expect(rapida['frase']).to include('Lista de dispensas', 'Organización Lenta')
    expect(rapida['hacer']).to be_present
    # Y el semáforo general no dice «todo funciona» con algo lento.
    expect(e['estado']).not_to eq('ok')
  end

  it 'un pedido lento suelto no alcanza para alarmar' do
    Metricas::Respuesta.registrar(endpoint: 'InformesController#show', ms: 9_000, club_id: club.id)
    expect(estado!['lentitud']['lentas']).to be_empty
  end

  it 'la línea de 24 horas trae una barra por hora' do
    expect(estado!['lentitud']['por_hora'].size).to eq(24)
  end
end

RSpec.describe Metricas::Respuesta do
  it 'suma los pedidos de la misma hora en una sola fila' do
    3.times { described_class.registrar(endpoint: 'A#b', ms: 300, club_id: 1) }
    filas = ActiveRecord::Base.connection.select_all('SELECT cantidad, b2 FROM metricas_respuesta').to_a
    expect(filas).to eq([{ 'cantidad' => 3, 'b2' => 3 }])
  end

  it 'el monitor externo no se mide' do
    described_class.registrar(endpoint: 'Rails::HealthController#show', ms: 5)
    expect(ActiveRecord::Base.connection.select_value('SELECT COUNT(*) FROM metricas_respuesta')).to eq(0)
  end
end
