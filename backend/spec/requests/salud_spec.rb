require 'rails_helper'

# Las rutas van con host completo: el helper de specs le prefija /api a todo lo demás, y /salud y
# /up viven en la raíz.

# /salud es lo que consulta el monitor EXTERNO cada minuto: dice si anda todo lo que la app
# necesita para atender (base, Redis, worker de Sidekiq). /up queda para Render y no mira nada más
# que el proceso: si Render lo viera caer por Redis, reiniciaría la web sin arreglar nada.
RSpec.describe 'GET /salud', type: :request do
  def json = JSON.parse(response.body)

  let(:worker_vivo)   { [{ 'beat' => Time.now.to_i - 5 }] }
  let(:worker_muerto) { [{ 'beat' => Time.now.to_i - 600 }] }

  it 'responde 200 sin loguearse cuando base, Redis y worker andan' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return(worker_vivo)
    get 'http://www.example.com/salud'
    expect(response).to have_http_status(:ok)
    expect(json['chequeos']).to eq('base' => 'ok', 'redis' => 'ok', 'worker' => 'ok')
  end

  it 'responde 503 si no hay worker (los jobs se encolan y nadie los corre)' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
    get 'http://www.example.com/salud'
    expect(response).to have_http_status(:service_unavailable)
    expect(json['chequeos']['worker']).to eq('caído')
  end

  it 'un worker que dejó de latir hace más de un minuto cuenta como caído' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return(worker_muerto)
    get 'http://www.example.com/salud'
    expect(response).to have_http_status(:service_unavailable)
  end

  it 'responde 503 si Redis no contesta' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return(worker_vivo)
    allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)
    get 'http://www.example.com/salud'
    expect(response).to have_http_status(:service_unavailable)
    expect(json['chequeos']['redis']).to eq('caído')
  end

  it 'no dice nada de más: sólo ok/caído por pieza' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return(worker_vivo)
    get 'http://www.example.com/salud'
    expect(json.keys).to contain_exactly('ok', 'chequeos', 'time')
  end

  it '/up sigue sin mirar Redis ni el worker' do
    allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
    get 'http://www.example.com/up'
    expect(response).to have_http_status(:ok)
  end
end
