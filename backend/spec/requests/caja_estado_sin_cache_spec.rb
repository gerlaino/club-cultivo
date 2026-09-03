require 'rails_helper'

# AC (Germán): "figura como caja sin abrir pero sí la abrí".
#
# El tablero se cachea 10 minutos, y eso está bien para lo que trae: conteos del día que si
# llegan con unos minutos de atraso no cambian ninguna decisión.
#
# El ESTADO DEL MOSTRADOR no. Es lo único de ese tablero que cambia por una acción de OTRA persona
# y que hay que ver en el momento: se abría la caja, se volvía al inicio, y durante diez minutos
# seguía diciendo "sin abrir". Un dato que miente sobre el estado de la plata no puede salir de un
# caché.
RSpec.describe 'El estado de la caja en el tablero no se cachea', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
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

  def de_la_sede = tablero['cajas_por_sede'].find { |c| c['sede_id'] == sede.id }

  it 'pasa de "sin abrir" a "en turno" en el acto, sin esperar a que venza el caché' do
    sign_in_as(admin)

    expect(de_la_sede['estado']).to eq('sin_abrir')

    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { efectivo_contado_ars: 100_000 }
    expect(response).to have_http_status(:created)

    despues = de_la_sede
    expect(despues['estado']).not_to eq('sin_abrir')
    expect(despues['efectivo_esperado_ars']).to eq(100_000.0)
  end

  # `cargado` es un estado propio y no un detalle: la mesa está lista y falta que alguien abra la
  # caja. Es justo donde se traba un arranque —el admin la dejó preparada y el que atiende todavía
  # no llegó— y es lo que el admin necesita ver de un vistazo, no dentro de diez minutos.
  it 'muestra en el acto que la mesa quedó cargada, y después que abrieron' do
    sign_in_as(admin)
    expect(de_la_sede['mostrador']['estado']).to eq('sin_abrir')

    ActsAsTenant.with_tenant(club) do
      lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
      stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                             cantidad: 500, precio_sugerido_ars: 100)
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                               cambios: [{ stock_id: stock.id, cantidad: 100 }],
                               motivo: 'carga de la mañana')
    end

    cargado = de_la_sede
    expect(cargado['mostrador']['estado']).to eq('cargado')
    expect(cargado['mostrador']['productos']).to eq(1)
    expect(cargado['estado']).to eq('sin_abrir') # la mesa está lista, la caja todavía no

    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { efectivo_contado_ars: 100_000, conteos: [] }
    expect(response).to have_http_status(:created)

    sign_in_as(admin)
    abierto = de_la_sede
    expect(abierto['mostrador']['estado']).to eq('abierto')
    expect(abierto['mostrador']['atiende']).to eq(ana.nombre_completo)
    # `sin_confirmar` es del buffet, donde alguien declara el fondo y otro lo confirma. Acá la
    # caja se abre contando, en un solo gesto: preguntarle si "confirmaron la apertura" la dejaba
    # sin_confirmar para siempre, esperando un paso que ya no le toca a nadie.
    expect(abierto['estado']).to eq('abierta')
  end

  # Lo que sí se cachea tiene que seguir cacheándose: si el fix hubiera sido "sacar el caché", el
  # tablero del admin pasaría a recalcular todo en cada visita.
  it 'el resto del tablero sigue saliendo del caché', :aggregate_failures do
    sign_in_as(admin)
    tablero

    expect(Rails.cache.exist?("analytics/dispensador/#{club.id}/#{admin.id}/club/#{Time.zone.today}")).to be(true)
  end
end
