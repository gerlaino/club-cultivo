require 'rails_helper'

# LO QUE CADA UNO NECESITA VER DEL MOSTRADOR.
#
#   · el que atiende → sus propios turnos cerrados: si mañana le preguntan por una diferencia,
#     tiene con qué. Los de los demás no son asunto suyo.
#   · administración → todos, más cuánto vale lo que hay sobre la mesa y qué turnos piden una
#     mirada.
RSpec.describe 'Quién ve qué del mostrador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 200, precio_sugerido_ars: 1_000)
    end
  end
  let!(:preroll) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: nil, forma_producto: 'preroll', unidad: 'un',
                     origen: 'compra_externa', proveedor: 'X', cantidad: 50, estado: 'asignado',
                     disponibilidad: 'ambas', costo_unitario_ars: 800)
    end
  end

  def mostrador = sede.mostrador!

  def cargar!(flor_cant, preroll_cant, motivo: 'carga del día')
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: motivo,
                               cambios: [{ stock_id: flor.id, cantidad: flor_cant },
                                         { stock_id: preroll.id, cantidad: preroll_cant }])
    end
  end

  def abrir!(usuario: ana, conteos: nil)
    ActsAsTenant.with_tenant(club) do
      Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: usuario,
                                  conteos: conteos || [], efectivo_contado_ars: 0).turno
    end
  end

  def cerrar!(turno, flor_contado, preroll_contado, usuario: ana)
    ActsAsTenant.with_tenant(club) do
      Mostradores::CerrarCaja.call(
        turno: turno, usuario: usuario, efectivo_contado_ars: 0,
        conteos: [{ stock_id: flor.id, contado: flor_contado },
                  { stock_id: preroll.id, contado: preroll_contado }]
      )
    end
  end

  def ver(como)
    sign_in_as(como)
    get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
    JSON.parse(response.body)
  end

  # En gramos no se compara con nada; en plata se ve de un vistazo que ahí arriba hay medio
  # sueldo. Sólo para quien responde por esa mercadería.
  describe 'cuánto vale lo que está sobre la mesa' do
    before { cargar!(300, 10) && abrir! }

    it 'administración lo ve, a costo' do
      # 300 g × $200 + 10 un × $800
      expect(ver(admin)['turno']['valor_mesa_ars']).to eq(68_000.0)
    end

    it 'y quien atiende no: no responde por eso' do
      expect(ver(ana)['turno']['valor_mesa_ars']).to be_nil
    end
  end

  describe 'sus propios turnos' do
    before do
      cargar!(300, 10)
      cerrar!(abrir!, 300, 10)
    end

    def turnos(como)
      sign_in_as(como)
      get "/api/sedes/#{sede.id}/mostrador/turnos", headers: auth_headers
      JSON.parse(response.body)
    end

    # Cerraba un turno y no tenía dónde mirarlo: si al día siguiente le preguntan por una
    # diferencia, no tenía con qué.
    it 'el que atendió ve los suyos' do
      cuerpo = turnos(ana)

      expect(cuerpo['turnos'].size).to eq(1)
      expect(cuerpo['gestiona']).to be(false)
      expect(cuerpo['turnos'].first['cerrado_por']).to eq(ana.nombre_completo)
    end

    it 'y no los de otro' do
      expect(turnos(create(:user, :dispensador, club: club))['turnos']).to be_empty
    end

    it 'administración los ve todos' do
      cuerpo = turnos(admin)

      expect(cuerpo['turnos'].size).to eq(1)
      expect(cuerpo['gestiona']).to be(true)
    end
  end

  # Prometer una bandeja y contar sólo los faltantes deja las otras dos razones invisibles apenas
  # cierra el turno.
  describe 'la bandeja cuenta las TRES cosas' do
    def sin_revisar = ver(admin)['sin_revisar']

    it 'un cierre cuadrado y sin nada raro no entra' do
      cargar!(300, 10)
      cerrar!(abrir!, 300, 10)

      expect(sin_revisar).to eq(0)
    end

    it 'entra si faltó producto' do
      cargar!(300, 10)
      cerrar!(abrir!, 295, 10)

      expect(sin_revisar).to eq(1)
    end

    it 'entra si quien abrió corrigió lo que decía la mesa' do
      cargar!(300, 10)
      turno = abrir!(conteos: [{ stock_id: flor.id, contado: 297 }])
      cerrar!(turno, 297, 10)

      expect(sin_revisar).to eq(1)
    end

    # Si administración movió la mesa a media tarde, la diferencia de la noche puede no ser de
    # quien atendió: el turno pide una mirada para no cargársela a él.
    it 'y entra si administración movió la mesa durante el turno' do
      cargar!(300, 10)
      turno = abrir!
      cargar!(200, 10, motivo: 'me llevo 100 g')
      cerrar!(turno, 200, 10)

      expect(sin_revisar).to eq(1)
    end
  end

  # La mesa es un estado permanente: existe con la caja abierta y con la caja cerrada, porque el
  # producto está físicamente ahí.
  describe 'la mesa sin caja abierta' do
    before { cargar!(300, 10) }

    it 'se ve igual, y dice que la caja está cerrada' do
      cuerpo = ver(admin)

      expect(cuerpo['turno']).to be_nil
      expect(cuerpo['mesa'].size).to eq(2)
      expect(cuerpo['mesa'].map { |m| m['mostrador'] }).to match_array([300.0, 10.0])
    end

    # Quien atiende ve la mesa aunque no haya abierto: es lo que va a contar.
    it 'y quien atiende también la ve' do
      expect(ver(ana)['mesa'].size).to eq(2)
    end
  end

  # La mesa la gobierna administración. Quien atiende nunca elige qué hay.
  describe 'quién puede cargar' do
    it 'administración sí' do
      expect(ver(admin)['puedo']['cargar']).to be(true)
    end

    it 'quien atiende no' do
      expect(ver(ana)['puedo']['cargar']).to be(false)
    end
  end
end
