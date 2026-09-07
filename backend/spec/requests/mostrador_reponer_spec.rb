require 'rails_helper'

# QUIEN ATIENDE PIDE, ADMINISTRACIÓN REPONE.
#
# Él no ve el depósito —cuánto hay guardado no es asunto suyo— pero sí necesita decir "se me está
# acabando esto". Antes la única forma era mirarlo en su pantalla de Stock y avisar por fuera de
# la app; ahora es un botón, y el pedido llega a la campana y al celular de quien puede hacer algo.
RSpec.describe 'Pedir reposición al mostrador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sup)   { create(:user, :supervisor, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 200, precio_sugerido_ars: 1_000)
    end
  end

  # La mesa cargada con una parte: queda producto en el depósito para reponer.
  before do
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: flor.id, cantidad: 100 }])
    end
  end

  def pedir(como: ana, stock_id: flor.id)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/reponer", headers: auth_headers, params: { stock_id: stock_id }
    JSON.parse(response.body)
  end

  def alertas = AlertaInterna.unscoped.where(club_id: club.id, tipo: 'reposicion_mostrador')

  it 'deja el pedido con quién, qué y dónde' do
    expect { pedir }.to change { alertas.count }.by(1)

    a = alertas.last
    expect(a.mensaje).to include(ana.nombre_completo)
    expect(a.mensaje).to include('Centro')
    expect(a.contexto['stock_id']).to eq(flor.id)
  end

  # El admin ve TODAS las alertas de su organización y el supervisor sólo las suyas: marcada para
  # supervisor le llega a los dos con una sola fila. Dos filas le mostrarían lo mismo dos veces al
  # admin.
  it 'le llega a administración: admin y supervisor' do
    pedir

    sign_in_as(sup)
    get '/api/alertas_internas', headers: auth_headers
    expect(response.body).to include('pide reponer')

    sign_in_as(admin)
    get '/api/alertas_internas', headers: auth_headers
    expect(response.body).to include('pide reponer')
  end

  # Un botón que se puede apretar diez veces llena la campana de avisos iguales, y eso es cómo se
  # aprende a ignorarla.
  it 'uno por producto y por día' do
    pedir
    cuerpo = nil
    expect { cuerpo = pedir }.not_to change { alertas.count }
    expect(cuerpo['ya_pedido']).to be(true)
  end

  it 'y el producto queda marcado como pedido en la mesa' do
    pedir

    sign_in_as(ana)
    get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
    fila = JSON.parse(response.body)['mesa'].first
    expect(fila['reposicion_pedida']).to be(true)
  end

  describe 'lo que ve quien atiende' do
    # Cuánto hay guardado no es asunto suyo. Lo único que necesita es si queda algo que traer:
    # pedir lo que no hay les hace perder el viaje a los dos.
    it 'NO recibe cuánto hay en el depósito, pero sí si queda algo' do
      sign_in_as(ana)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers

      fila = JSON.parse(response.body)['mesa'].first
      expect(fila['disponible']).to be_nil
      expect(fila['hay_en_deposito']).to be(true)
    end

    it 'y administración sí lo ve: ella decide qué baja' do
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers

      fila = JSON.parse(response.body)['mesa'].first
      expect(fila['disponible']).to eq(900.0)
    end

    # Su pantalla de Stock mostraba el depósito entero: el filtro a la mesa aplicaba sólo al
    # carrito. Va en el backend porque por la API se saltea siempre.
    it 'su listado de stock muestra la MESA, no el depósito' do
      sign_in_as(ana)
      get '/api/stocks', headers: auth_headers

      fila = JSON.parse(response.body).find { |s| s['id'] == flor.id }
      expect(fila['cantidad']).to eq(100.0)          # lo que hay sobre la mesa
      expect(fila['cantidad_disponible_real']).to eq(100.0)
    end
  end

  it 'no se puede pedir a un producto que no existe' do
    pedir(stock_id: 999_999)

    expect(response).to have_http_status(:not_found)
  end
end
