require 'rails_helper'

# QUIÉN VE QUÉ AL DISPENSAR.
#
# El **dispensador** ve exactamente la mesa: los productos que están arriba y con el número de
# arriba. El **admin y el supervisor** son administración y ven todo el stock habilitado de la
# sede, con o sin mostrador abierto.
#
# El supervisor estaba del otro lado, y eso lo dejaba siendo administración para ver la merma y
# para llevarse la recaudación, pero "el que atiende" para dispensar — la misma persona en dos
# lados según qué pantalla mirara.
#
# La regla gobierna DOS cosas a la vez —el catálogo que ofrece el carrito y la validación de
# `Dispensacion`— y por eso vive en un solo lugar (`User#atiende_mostrador?`). Separadas, la
# pantalla ofrecería algo que el backend rechaza: el peor error posible, porque parece culpa del
# usuario.
RSpec.describe 'Quién ve qué stock al dispensar', type: :request do
  include AuthHelpers

  let(:club)       { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:supervisor) { create(:user, :supervisor, club: club) }
  let(:ana)        { create(:user, :dispensador, club: club) }
  let(:sede)       { create(:sede, club: club, tipo: 'social') }
  let(:sala)       { create(:sala, club: club, sede: sede) }
  let(:lote)       { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala) } }
  let(:paciente)   { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  def stock!(cantidad)
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: cantidad, estado: 'asignado', disponibilidad: 'ambas',
                     precio_sugerido_ars: 100, costo_unitario_ars: 20)
    end
  end

  let!(:en_la_mesa)  { stock!(500) }
  let!(:en_deposito) { stock!(300) }

  # La mesa lleva SÓLO uno de los dos, y no entero: 100 de los 500.
  let!(:turno) do
    ActsAsTenant.with_tenant(club) do
      res = Mostradores::AbrirTurno.call(mostrador: sede.mostrador!, usuario: admin,
                                         monto_inicial_ars: 0,
                                         items: [{ stock_id: en_la_mesa.id, cantidad: 100 }])
      Mostradores::ConfirmarApertura.call(turno: res.turno, usuario: ana)
      res.turno
    end
  end

  def carrito_de(quien)
    sign_in_as(quien)
    get "/api/stocks?sede_id=#{sede.id}&para_dispensa=1", headers: auth_headers
    JSON.parse(response.body)
  end

  describe 'el dispensador' do
    it 've sólo lo que está sobre la mesa' do
      ids = carrito_de(ana).map { |s| s['id'] }

      expect(ids).to eq([en_la_mesa.id])
    end

    # Ofrecerle 500 cuando arriba hay 100 es prometerle algo que no puede entregar.
    it 'y con el número de la mesa, no el del depósito' do
      fila = carrito_de(ana).first

      expect(fila['cantidad_disponible_real']).to eq(100.0)
    end

    it 'no puede dispensar lo que no bajó a la mesa' do
      d = ActsAsTenant.with_tenant(club) do
        Dispensacion.new(paciente: paciente, user: ana, stock: en_deposito, sede: sede,
                         cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                         fecha_dispensacion: Time.zone.today)
      end

      expect(d).not_to be_valid
      expect(d.errors[:base].join).to match(/No está sobre el mostrador/)
    end
  end

  describe 'el supervisor, que es administración' do
    it 've todo el stock habilitado de la sede' do
      ids = carrito_de(supervisor).map { |s| s['id'] }

      expect(ids).to match_array([en_la_mesa.id, en_deposito.id])
    end

    it 'y con el número del depósito' do
      fila = carrito_de(supervisor).find { |s| s['id'] == en_la_mesa.id }

      # 500 menos los 100 que están apartados sobre la mesa: el apartado sigue valiendo para él.
      expect(fila['cantidad_disponible_real']).to eq(400.0)
    end

    it 'dispensa del depósito con el mostrador abierto' do
      d = ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: supervisor, stock: en_deposito, sede: sede,
                             cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                             fecha_dispensacion: Time.zone.today)
      end

      expect(d).to be_persisted
      expect(en_deposito.reload.cantidad.to_f).to eq(295.0)
    end

    it 'y también con el mostrador cerrado' do
      ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarTurno.call(turno: turno, usuario: ana, efectivo_contado_ars: 0,
                                      conteos: turno.items.map { |i| { item_id: i.id, contado: i.esperado } })

        d = Dispensacion.create!(paciente: paciente, user: supervisor, stock: en_deposito, sede: sede,
                                 cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                                 fecha_dispensacion: Time.zone.today)
        expect(d).to be_persisted
      end
    end

    # Que no pase por el mostrador no significa que el mostrador lo ignore: si saca algo que está
    # arriba, se imputa igual, o el arqueo de la noche le miente al que atendió.
    it 'pero si saca algo que está sobre la mesa, se imputa al turno' do
      item = turno.items.first

      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: supervisor, stock: en_la_mesa, sede: sede,
                             cantidad: 10, medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                             fecha_dispensacion: Time.zone.today)
      end

      expect(item.reload.cantidad_dispensada.to_f).to eq(10.0)
      expect(item.esperado.to_f).to eq(90.0)
    end
  end

  describe 'el admin' do
    it 've todo, igual que el supervisor' do
      ids = carrito_de(admin).map { |s| s['id'] }

      expect(ids).to match_array([en_la_mesa.id, en_deposito.id])
    end
  end
end

# EL MOSTRADOR DE OTRA SEDE NO SE TOCA.
#
# La pantalla sólo ofrece las sedes de la persona, pero la pantalla no es la regla: mandando otro
# `sede_id` se abría, cargaba y cerraba el mostrador de una sede ajena. Es el mismo agujero que
# ya se había tapado en el listado de stock — la asignación de sedes existe justamente para esto.
RSpec.describe 'El mostrador de una sede que no es la mía', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:norte)  { create(:sede, club: club, tipo: 'social', nombre: 'Norte') }
  let(:centro) { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }

  # Dana atiende SÓLO en Norte.
  let(:dana) do
    u = create(:user, :dispensador, club: club)
    ActsAsTenant.with_tenant(club) { UserSede.create!(user: u, sede: norte) }
    u
  end

  before { centro.mostrador! }

  it 'no se puede ni mirar' do
    sign_in_as(dana)
    get "/api/sedes/#{centro.id}/mostrador", headers: auth_headers

    expect(response).to have_http_status(:not_found)
  end

  it 'ni abrir' do
    sign_in_as(dana)
    post "/api/sedes/#{centro.id}/mostrador/abrir", headers: auth_headers,
         params: { monto_inicial_ars: 0, items: [] }

    expect(response).to have_http_status(:not_found)
    expect(centro.mostrador.turno_abierto).to be_nil
  end

  it 'pero la suya sí' do
    sign_in_as(dana)
    get "/api/sedes/#{norte.id}/mostrador", headers: auth_headers

    expect(response).to have_http_status(:ok)
  end

  # Quien no tiene ninguna asignada ve todas: organización de una sola sede, o un admin que no se
  # asignó ninguna.
  it 'y sin sedes asignadas se ven todas' do
    sign_in_as(admin)
    get "/api/sedes/#{centro.id}/mostrador", headers: auth_headers

    expect(response).to have_http_status(:ok)
  end
end
