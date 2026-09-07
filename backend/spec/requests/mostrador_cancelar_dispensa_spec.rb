require 'rails_helper'

# Cancelar una dispensa que salió de la mesa tiene que devolverle el producto A LA MESA, no sólo
# al stock.
#
# Sin esto el gramo volvía al pozo pero el mostrador lo seguía dando por salido: el frasco
# vuelve a la mesa y a la noche el conteo da un SOBRANTE que el que atendió no puede explicar.
# Es el inverso exacto de `imputar_a_mostrador`.
RSpec.describe 'Cancelar una dispensa del mostrador', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  let!(:turno) { abrir_mostrador!(sede, usuario: admin, recibe: ana) }

  def dispensar!(cantidad = 50)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                           cantidad: cantidad, medio_pago: 'efectivo', aporte_socio_ars: 5_000,
                           fecha_dispensacion: Time.zone.today)
    end
  end

  def item = turno.items.find_by(stock_id: stock.id)

  it 'con el turno abierto, el producto vuelve a la mesa' do
    d = dispensar!(50)
    expect(item.reload.cantidad_dispensada.to_f).to eq(50.0)
    en_mesa_antes = mesa_de(sede)[stock.id]

    ActsAsTenant.with_tenant(club) { d.destroy }

    expect(item.reload.cantidad_dispensada.to_f).to eq(0.0)
    expect(mesa_de(sede)[stock.id]).to eq(en_mesa_antes + 50)
    expect(stock.reload.cantidad.to_f).to eq(500.0)
  end

  # Lo que importa de verdad: que el conteo de la noche siga cerrando.
  it 'y el conteo de la noche sigue cuadrando' do
    d = dispensar!(50)
    ActsAsTenant.with_tenant(club) { d.destroy }

    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
         params: { conteos: [{ stock_id: stock.id, contado: 500 }], efectivo_contado_ars: 0 }

    expect(response).to have_http_status(:ok)
    expect(item.reload.diferencia_cierre.to_f).to eq(0.0)
  end

  # Si el turno ya cerró, su arqueo se hizo con el producto afuera: tocar ese número movería algo
  # que alguien ya firmó. Pero el producto SÍ vuelve a la mesa —ahí es donde está físicamente— y
  # queda disponible para el próximo que lo pida.
  it 'con el turno ya cerrado, no se toca lo que alguien firmó' do
    d = dispensar!(50)
    ActsAsTenant.with_tenant(club) do
      Mostradores::CerrarCaja.call(turno: turno, usuario: ana, efectivo_contado_ars: 0,
                                   conteos: [{ stock_id: stock.id, contado: mesa_de(sede)[stock.id] }])
      d.destroy
    end

    expect(item.reload.cantidad_dispensada.to_f).to eq(50.0) # el arqueo firmado, intacto
    expect(stock.reload.cantidad.to_f).to eq(500.0)          # el producto volvió al inventario
    expect(mesa_de(sede)[stock.id]).to eq(500.0)             # y a la mesa
  end

  # LA OTRA MITAD DE LA REGLA: lo que nunca estuvo arriba y no lo espera nadie, vuelve al
  # DEPÓSITO. Subirlo igual lo dejaría apartado sobre una mesa cerrada — invisible como
  # disponible, esperando que alguien se dé cuenta de bajarlo.
  describe 'un producto que nunca estuvo sobre la mesa' do
    let!(:otra_sede) { create(:sede, club: club, tipo: 'social') }
    let!(:suelto) do
      ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: otra_sede, forma_producto: 'flor_seca', unidad: 'g',
                       lote: create(:lote, club: club, sala: create(:sala, club: club, sede: otra_sede)),
                       cantidad: 300, estado: 'asignado', disponibilidad: 'ambas',
                       precio_sugerido_ars: 100)
      end
    end

    # El admin dispensa del depósito de una sede sin nadie atendiendo, se equivoca y cancela.
    it 'con el mostrador cerrado vuelve al depósito, no queda apartado sobre una mesa vacía' do
      d = ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: admin, stock: suelto, sede: otra_sede,
                             cantidad: 30, medio_pago: 'efectivo', aporte_socio_ars: 3_000,
                             fecha_dispensacion: Time.zone.today)
      end
      expect(suelto.reload.cantidad.to_f).to eq(270.0)

      ActsAsTenant.with_tenant(club) { d.destroy }

      expect(suelto.reload.cantidad.to_f).to eq(300.0)
      expect(mesa_de(otra_sede)).to be_empty
      # Y lo que importa: vuelve a estar LIBRE para el depósito, no apartado.
      expect(suelto.reload.cantidad_disponible_real.to_f).to eq(300.0)
    end

    # Pero si hay alguien atendiendo, sí sube: es el paquete que vuelve del reparto a las 19:00 y
    # el que atiende lo tiene ahí adelante para el próximo que lo pida.
    it 'con alguien atendiendo sí sube a la mesa, aunque no estuviera arriba' do
      d = ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: admin, stock: suelto, sede: otra_sede,
                             cantidad: 30, medio_pago: 'efectivo', aporte_socio_ars: 3_000,
                             fecha_dispensacion: Time.zone.today)
      end
      abrir_mostrador!(otra_sede, usuario: admin, recibe: ana)
      ActsAsTenant.with_tenant(club) { d.destroy }

      expect(mesa_de(otra_sede)[suelto.id]).to eq(300.0)
    end
  end

  # LO QUE ADMINISTRACIÓN BAJA A MEDIA TARDE TAMBIÉN CUENTA EN EL ARQUEO.
  #
  # Los renglones del turno se crean al ABRIR, con lo que había sobre la mesa entonces. Un
  # producto agregado después se puede dispensar —la mesa es el estado de AHORA, no la foto de la
  # mañana— pero no tenía renglón, así que lo entregado no se sumaba a ningún lado: la mesa bajaba
  # y el arqueo decía que de ese producto no salió nada.
  #
  # El faltante seguía cuadrando (el esperado se calcula desde la mesa), pero el informe de merma
  # dividía por un "entregado" más chico y el PORCENTAJE salía inflado — justo el número que se
  # mira para saber si algo cambió.
  describe 'un producto que se cargó DESPUÉS de abrir la caja' do
    let!(:tarde) do
      ActsAsTenant.with_tenant(club) do
        st = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll',
                            unidad: 'un', cantidad: 80, estado: 'asignado',
                            disponibilidad: 'ambas', precio_sugerido_ars: 2_000)
        Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                                 motivo: 'se acabaron los prerolls',
                                 cambios: [{ stock_id: st.id, cantidad: 20 }])
        st
      end
    end

    it 'lo dispensado se suma al arqueo de ese turno' do
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: ana, stock: tarde, sede: sede, cantidad: 5,
                             medio_pago: 'efectivo', aporte_socio_ars: 10_000,
                             fecha_dispensacion: Time.zone.today)
      end

      item = turno.reload.items.find_by(stock_id: tarde.id)
      expect(item).to be_present, 'el turno ni siquiera tiene renglón para ese producto'
      expect(item.cantidad_dispensada.to_f).to eq(5.0)
      # Y no estaba a la mañana: eso es lo que dice el arqueo.
      expect(item.cantidad_apertura.to_f).to eq(0.0)
    end

    it 'y la mesa baja igual' do
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: ana, stock: tarde, sede: sede, cantidad: 5,
                             medio_pago: 'efectivo', aporte_socio_ars: 10_000,
                             fecha_dispensacion: Time.zone.today)
      end

      expect(mesa_de(sede)[tarde.id].to_f).to eq(15.0)
    end
  end
end
