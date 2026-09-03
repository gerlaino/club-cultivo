require 'rails_helper'

# EL MOSTRADOR TIENE CONTENIDO PROPIO, Y EL TURNO ES EL ARQUEO.
#
# Son dos cosas de personas distintas:
#   · QUÉ HAY sobre la mesa → lo decide el admin, cuando quiera, desde donde esté
#   · EL ARQUEO             → lo hace quien atiende, al abrir y al cerrar
#
# Atadas —abrir el turno ERA poner la mercadería— el admin no podía gobernar la mesa a distancia,
# que es el punto entero del módulo: que pueda delegar tranquilo.
RSpec.describe 'El mostrador y su turno', type: :request do
  include AuthHelpers

  let(:club)     { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }
  let(:mostrador) { sede.mostrador! }

  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 200, precio_sugerido_ars: 1_000)
    end
  end

  def cargar!(cantidad, usuario: admin, motivo: 'carga del día')
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: mostrador, usuario: usuario, motivo: motivo,
                               cambios: [{ stock_id: flor.id, cantidad: cantidad }])
    end
  end

  def abrir!(conteos: [], efectivo: nil, usuario: ana)
    ActsAsTenant.with_tenant(club) do
      Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: usuario,
                                  conteos: conteos, efectivo_contado_ars: efectivo)
    end
  end

  describe 'el admin gobierna la mesa' do
    it 'sube producto y queda apartado, sin descontarlo del stock' do
      expect(cargar!(300)).to be_ok

      expect(mostrador.sobre_la_mesa.first.cantidad.to_f).to eq(300.0)
      expect(flor.reload.cantidad.to_f).to eq(1_000.0)              # NO se descuenta
      expect(flor.cantidad_disponible_real.to_f).to eq(700.0)       # sí se aparta
    end

    it 'y lo puede bajar' do
      cargar!(300)
      cargar!(120, motivo: 'me llevo el resto al depósito')

      expect(mostrador.sobre_la_mesa.first.cantidad.to_f).to eq(120.0)
      expect(flor.reload.cantidad_disponible_real.to_f).to eq(880.0)
    end

    # "Hay 300 g" sin historial es un número que apareció, y monitorear a distancia sin historial
    # es mirar una foto.
    it 'cada cambio deja quién y por qué' do
      cargar!(300, motivo: 'apertura del lunes')

      mov = MostradorMovimiento.unscoped.recientes.first
      expect(mov.tipo).to eq('carga')
      expect(mov.cantidad.to_f).to eq(300.0)
      expect(mov.usuario_id).to eq(admin.id)
      expect(mov.motivo).to eq('apertura del lunes')
    end

    it 'sin motivo no se toca la mesa' do
      res = cargar!(300, motivo: nil)

      expect(res).not_to be_ok
      expect(res.error).to match(/por qué/i)
      expect(mostrador.items.count).to eq(0)
    end

    it 'no se sube más de lo que hay libre en el depósito' do
      res = cargar!(5_000)

      expect(res).not_to be_ok
      expect(res.error).to match(/No hay tanto/i)
    end

    # El contenido no depende de que alguien esté atendiendo: el producto está físicamente sobre
    # esa mesa a las tres de la tarde y a la medianoche.
    it 'lo cargado sigue apartado con la caja cerrada' do
      cargar!(300)

      expect(mostrador.turno_abierto).to be_nil
      expect(flor.reload.cantidad_disponible_real.to_f).to eq(700.0)
    end
  end

  describe 'quien atiende abre contando' do
    before { cargar!(300) }

    it 'si coincide, abre y la mesa no se mueve' do
      res = abrir!(conteos: [{ stock_id: flor.id, contado: 300 }], efectivo: 0)

      expect(res).to be_ok
      expect(mostrador.reload.sobre_la_mesa.first.cantidad.to_f).to eq(300.0)
      item = res.turno.items.first
      expect(item.esperado_apertura.to_f).to eq(300.0)
      expect(item.cantidad_apertura.to_f).to eq(300.0)
    end

    # NO BLOQUEA. Si contara menos y se lo frenara, el mostrador queda cerrado a las 8 de la
    # mañana esperando a alguien que no está — justo lo que el módulo existe para evitar.
    it 'si cuenta menos, abre igual y la mesa pasa a tener lo contado' do
      res = abrir!(conteos: [{ stock_id: flor.id, contado: 297 }], efectivo: 0)

      expect(res).to be_ok
      expect(mostrador.reload.sobre_la_mesa.first.cantidad.to_f).to eq(297.0)
      expect(res.turno.items.first.esperado_apertura.to_f).to eq(300.0)
      expect(res.turno.notas_apertura).to match(/contó 297.*había 300/)
    end

    # El conteo de apertura NO toca el inventario: acá todavía no se sabe si faltó de verdad o si
    # el admin declaró de más, y el producto puede estar en el depósito.
    it 'y el inventario no se toca al abrir' do
      abrir!(conteos: [{ stock_id: flor.id, contado: 297 }], efectivo: 0)

      expect(flor.reload.cantidad.to_f).to eq(1_000.0)
    end

    it 'sin contar nada, se toma lo que dice el sistema' do
      res = abrir!(efectivo: 0)

      expect(res).to be_ok
      expect(res.turno.items.first.cantidad_apertura.to_f).to eq(300.0)
    end

    it 'no se abren dos cajas en el mismo mostrador' do
      abrir!(efectivo: 0)
      res = abrir!(efectivo: 0)

      expect(res).not_to be_ok
      expect(res.error).to match(/ya hay una caja abierta/i)
    end
  end

  describe 'dispensar baja la mesa' do
    before do
      cargar!(300)
      abrir!(efectivo: 0)
    end

    it 'lo entregado sale de la mesa y del stock' do
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: ana, stock: flor, sede: sede, cantidad: 10,
                             medio_pago: 'efectivo', aporte_socio_ars: 10_000,
                             fecha_dispensacion: Time.zone.today)
      end

      expect(mostrador.reload.sobre_la_mesa.first.cantidad.to_f).to eq(290.0)
      expect(flor.reload.cantidad.to_f).to eq(990.0)
      # Y el disponible baja UNA sola vez: 990 en el depósito menos 290 apartados.
      expect(flor.cantidad_disponible_real.to_f).to eq(700.0)
    end

    it 'no se dispensa lo que no está sobre la mesa' do
      otro = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'hash', unidad: 'g',
                       cantidad: 50, estado: 'asignado', disponibilidad: 'ambas')
      end

      d = ActsAsTenant.with_tenant(club) do
        Dispensacion.new(paciente: paciente, user: ana, stock: otro, sede: sede, cantidad: 2,
                         medio_pago: 'efectivo', aporte_socio_ars: 200,
                         fecha_dispensacion: Time.zone.today)
      end

      expect(d).not_to be_valid
      expect(d.errors[:base].join).to match(/No está sobre el mostrador/)
    end
  end

  describe 'cerrar caja' do
    let!(:turno) { cargar!(300) && abrir!(efectivo: 10_000).turno }

    def cerrar!(contado, efectivo: 10_000, usuario: ana, fondo: nil)
      ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarCaja.call(turno: turno, usuario: usuario,
                                     conteos: [{ stock_id: flor.id, contado: contado }],
                                     efectivo_contado_ars: efectivo, fondo_siguiente_ars: fondo,
                                     notas: 'merma de fraccionamiento')
      end
    end

    it 'si cuadra, cierra sin tocar el inventario' do
      expect(cerrar!(300)).to be_ok

      expect(turno.reload).to be_cerrado
      expect(flor.reload.cantidad.to_f).to eq(1_000.0)
    end

    # Acá la diferencia SÍ es real: el producto estaba sobre la mesa, se contó, y no está.
    it 'el faltante ajusta el inventario y la mesa' do
      cerrar!(295)

      expect(flor.reload.cantidad.to_f).to eq(995.0)
      expect(mostrador.reload.sobre_la_mesa.first.cantidad.to_f).to eq(295.0)
      mov = flor.stock_movimientos.where(tipo: 'ajuste').last
      expect(mov.gramos.to_f).to eq(-5.0)
      # NUNCA como merma: el informe de Pérdidas cuenta merma y esto puede estar entero.
      expect(mov.tipo).to eq('ajuste')
    end

    it 'y queda escrito lo esperado contra lo contado, para poder mostrarlo' do
      cerrar!(295)

      item = turno.reload.items.first
      expect(item.esperado_cierre.to_f).to eq(300.0)
      expect(item.cantidad_cierre.to_f).to eq(295.0)
    end

    it 'la diferencia no bloquea el cierre' do
      expect(cerrar!(280)).to be_ok
      expect(turno.reload).to be_cerrado
    end

    # Cerrar y volver a abrir ES el arqueo: sirve igual para el cambio de turno.
    it 'el que sigue abre con lo que quedó sobre la mesa' do
      cerrar!(295)
      otra = create(:user, :dispensador, club: club)

      res = abrir!(conteos: [{ stock_id: flor.id, contado: 295 }], efectivo: 10_000, usuario: otra)

      expect(res).to be_ok
      expect(res.turno.items.first.esperado_apertura.to_f).to eq(295.0)
    end

    it 'falta contar algo y no cierra' do
      res = ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarCaja.call(turno: turno, usuario: ana, conteos: [],
                                     efectivo_contado_ars: 10_000)
      end

      expect(res).not_to be_ok
      expect(res.error).to match(/falta contar/i)
    end
  end
end
