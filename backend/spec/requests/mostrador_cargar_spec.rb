require 'rails_helper'

# EL ADMIN GOBIERNA LA MESA, DESDE DONDE ESTÉ.
#
# Escribe cuánto tiene que haber de cada producto sobre el mostrador —el TOTAL, no el delta— y
# guarda con un motivo. Puede hacerlo a las 7 de la mañana antes de que llegue nadie, o desde el
# celular a media tarde porque se acabó algo. Ese es el punto entero del módulo: delegar tranquilo
# y monitorear a distancia.
#
# Subir a la mesa APARTA, no descuenta. Y bajar NO es un retiro a nombre de nadie: el producto
# sigue adentro de la organización, sólo vuelve al depósito.
RSpec.describe 'Cargar la mesa del mostrador', type: :request do
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

  def cargar!(cantidad, sobre: stock, como: admin, motivo: 'carga del día', destino: nil)
    sign_in_as(como)
    cambio = { stock_id: sobre.id, cantidad: cantidad }
    cambio[:destino] = destino if destino
    post "/api/sedes/#{sede.id}/mostrador/cargar", headers: auth_headers,
         params: { cambios: [cambio], motivo: motivo }
    JSON.parse(response.body)
  end

  def en_la_mesa(s = stock) = mesa_de(sede)[s.id]

  describe 'subir y bajar' do
    it 'sube lo que se le indique, y queda apartado sin descontarse' do
      cuerpo = cargar!(300)

      expect(response).to have_http_status(:ok)
      expect(en_la_mesa).to eq(300.0)
      expect(cuerpo['mesa'].first['mostrador']).to eq(300.0)
      expect(stock.reload.cantidad.to_f).to eq(1_000.0)            # NO se descuenta
      expect(stock.cantidad_disponible_real.to_f).to eq(700.0)     # sí se aparta
    end

    # Se escribe el TOTAL que tiene que quedar, no la diferencia: pedirle al usuario que calcule
    # el delta es pedirle la cuenta que hace la máquina.
    it 'el número que se manda es el total, no lo que se agrega' do
      cargar!(300)
      cargar!(500, motivo: 'reposición del mediodía')

      expect(en_la_mesa).to eq(500.0)
      expect(stock.reload.cantidad_disponible_real.to_f).to eq(500.0)
    end

    it 'y baja escribiendo un número más chico' do
      cargar!(300)
      cargar!(120, motivo: 'me llevo el resto al depósito')

      expect(en_la_mesa).to eq(120.0)
      expect(stock.reload.cantidad_disponible_real.to_f).to eq(880.0)
    end

    it 'no deja subir más de lo que queda libre en el depósito' do
      cuerpo = cargar!(5_000)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/No hay tanto/i)
      expect(en_la_mesa).to be_nil
    end

    # El gramo no salió de la organización ni cambió de sede: sigue siendo la misma fila, sólo
    # cambia quién responde por él. Ese rastro vive en `MostradorMovimiento`, no en el inventario.
    it 'cargar no deja movimiento de stock' do
      expect { cargar!(300) }.not_to change { stock.stock_movimientos.count }
    end
  end

  describe 'el rastro' do
    # "Hay 300 g" sin historial es un número que apareció, y monitorear a distancia sin historial
    # es mirar una foto.
    it 'cada cambio queda con quién y por qué' do
      cargar!(300, motivo: 'apertura del lunes')

      mov = MostradorMovimiento.unscoped.recientes.first
      expect(mov.tipo).to eq('carga')
      expect(mov.cantidad.to_f).to eq(300.0)
      expect(mov.usuario_id).to eq(admin.id)
      expect(mov.motivo).to eq('apertura del lunes')
    end

    it 'bajar queda como retiro de la mesa' do
      cargar!(300)
      cargar!(100, motivo: 'sobra')

      expect(MostradorMovimiento.unscoped.recientes.first.tipo).to eq('retiro')
    end

    it 'sin motivo no se toca la mesa' do
      cuerpo = cargar!(300, motivo: nil)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/por qué/i)
      expect(en_la_mesa).to be_nil
    end
  end

  # La mesa la carga administración. Quien atiende nunca elige qué hay: cuenta lo que encuentra.
  describe 'quién puede' do
    it 'el dispensador no carga la mesa' do
      cuerpo = cargar!(300, como: ana)

      expect(response).to have_http_status(:forbidden)
      expect(cuerpo['error']).to match(/administración/i)
      expect(en_la_mesa).to be_nil
    end

    it 'el supervisor sí: es administración' do
      cargar!(300, como: create(:user, :supervisor, club: club))

      expect(response).to have_http_status(:ok)
      expect(en_la_mesa).to eq(300.0)
    end
  end

  describe 'lo que no se puede subir' do
    it 'stock de otra sede' do
      otra  = create(:sede, club: club, tipo: 'social')
      ajeno = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: otra, lote: lote, forma_producto: 'flor_seca',
                       unidad: 'g', cantidad: 100, estado: 'asignado', disponibilidad: 'ambas')
      end

      cuerpo = cargar!(50, sobre: ajeno)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/no está asignado a esta sede/i)
    end

    it 'ni stock que no está habilitado para dispensa' do
      solo_prod = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                       unidad: 'g', cantidad: 100, estado: 'asignado', disponibilidad: 'produccion')
      end

      cuerpo = cargar!(50, sobre: solo_prod)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to match(/no está habilitado para dispensa/i)
    end
  end

  # Se compara contra lo que llegó a haber en el turno, no contra un número fijo: 20 g quedando
  # de 500 es distinto de 20 quedando de 25.
  describe 'las señales de la pantalla' do
    def mesa_json(como = admin)
      sign_in_as(como)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
      JSON.parse(response.body)['mesa']
    end

    it 'avisa REPONER cuando queda poco arriba pero hay abajo' do
      cargar!(300)
      abrir = ActsAsTenant.with_tenant(club) do
        Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana, efectivo_contado_ars: 0)
      end
      expect(abrir).to be_ok
      cargar!(5, motivo: 'se dispensó casi todo')

      expect(mesa_json.first['senal']).to eq('reponer')
    end

    it 'avisa SIN REPUESTO cuando no queda arriba ni abajo' do
      cargar!(1_000)
      ActsAsTenant.with_tenant(club) do
        Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana, efectivo_contado_ars: 0)
      end
      cargar!(5, motivo: 'casi vacío')
      # Todo lo demás salió del depósito por otra vía: no hay con qué reponer.
      ActsAsTenant.with_tenant(club) { stock.update!(cantidad: 5) }

      expect(mesa_json.first['senal']).to eq('sin_repuesto')
    end

    it 'sin nada raro, ninguna señal' do
      cargar!(300)
      ActsAsTenant.with_tenant(club) do
        Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana, efectivo_contado_ars: 0)
      end

      expect(mesa_json.first['senal']).to be_nil
    end
  end

  # BAJAR NO SIEMPRE ES "VUELVE AL DEPÓSITO".
  #
  # Si se bajan 12 g porque se perdieron y vuelven al depósito, esos gramos quedan contados como
  # existentes: el inventario miente y la pérdida no se mide en ningún lado. Cada línea que baja
  # dice a dónde va.
  describe 'lo que baja: al depósito o a la merma' do
    before { cargar!(300) }

    it 'por defecto vuelve al depósito y el inventario no se toca' do
      expect { cargar!(100, motivo: 'sobró de la mañana') }
        .not_to change { stock.reload.cantidad.to_f }

      expect(en_la_mesa).to eq(100.0)
      expect(stock.cantidad_disponible_real.to_f).to eq(900.0)   # se libera lo apartado
    end

    it 'declarada MERMA, sale del inventario de verdad' do
      cargar!(100, motivo: 'se cayó el frasco', destino: 'merma')

      expect(response).to have_http_status(:ok)
      expect(en_la_mesa).to eq(100.0)
      expect(stock.reload.cantidad.to_f).to eq(800.0)            # 200 g que ya no existen
    end

    # El informe de Pérdidas cuenta `merma`. Un `ajuste` diría "no cuadró", que no es lo mismo que
    # "se perdió" — y para un auditor la diferencia importa.
    it 'y queda como merma, no como ajuste, con el motivo escrito' do
      cargar!(100, motivo: 'se cayó el frasco', destino: 'merma')

      mov = stock.stock_movimientos.reload.order(:id).last
      expect(mov.tipo).to eq('merma')
      expect(mov.gramos.to_f).to eq(-200.0)
      expect(mov.notas).to include('se cayó el frasco')
    end

    it 'no deja declarar más merma que lo que existe' do
      ActsAsTenant.with_tenant(club) { stock.update!(cantidad: 250) }

      cuerpo = cargar!(0, motivo: 'todo perdido', destino: 'merma')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cuerpo['error']).to include('más merma que lo que hay')
      expect(en_la_mesa).to eq(300.0)   # no se movió nada
    end

    # Subir nunca puede ser una pérdida: viene del depósito.
    it 'al SUBIR ignora el destino' do
      expect { cargar!(400, motivo: 'reposición', destino: 'merma') }
        .not_to change { stock.reload.cantidad.to_f }

      expect(en_la_mesa).to eq(400.0)
    end
  end
end
