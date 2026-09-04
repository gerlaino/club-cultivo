require 'rails_helper'

# Lo que el carrito de dispensa le OFRECE a quien atiende.
#
# La regla más importante del proyecto sobre esto: si la pantalla ofrece algo que el backend
# rechaza, parece culpa del usuario. Como la dispensa ahora exige que el producto esté sobre la
# mesa, el carrito tiene que ofrecer exactamente eso — ni más (el depósito) ni con otro número
# (el libre del depósito en vez de lo que queda arriba).
RSpec.describe 'El carrito ofrece lo que está sobre la mesa', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end
  let!(:preroll) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll', unidad: 'un',
                     cantidad: 80, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 500)
    end
  end

  # El admin sube SÓLO la flor a la mesa y Ana abre la caja contando: los dos pasos reales, de
  # las dos personas.
  def abrir_mostrador_con_flor!
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'apertura',
                               cambios: [{ stock_id: flor.id, cantidad: 300 }])
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana, efectivo_contado_ars: 0)
    end
  end

  def carrito(como)
    sign_in_as(como)
    get '/api/stocks', headers: auth_headers, params: { para_dispensa: true }
    JSON.parse(response.body)
  end

  it 'con el mostrador cerrado, no le ofrece nada' do
    expect(carrito(ana)).to eq([])
  end

  it 'ofrece sólo lo que se subió a la mesa' do
    abrir_mostrador_con_flor!

    ids = carrito(ana).map { |s| s['id'] }
    expect(ids).to eq([flor.id])
    expect(ids).not_to include(preroll.id)
  end

  # Ofrecerle 200 g del depósito cuando sobre la mesa hay 300 es prometerle algo que no puede
  # entregar — y al revés, esconderle lo que sí tiene.
  # Se piden LOS DOS campos: el carrito muestra y valida contra `cantidad` —el frasco entero—,
  # así que pisar sólo `cantidad_disponible_real` le mostraba "1.000 g" con 300 sobre la mesa y
  # lo dejaba cargar 500 para que el backend se lo rechazara al confirmar, con el paciente
  # enfrente. La regla estaba escrita acá y leída en otro campo allá.
  it 'el disponible que muestra es el de la mesa, no el del depósito' do
    abrir_mostrador_con_flor!

    fila = carrito(ana).first
    expect(fila['cantidad_disponible_real']).to eq(300.0)
    expect(fila['cantidad']).to eq(300.0)
  end

  it 'baja a medida que se dispensa' do
    abrir_mostrador_con_flor!
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: create(:paciente, club: club), user: ana, stock: flor,
                           sede: sede, cantidad: 45, medio_pago: 'efectivo',
                           aporte_socio_ars: 4_500, fecha_dispensacion: Time.zone.today)
    end

    expect(carrito(ana).first['cantidad_disponible_real']).to eq(255.0)
    expect(carrito(ana).first['cantidad']).to eq(255.0)
  end

  # Al admin NO se le pisa: dispensa del depósito entero, y mostrarle lo de la mesa le escondería
  # lo que sí puede entregar.
  it 'al admin le muestra el frasco entero, no lo que hay sobre la mesa' do
    abrir_mostrador_con_flor!

    fila = carrito(admin).find { |s| s['id'] == flor.id }
    expect(fila['cantidad']).to eq(500.0)
  end

  # El admin no atiende el mostrador: es el que lo carga y lo arquea, y ve todo el depósito.
  it 'al admin le sigue ofreciendo el depósito entero' do
    ids = carrito(admin).map { |s| s['id'] }

    expect(ids).to include(flor.id, preroll.id)
  end

  # Al admin se le ofrece TODO, pero si dispensa lo que está arriba, va a descontar de la mesa
  # igual que si lo hiciera el que atiende. El badge existe para que lo sepa ANTES de elegir, no
  # para que se entere a la noche cuando el que atiende cierra con un faltante que no esperaba.
  it 'le marca cuál de eso está sobre alguna mesa' do
    abrir_mostrador_con_flor!

    por_id = carrito(admin).index_by { |s| s['id'] }

    expect(por_id[flor.id]['en_mostrador']).to be(true)
    expect(por_id[preroll.id]['en_mostrador']).to be(false)
  end

  # `serialize_stock` no distingue quién pregunta: el campo viaja igual para los dos. Para el
  # que atiende sale siempre `true` —ya ve sólo lo que está sobre la mesa, así que no podría ser
  # otra cosa— y el frontend no dibuja el badge para su rol: repetirle con un chip lo que ya sabe
  # por estar filtrado no agrega nada.
  it 'al que atiende le sale siempre true: ya ve sólo lo que está sobre la mesa' do
    abrir_mostrador_con_flor!

    fila = carrito(ana).first
    expect(fila['en_mostrador']).to be(true)
  end
end
