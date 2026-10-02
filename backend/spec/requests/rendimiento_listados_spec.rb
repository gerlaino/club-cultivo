require 'rails_helper'

# LAS PANTALLAS DEL DÍA NO PUEDEN TARDAR MÁS PORQUE LA ORGANIZACIÓN CRECIÓ.
#
# «Crecen las genéticas, crecen las cantidades, y vas a hacer la dispensa y tarda en cargar»
# (el socio de Germán, 1-oct-2026). La causa era la de siempre: cada fila del listado hacía sus
# propias consultas (las plantas de cada genética, su foto, la sede y la organización de cada
# frasco, sus repartos, sus eventos…). Con 100 genéticas eran ~400 consultas para una lista.
#
# Lo que se afirma acá es eso y nada más: la cantidad de consultas de cada listado NO crece con la
# cantidad de filas. Se mide con pocas filas, se agregan más y se vuelve a medir.
RSpec.describe 'Rendimiento — los listados del día no crecen con la cantidad de filas', type: :request do
  include AuthHelpers

  # Se mide con 2 filas y con 2 + MAS. Una consulta POR FILA suma MAS o más; lo que se tolera es
  # el ruido fijo: las precargas (una consulta para toda la lista) a veces las contesta la caché de
  # consultas de Rails y a veces no, según cómo quedan los ids — eso mueve el total unas pocas
  # consultas entre corridas sin que crezca con las filas.
  MAS    = 15
  MARGEN = 7

  let(:club)  { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  def consultas
    contador = 0
    cb = lambda do |*, payload|
      next if payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])
      next if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      contador += 1
    end
    ActiveSupport::Notifications.subscribed(cb, 'sql.active_record') { yield }
    expect(response).to have_http_status(:ok), response.body
    contador
  end

  def con_tenant(&) = ActsAsTenant.with_tenant(club, &)

  # Una genética con su lote en curso, sus plantas y su frasco en la sede.
  def genetica_con_frasco!
    con_tenant do
      g    = create(:genetica, club: club, tipo: 'hibrida')
      lote = create(:lote, club: club, sala: sala, genetica: g)
      create(:plant, lote: lote, club: club)
      Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                    unidad: 'g', cantidad: 100, precio_sugerido_ars: 1_000, estado: 'asignado',
                    disponibilidad: 'dispensa')
    end
  end

  def cargar_mesa!(stocks)
    con_tenant do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                               cambios: stocks.map { |s| { stock_id: s.id, cantidad: 10 } },
                               motivo: 'Carga del día')
    end
  end

  def no_crece(pocas:, muchas:)
    expect(muchas - pocas).to be <= MARGEN,
                              "con #{MAS} filas más hizo #{muchas - pocas} consultas más (#{pocas} → #{muchas}): hay una consulta por fila"
  end

  it 'GET /geneticas (el catálogo de la organización)' do
    sign_in_as(admin)
    2.times { genetica_con_frasco! }
    pocas = consultas { get '/geneticas', headers: auth_headers }
    MAS.times { genetica_con_frasco! }
    muchas = consultas { get '/geneticas', headers: auth_headers }

    expect(JSON.parse(response.body).size).to be >= 2 + MAS
    no_crece(pocas:, muchas:)
  end

  it 'GET /stocks?para_dispensa (el carrito de administración)' do
    sign_in_as(admin)
    2.times { genetica_con_frasco! }
    pocas = consultas { get '/stocks', params: { para_dispensa: 1 }, headers: auth_headers }
    MAS.times { genetica_con_frasco! }
    muchas = consultas { get '/stocks', params: { para_dispensa: 1 }, headers: auth_headers }

    expect(JSON.parse(response.body).size).to eq(2 + MAS)
    no_crece(pocas:, muchas:)
  end

  it 'GET /stocks?para_dispensa (el carrito de quien atiende: sólo la mesa)' do
    disp = create(:user, :dispensador, club: club)
    cargar_mesa!(Array.new(2) { genetica_con_frasco! })
    sign_in_as(disp)
    pocas = consultas { get '/stocks', params: { para_dispensa: 1 }, headers: auth_headers }
    cargar_mesa!(Array.new(MAS) { genetica_con_frasco! })
    muchas = consultas { get '/stocks', params: { para_dispensa: 1 }, headers: auth_headers }

    expect(JSON.parse(response.body).size).to eq(2 + MAS)
    no_crece(pocas:, muchas:)
  end

  it 'GET /sedes/:id/mostrador (la mesa)' do
    sign_in_as(admin)
    cargar_mesa!(Array.new(2) { genetica_con_frasco! })
    pocas = consultas { get "/sedes/#{sede.id}/mostrador", headers: auth_headers }
    cargar_mesa!(Array.new(MAS) { genetica_con_frasco! })
    muchas = consultas { get "/sedes/#{sede.id}/mostrador", headers: auth_headers }

    expect(JSON.parse(response.body)['mesa'].size).to eq(2 + MAS)
    no_crece(pocas:, muchas:)
  end

  it 'GET /sedes/:id/mostrador con la caja abierta (la señal de reponer mira el turno)' do
    sign_in_as(admin)
    primeros = Array.new(2) { genetica_con_frasco! }
    cargar_mesa!(primeros)
    con_tenant do
      res = Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: admin,
                                        conteos: primeros.map { |st| { stock_id: st.id, contado: 10 } },
                                        efectivo_contado_ars: 0, notas: nil)
      expect(res.ok?).to be(true), res.error.to_s
    end
    pocas = consultas { get "/sedes/#{sede.id}/mostrador", headers: auth_headers }
    cargar_mesa!(Array.new(MAS) { genetica_con_frasco! })
    muchas = consultas { get "/sedes/#{sede.id}/mostrador", headers: auth_headers }

    expect(JSON.parse(response.body)['turno']).to be_present
    no_crece(pocas:, muchas:)
  end

  it 'GET /movimientos_contables (el libro)' do
    sign_in_as(admin)
    movimiento = lambda do
      con_tenant do
        create(:movimiento_contable, club: club, created_by: admin, sede: sede,
                                     paciente: create(:paciente, club: club, created_by: admin))
      end
    end
    2.times { movimiento.call }
    pocas = consultas { get '/movimientos_contables', headers: auth_headers }
    MAS.times { movimiento.call }
    muchas = consultas { get '/movimientos_contables', headers: auth_headers }

    expect(JSON.parse(response.body)['movimientos'].size).to eq(2 + MAS)
    no_crece(pocas:, muchas:)
  end
end
