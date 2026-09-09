require 'rails_helper'

# CERRAR UN STOCK: QUÉ PASÓ Y CUÁNDO.
#
# Germán: «al finalizar stock tendríamos que poder poner la fecha, porque puede pasar que por ahí
# lo cerré hace 4 días y recién hoy que me siento con la compu lo registro».
#
# El movimiento se fechaba con `created_at` —el momento de la carga—, así que el informe de
# Pérdidas mostraba la merma en la semana equivocada. Es el mismo motivo por el que una
# dispensación tiene `fecha_dispensacion` aparte.
RSpec.describe 'Cerrar un stock', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede), estado: 'curado') } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 300, estado: 'asignado', disponibilidad: 'ambas',
                     fecha_elaboracion: Date.current - 30)
    end
  end

  before { sign_in_as(admin) }

  def cerrar(motivo: 'entregado', fecha: nil, detalle: nil)
    post "/api/stocks/#{stock.id}/descartar",
         params: { motivo: motivo, fecha: fecha, detalle: detalle }.compact, as: :json
  end

  def movimiento = stock.stock_movimientos.order(:id).last

  it 'sin fecha se cierra hoy, como siempre' do
    cerrar

    expect(response).to have_http_status(:ok)
    expect(movimiento.fecha).to eq(Time.zone.today)
    expect(movimiento.tipo).to eq('salida')   # entregado NO es merma
  end

  it 'con una fecha de hace cuatro días, queda fechado ahí' do
    cerrar(fecha: (Date.current - 4).to_s)

    expect(response).to have_http_status(:ok)
    expect(movimiento.fecha).to eq(Date.current - 4)
    # Y lo que se cargó sigue siendo hoy: son dos datos distintos y los dos hacen falta.
    expect(movimiento.created_at.to_date).to eq(Time.zone.today)
  end

  it 'no acepta una fecha futura' do
    cerrar(fecha: (Date.current + 1).to_s)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/futura/i)
    expect(stock.reload.cantidad.to_f).to eq(300.0)
  end

  # No se puede cerrar algo antes de que existiera. Contra `fecha_elaboracion` y NO contra
  # `created_at`: una carga retroactiva del producto es legítima.
  it 'ni una anterior a cuando se produjo' do
    cerrar(fecha: (Date.current - 60).to_s)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/no se puede cerrar antes/i)
  end

  # Lo que decidió Germán: no hay un botón «finalizar lote» aparte. Se cierra el stock diciendo
  # qué pasó, y el lote se cierra solo — un solo camino a `finalizado`.
  describe 'el lote' do
    it 'se finaliza solo al cerrarse el último stock' do
      cerrar(motivo: 'entregado', detalle: 'Lo retiró la ONG')

      expect(lote.reload.estado).to eq('finalizado')
      evento = lote.lote_eventos.order(:id).last
      expect(evento.estado_nuevo).to eq('finalizado')
    end

    it 'y con la fecha en que se cerró de verdad, no la de la carga' do
      cerrar(fecha: (Date.current - 4).to_s)

      evento = lote.reload.lote_eventos.order(:id).last
      expect(evento.registrado_en.to_date).to eq(Date.current - 4)
    end
  end

  # El informe de Pérdidas corta por período: si contara por la fecha de CARGA, lo que se perdió
  # el jueves aparecería en la semana en que alguien lo anotó.
  it 'la merma cae en la semana en que pasó, no en la que se cargó' do
    cerrar(motivo: 'destruido', fecha: (Date.current - 4).to_s)

    hace_una_semana = StockMovimiento.en_periodo(Date.current - 7, Date.current - 3)
    esta_semana     = StockMovimiento.en_periodo(Date.current - 2, Date.current)
    expect(hace_una_semana).to include(movimiento)
    expect(esta_semana).not_to include(movimiento)
    expect(movimiento.tipo).to eq('merma')   # destruido SÍ es pérdida
  end
end

# DÓNDE PUEDE VIVIR UN STOCK: depende de para qué es.
#
# Germán, después de no encontrar un preroll en el mostrador: «al crear un stock y elijo la sede,
# me permite elegir una sede de producción, ¿está bien eso?». No: el mostrador vive en una sede
# social o mixta, así que lo que se carga para dispensar en una sede de producción no lo ve nadie.
RSpec.describe 'La sede de un stock', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:produccion) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let!(:social)     { create(:sede, club: club, created_by: admin, tipo: 'social') }
  let(:genetica)    { ActsAsTenant.with_tenant(club) { create(:genetica, club: club) } }

  before { sign_in_as(admin) }

  def crear(sede:, disponibilidad:)
    post '/api/stocks', params: {
      stock: { origen: 'compra_externa', forma_producto: 'preroll', unidad: 'un', cantidad: 40,
               estado: 'asignado', proveedor: 'Proveedor SA', sede_id: sede.id,
               disponibilidad: disponibilidad, genetica_id: genetica.id }
    }, as: :json
  end

  it 'lo que se dispensa va a una sede que atienda' do
    crear(sede: social, disponibilidad: 'dispensa')
    expect(response).to have_http_status(:created)
  end

  it 'y no a una de producción, que no tiene mostrador' do
    crear(sede: produccion, disponibilidad: 'dispensa')

    expect(response).to have_http_status(:unprocessable_entity)
    body = JSON.parse(response.body)['errors'].join
    expect(body).to include(produccion.nombre)
    expect(body).to match(/social o mixta/i)
    expect(ActsAsTenant.with_tenant(club) { club.stocks.count }).to eq(0)
  end

  it 'la materia prima va a donde se produce' do
    crear(sede: produccion, disponibilidad: 'produccion')
    expect(response).to have_http_status(:created)
  end

  it 'y no a una que sólo atiende' do
    crear(sede: social, disponibilidad: 'produccion')
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # 'ninguna' es cuarentena/apartado: todavía no se decidió qué va a ser.
  it 'lo apartado puede estar en cualquier lado' do
    crear(sede: produccion, disponibilidad: 'ninguna')
    expect(response).to have_http_status(:created)
  end

  # LA FLOR DE UN LOTE NACE EN LA SEDE DONDE SE CULTIVA y sirve para las dos cosas: exigirle una
  # sede que atienda haría inguardable el alta más común que hay. Se reparte después.
  it "y 'ambas' tampoco se acota: es el caso de la flor recién cosechada" do
    crear(sede: produccion, disponibilidad: 'ambas')
    expect(response).to have_http_status(:created)
  end

  # Verificar que el candado esté puesto en una puerta no es verificar que lo tengan todas.
  it 'repartir tampoco lo manda a donde no sirve' do
    crear(sede: social, disponibilidad: 'dispensa')
    stock_id = JSON.parse(response.body)['id']

    post "/api/stocks/#{stock_id}/asignar", params: { sede_id: produccion.id, cantidad: 10 }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/social o mixta/i)
  end
end
