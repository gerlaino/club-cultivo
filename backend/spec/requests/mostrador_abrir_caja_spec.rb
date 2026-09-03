require 'rails_helper'

# ABRIR LA CAJA: quien atiende cuenta lo que encuentra y arranca.
#
# Reemplaza a la vieja "recepción" separada, que era el mismo conteo pedido dos veces: el admin
# declaraba, la persona confirmaba, y encima había un botón de "confirmar y arrancar" que nadie
# miraba. Ahora abrir ES contar.
#
# NO BLOQUEA POR DIFERENCIA. Si lo que cuenta no coincide, pone lo que contó y abre igual:
# frenarlo dejaría el mostrador cerrado a las 8 de la mañana esperando a alguien que no está, que
# es exactamente lo que este módulo existe para evitar.
RSpec.describe 'Abrir la caja del mostrador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def cargar!(cantidad)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: cantidad }])
    end
  end

  def abrir!(conteos: nil, efectivo: nil, como: ana, notas: nil)
    sign_in_as(como)
    params = { efectivo_contado_ars: efectivo, notas: notas }.compact
    params[:conteos] = conteos if conteos
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers, params: params
    JSON.parse(response.body)
  end

  def turno = sede.mostrador!.turno_abierto
  def en_la_mesa = mesa_de(sede)[stock.id]

  describe 'el conteo de apertura' do
    before { cargar!(300) }

    it 'si coincide, abre y la mesa no se mueve' do
      cuerpo = abrir!(conteos: [{ stock_id: stock.id, contado: 300 }], efectivo: 10_000)

      expect(response).to have_http_status(:created)
      expect(cuerpo['abierto_por']).to eq(ana.nombre_completo)
      expect(en_la_mesa).to eq(300.0)
    end

    it 'sin contar nada, se toma lo que dice el sistema: confirmar es un click' do
      abrir!(efectivo: 10_000)

      expect(response).to have_http_status(:created)
      expect(turno.items.first.cantidad_apertura.to_f).to eq(300.0)
    end

    it 'si cuenta menos, abre igual y la mesa pasa a tener lo contado' do
      abrir!(conteos: [{ stock_id: stock.id, contado: 297 }], efectivo: 10_000)

      expect(response).to have_http_status(:created)
      expect(en_la_mesa).to eq(297.0)
      expect(turno.items.first.esperado_apertura.to_f).to eq(300.0)
    end

    # Acá todavía no se sabe si faltó de verdad o si el admin declaró de más: el producto puede
    # estar en el depósito. El inventario se ajusta al CERRAR, contra lo que la persona recibió.
    it 'y el inventario no se toca' do
      abrir!(conteos: [{ stock_id: stock.id, contado: 297 }], efectivo: 10_000)

      expect(stock.reload.cantidad.to_f).to eq(1_000.0)
    end

    it 'la diferencia queda escrita para que el admin la lea' do
      abrir!(conteos: [{ stock_id: stock.id, contado: 297 }], efectivo: 10_000)

      expect(turno.notas_apertura).to match(/contó 297.*había 300/)
    end

    it 'con la mesa vacía se puede abrir igual: la carga administración después' do
      ActsAsTenant.with_tenant(club) do
        Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'saco todo',
                                 cambios: [{ stock_id: stock.id, cantidad: 0 }])
      end

      abrir!(efectivo: 0)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'la caja de plata' do
    before { cargar!(300) }

    it 'arranca con el efectivo contado' do
      cuerpo = abrir!(efectivo: 25_000)

      expect(cuerpo['caja']['fondo_ars']).to eq(25_000.0)
    end

    # A diferencia del stock, acá la diferencia SÍ es una pérdida real: los gramos que faltan
    # pueden estar en el depósito, pero los pesos que faltan no están en ningún lado.
    it 'si la caja venía abierta y lo contado no coincide, el fondo pasa a ser lo contado' do
      abrir!(efectivo: 25_000)
      caja = turno.caja_turno
      ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarCaja.call(turno: turno, usuario: ana, efectivo_contado_ars: 25_000,
                                     fondo_siguiente_ars: 25_000,
                                     conteos: [{ stock_id: stock.id, contado: 300 }])
      end
      expect(caja.reload).to be_cerrada

      # El próximo abre contando 24.000 donde el sistema hereda 25.000.
      cuerpo = abrir!(efectivo: 24_000, como: create(:user, :dispensador, club: club))
      expect(cuerpo['caja']['fondo_ars']).to eq(24_000.0)
    end

    it 'el efectivo contado no puede ser negativo' do
      cuerpo = abrir!(efectivo: -100)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/negativo/i)
    end

    # EL PRIMER DÍA no hay ningún cierre anterior del que heredar el fondo. Si tampoco se cuenta
    # nada, el turno abriría igual —no bloquea por diferencia— pero SIN caja: lo cobrado en
    # efectivo no tendría dónde caer, y desaparecería del arqueo de esa noche sin que nadie se
    # enterara hasta contar. Mejor un error claro que un cajón que no existe.
    it 'el primer día, sin nada que heredar, exige contar el efectivo' do
      cuerpo = abrir!(efectivo: nil)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/heredar el fondo/i)
      expect(turno).to be_nil
    end

    it 'con algo que heredar, sí se puede abrir sin escribir nada' do
      abrir!(efectivo: 10_000)
      ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarCaja.call(turno: turno, usuario: ana, efectivo_contado_ars: 10_000,
                                     fondo_siguiente_ars: 10_000,
                                     conteos: [{ stock_id: stock.id, contado: 300 }])
      end

      cuerpo = abrir!(efectivo: nil, como: create(:user, :dispensador, club: club))

      expect(response).to have_http_status(:created)
      expect(cuerpo['caja']['fondo_ars']).to eq(10_000.0)
    end
  end

  describe 'quién puede' do
    before { cargar!(300) }

    it 'la abre quien atiende' do
      abrir!(efectivo: 0, como: ana)
      expect(response).to have_http_status(:created)
    end

    # Que dependa del admin es lo que hace que nadie lo use: a las 8 de la mañana o a las 11 de
    # la noche puede no haber ninguno. Pero él también puede, si hizo falta.
    it 'y también administración' do
      abrir!(efectivo: 0, como: admin)
      expect(response).to have_http_status(:created)
    end

    it 'pero no dos veces' do
      abrir!(efectivo: 0)
      cuerpo = abrir!(efectivo: 0)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/ya hay una caja abierta/i)
    end
  end

  # El apartado NO depende de que haya alguien atendiendo: el producto está físicamente sobre esa
  # mesa a las tres de la tarde y a la medianoche. Antes se liberaba al cerrar el turno, así que
  # de noche el sistema lo daba por libre y una reserva podía comprometerlo.
  describe 'el apartado' do
    it 'sigue vigente con la caja cerrada' do
      cargar!(300)

      expect(sede.mostrador!.turno_abierto).to be_nil
      expect(stock.reload.cantidad_disponible_real.to_f).to eq(700.0)
    end

    it 'y no se suelta al cerrar la caja' do
      cargar!(300)
      abrir!(efectivo: 0)
      ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarCaja.call(turno: turno, usuario: ana, efectivo_contado_ars: 0,
                                     conteos: [{ stock_id: stock.id, contado: 300 }])
      end

      expect(stock.reload.cantidad_disponible_real.to_f).to eq(700.0)
      expect(mesa_de(sede)[stock.id]).to eq(300.0)
    end
  end
end
