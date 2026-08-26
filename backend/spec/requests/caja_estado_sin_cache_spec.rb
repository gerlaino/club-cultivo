require 'rails_helper'

# AC (Germán): "figura como caja sin abrir pero sí la abrí".
#
# El tablero se cachea 10 minutos, y eso está bien para lo que trae: conteos del día que si
# llegan con unos minutos de atraso no cambian ninguna decisión.
#
# El ESTADO DE LA CAJA no. Es lo único de ese tablero que cambia por una acción de OTRA persona y
# que hay que ver en el momento: el admin abría la caja, volvía al inicio, y durante diez minutos
# seguía diciendo "sin abrir". Un dato que miente sobre el estado de la plata no puede salir de un
# caché.
RSpec.describe 'El estado de la caja en el tablero no se cachea', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:sede) { create(:sede, club: club, nombre: 'Pagola', tipo: 'mixta') }

  # En test el caché es `:null_store`: sin un MemoryStore real, este spec pasaría en verde con el
  # bug puesto, porque un caché que no guarda nada nunca puede servir un dato viejo.
  around do |ejemplo|
    anterior = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ejemplo.run
  ensure
    Rails.cache = anterior
  end

  def tablero
    get '/api/analytics/dispensador', headers: auth_headers
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  it 'pasa de "sin abrir" a "en turno" en el acto, sin esperar a que venza el caché' do
    sign_in_as(admin)

    antes = tablero['cajas_por_sede'].find { |c| c['sede_id'] == sede.id }
    expect(antes['estado']).to eq('sin_abrir')

    post "/api/sedes/#{sede.id}/caja/abrir", headers: auth_headers, params: { monto_inicial_ars: 100_000 }
    expect(response).to have_http_status(:created)

    despues = tablero['cajas_por_sede'].find { |c| c['sede_id'] == sede.id }
    expect(despues['estado']).not_to eq('sin_abrir')
    expect(despues['efectivo_esperado_ars']).to eq(100_000.0)
  end

  it 'refleja en el acto que confirmaron el fondo' do
    ana = create(:user, :dispensador, club: club)
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/caja/abrir", headers: auth_headers, params: { monto_inicial_ars: 100_000 }
    caja_id = JSON.parse(response.body)['id']

    expect(tablero['cajas_por_sede'].first['estado']).to eq('sin_confirmar')

    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/caja/#{caja_id}/confirmar_apertura", headers: auth_headers

    sign_in_as(admin)
    expect(tablero['cajas_por_sede'].first['estado']).to eq('abierta')
  end

  # Lo que sí se cachea tiene que seguir cacheándose: si el fix hubiera sido "sacar el caché", el
  # tablero del admin pasaría a recalcular todo en cada visita.
  it 'el resto del tablero sigue saliendo del caché', :aggregate_failures do
    sign_in_as(admin)
    tablero

    expect(Rails.cache.exist?("analytics/dispensador/#{club.id}/#{admin.id}/club/#{Time.zone.today}")).to be(true)
  end
end
