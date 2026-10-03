require 'rails_helper'

# AC (Germán, 2-oct-2026): un panel donde se vean los servicios y los servidores, «super profesional
# pero simple a la vista, que quien sea entienda lo que ve». Lo de Render se traduce: qué es cada
# cosa, si anda, cuánto usa, cuánto cuesta. Y cuál es producción no se adivina por el nombre (el de
# producción se llama `cultivo-staging-api`).
RSpec.describe Infra::Servidores do
  # Lo que contestaría la API de Render. Una clase de verdad, no un mock de instancias.
  class RenderFalso
    attr_reader :servicios, :postgres, :key_value

    def initialize(servicios: [], postgres: [], key_value: [], deploys: {}, memoria: [], cpu: [])
      @servicios, @postgres, @key_value, @deploys, @memoria, @cpu = servicios, postgres, key_value, deploys, memoria, cpu
    end

    def ultimo_deploy(id) = @deploys[id]
    def metrica(m, _id) = (m == 'memory' ? @memoria : @cpu)
  end

  def web(id, nombre, plan: 'starter', suspendido: false)
    { 'id' => id, 'name' => nombre, 'type' => 'web_service', 'suspended' => suspendido ? 'suspended' : 'not_suspended',
      'serviceDetails' => { 'plan' => plan }, 'dashboardUrl' => "https://dashboard.render.com/#{id}" }
  end

  around do |ej|
    viejos = ENV.to_h.slice('RENDER_SERVICE_ID', 'DATABASE_URL', 'REDIS_URL')
    ENV['RENDER_SERVICE_ID'] = 'srv-prod'
    ENV['DATABASE_URL'] = 'postgres://u:p@dpg-prod-a.oregon-postgres.render.com/app'
    ENV['REDIS_URL'] = 'redis://red-prod:6379'
    ej.run
  ensure
    %w[RENDER_SERVICE_ID DATABASE_URL REDIS_URL].each { |k| viejos.key?(k) ? ENV[k] = viejos[k] : ENV.delete(k) }
  end

  def llamar(api) = described_class.new(api).call
  def tarjeta(r, nombre) = r[:servidores].find { |s| s[:nombre] == nombre }

  it 'reconoce producción por el id que Render le pasa al servidor, no por el nombre' do
    api = RenderFalso.new(servicios: [web('srv-prod', 'cultivo-staging-api'), web('srv-otro', 'club-cultivo-staging')],
                          deploys: { 'srv-prod' => { 'status' => 'live' }, 'srv-otro' => { 'status' => 'live' } })
    r = llamar(api)
    expect(tarjeta(r, 'cultivo-staging-api')).to include(en_produccion: true, titulo: 'La app', estado: 'ok')
    expect(tarjeta(r, 'club-cultivo-staging')).to include(en_produccion: false)
    expect(r[:sobran]).to eq(['club-cultivo-staging'])
  end

  it 'la base y el Redis de producción son los de DATABASE_URL y REDIS_URL' do
    api = RenderFalso.new(
      postgres:  [{ 'id' => 'dpg-prod', 'name' => 'club-cultivo-staging-db', 'plan' => 'basic_256mb', 'status' => 'available' },
                  { 'id' => 'dpg-pre', 'name' => 'cultivo-pre-db', 'plan' => 'basic_256mb', 'status' => 'available' }],
      key_value: [{ 'id' => 'red-prod', 'name' => 'redis', 'plan' => 'starter', 'status' => 'available' }]
    )
    r = llamar(api)
    expect(tarjeta(r, 'club-cultivo-staging-db')).to include(en_produccion: true, titulo: 'Base de datos', precio_usd: 6)
    expect(tarjeta(r, 'cultivo-pre-db')).to include(en_produccion: false)
    expect(tarjeta(r, 'redis')).to include(en_produccion: true, precio_usd: 10)
  end

  it 'si el id no coincide, la reconoce por el nombre de la base y el usuario (2-oct-2026)' do
    ENV['DATABASE_URL'] = 'postgresql://cultivo_user:x@otro-host-a/cultivo_db'
    api = RenderFalso.new(postgres: [
      { 'id' => 'dpg-zzz', 'name' => 'club-cultivo-staging-db', 'databaseName' => 'cultivo_db', 'databaseUser' => 'cultivo_user', 'status' => 'available' },
      { 'id' => 'dpg-pre', 'name' => 'cultivo-pre-db', 'databaseName' => 'cultivo_pre', 'databaseUser' => 'cultivo_pre', 'status' => 'available' },
    ])
    r = llamar(api)
    expect(tarjeta(r, 'club-cultivo-staging-db')[:en_produccion]).to be(true)
    expect(tarjeta(r, 'cultivo-pre-db')[:en_produccion]).to be(false)
  end

  it 'un deploy que falló es «para mirar» y lo dice en castellano' do
    api = RenderFalso.new(servicios: [web('srv-prod', 'cultivo-staging-api')], deploys: { 'srv-prod' => { 'status' => 'build_failed' } })
    t = tarjeta(llamar(api), 'cultivo-staging-api')
    expect(t[:estado]).to eq('atencion')
    expect(t[:estado_texto]).to include('no se pudo instalar')
  end

  it 'un servicio suspendido está apagado y no suma al costo' do
    api = RenderFalso.new(servicios: [web('srv-prod', 'cultivo-staging-api', plan: 'standard'), web('srv-x', 'club-cultivo-stg', suspendido: true)],
                          deploys: { 'srv-prod' => { 'status' => 'live' } })
    r = llamar(api)
    expect(tarjeta(r, 'club-cultivo-stg')).to include(estado: 'apagado', precio_usd: 0)
    expect(r[:costo_usd_mes]).to eq(25)
  end

  it 'la memoria se mide contra lo que da el plan, y casi llena es «para mirar»' do
    mb = ->(n) { n * 1024 * 1024 }
    api = RenderFalso.new(servicios: [web('srv-prod', 'cultivo-staging-api', plan: 'starter')],
                          deploys: { 'srv-prod' => { 'status' => 'live' } },
                          memoria: [{ t: '1', v: mb.call(300) }, { t: '2', v: mb.call(470) }], cpu: [{ t: '1', v: 0.1 }])
    t = tarjeta(llamar(api), 'cultivo-staging-api')
    expect(t[:recursos][:memoria]).to include(actual: 470, pico: 470, limite: 512, pct: 92)
    expect(t[:estado]).to eq('atencion')
  end

  it 'sin la llave de Render no rompe: dice qué falta' do
    ENV.delete('RENDER_API_KEY')
    expect(described_class.call).to include(configurado: false)
  end
end
