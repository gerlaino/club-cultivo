require 'rails_helper'

# Dónde se le va el producto a la organización.
#
# La merma es inevitable y no es culpa de nadie: se mide para encontrar el cuello de botella —
# qué producto, en qué momento. Por eso el número que manda es el PORCENTAJE sobre lo entregado
# y no los gramos: un ranking absoluto siempre encabeza con lo que más se vende, y eso no dice
# nada.
RSpec.describe 'La merma del mostrador', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  # Flor: mucho volumen, poca merma relativa. Preroll: poco volumen, mucha.
  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 500, precio_sugerido_ars: 1_000)
    end
  end
  let!(:preroll) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll', unidad: 'un',
                     cantidad: 100, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 1_000, precio_sugerido_ars: 2_000)
    end
  end

  # Un turno completo: abrir, recibir, dispensar y cerrar contando.
  def turno!(flor_carga:, flor_disp:, flor_contado:, preroll_carga:, preroll_disp:, preroll_contado:)
    ActsAsTenant.with_tenant(club) do
      res = Mostradores::AbrirTurno.call(
        mostrador: sede.mostrador, usuario: admin, monto_inicial_ars: 0,
        items: [{ stock_id: flor.id, cantidad: flor_carga }, { stock_id: preroll.id, cantidad: preroll_carga }]
      )
      turno = res.turno
      Mostradores::ConfirmarApertura.call(turno: turno, usuario: ana)

      [[flor, flor_disp], [preroll, preroll_disp]].each do |st, cant|
        next if cant.zero?
        Dispensacion.create!(paciente: paciente, user: ana, stock: st, sede: sede, cantidad: cant,
                             medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                             fecha_dispensacion: Time.zone.today)
      end

      conteos = turno.items.map do |it|
        contado = it.stock_id == flor.id ? flor_contado : preroll_contado
        { item_id: it.id, contado: contado, motivo: 'merma de fraccionamiento' }
      end
      Mostradores::CerrarTurno.call(turno: turno, usuario: ana, conteos: conteos,
                                    efectivo_contado_ars: 0, fondo_siguiente_ars: 0)
      turno
    end
  end

  def merma(como: admin, params: {})
    sign_in_as(como)
    get "/api/sedes/#{sede.id}/mostrador/merma", headers: auth_headers, params: params
    JSON.parse(response.body)
  end

  describe 'el resumen' do
    before do
      # Flor: entrega 400, faltan 4  → 1%
      # Preroll: entrega 20, faltan 2 → 10%
      turno!(flor_carga: 500, flor_disp: 400, flor_contado: 96,
             preroll_carga: 50, preroll_disp: 20, preroll_contado: 28)
    end

    it 'cuenta lo entregado, lo que faltó y qué porcentaje es' do
      r = merma['resumen']

      expect(r['turnos']).to eq(1)
      expect(r['dispensado']).to eq(420.0)
      expect(r['faltante']).to eq(6.0)          # 4 de flor + 2 de prerolls
      expect(r['merma_pct']).to eq(1.43)        # 6 / 420
    end

    # En gramos no se compara con nada; en plata se pone al lado de cualquier otro gasto.
    it 'lo valoriza a costo' do
      # 4 g × $500 + 2 un × $1.000 = $4.000
      expect(merma['resumen']['faltante_ars']).to eq(4_000.0)
    end
  end

  describe 'por producto' do
    before do
      turno!(flor_carga: 500, flor_disp: 400, flor_contado: 96,
             preroll_carga: 50, preroll_disp: 20, preroll_contado: 28)
    end

    # El punto de todo el informe: el preroll pierde 2 unidades y la flor 4 gramos, pero el
    # cuello de botella es el preroll. Un ranking por absoluto lo pondría segundo.
    it 'ordena por porcentaje, no por cantidad: el cuello de botella va primero' do
      productos = merma['por_producto']

      expect(productos.first['producto']).to match(/preroll/i)
      expect(productos.first['merma_pct']).to eq(10.0)
      expect(productos.second['merma_pct']).to eq(1.0)
      expect(productos.second['faltante']).to be > productos.first['faltante']
    end
  end

  describe 'por turno' do
    it 'dice cuándo, quién cerró, quién lo había recibido y con qué motivo' do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 197,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)

      t = merma['por_turno'].first
      expect(t['cerrado_por']).to eq(ana.nombre_completo)
      expect(t['recibido_por']).to eq(ana.nombre_completo)
      expect(t['faltante']).to eq(3.0)
      expect(t['motivos']).to include('merma de fraccionamiento')
      expect(t['revisado']).to be(false)
    end

    it 'acumula turnos y los ordena del más nuevo al más viejo' do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 200,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 198,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)

      expect(merma['resumen']['turnos']).to eq(2)
      expect(merma['por_turno'].first['faltante']).to eq(2.0) # el último
    end

    # Si el que recibe corrige seguido, el cuello de botella no es la merma: es quien carga la
    # mesa, que declara mal.
    it 'cuenta las correcciones de recepción' do
      ActsAsTenant.with_tenant(club) do
        res = Mostradores::AbrirTurno.call(mostrador: sede.mostrador, usuario: admin,
                                           monto_inicial_ars: 0,
                                           items: [{ stock_id: flor.id, cantidad: 300 }])
        item = res.turno.items.first
        Mostradores::ConfirmarApertura.call(
          turno: res.turno, usuario: ana,
          correcciones: [{ item_id: item.id, contado: 297, motivo: 'faltaban 3' }]
        )
        Mostradores::CerrarTurno.call(turno: res.turno, usuario: ana,
                                      conteos: [{ item_id: item.id, contado: 297 }],
                                      efectivo_contado_ars: 0, fondo_siguiente_ars: 0)
      end

      expect(merma['por_turno'].first['correcciones']).to eq(1)
    end
  end

  describe 'la lista de trabajo' do
    before do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 197,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)
    end

    it 'cuenta los turnos con faltante que nadie miró todavía' do
      expect(merma['sin_revisar']).to eq(1)
    end

    it 'marcarlo revisado lo saca de la lista' do
      id = merma['por_turno'].first['id']

      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/mostrador/turnos/#{id}/revisar", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(merma['sin_revisar']).to eq(0)
      expect(merma['por_turno'].first['revisado']).to be(true)
    end
  end

  # El aviso tiene que verse SIN entrar a buscarlo: uno que sólo aparece cuando ya fuiste a
  # mirar no avisa nada.
  describe 'el aviso en la carga principal' do
    it 'la pantalla del mostrador ya trae cuántos turnos hay sin mirar' do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 197,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)

      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers

      expect(JSON.parse(response.body)['sin_revisar']).to eq(1)
    end

    it 'un turno que cerró cuadrado no entra en el aviso' do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 200,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)

      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers

      expect(JSON.parse(response.body)['sin_revisar']).to eq(0)
    end

    it 'el que atiende no lo ve' do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 197,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)

      sign_in_as(ana)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers

      expect(JSON.parse(response.body)['sin_revisar']).to eq(0)
    end
  end

  # Pérdidas ya contaba estos gramos, pero mezclados con cualquier otra corrección de inventario:
  # el admin veía un número y no sabía que era lo que se pierde atendiendo — que es lo único de
  # esa lista sobre lo que puede hacer algo esta semana.
  describe 'el informe de Pérdidas' do
    before do
      turno!(flor_carga: 500, flor_disp: 400, flor_contado: 96,
             preroll_carga: 50, preroll_disp: 20, preroll_contado: 28)
      # Un ajuste de inventario que NO es del mostrador: se rompió un frasco en el depósito.
      ActsAsTenant.with_tenant(club) do
        flor.stock_movimientos.create!(tipo: 'ajuste', gramos: -10, usuario: admin,
                                       notas: 'se rompió un frasco')
        flor.update!(cantidad: flor.cantidad - 10)
      end
    end

    def perdidas
      sign_in_as(admin)
      get '/api/informes/perdidas', headers: auth_headers,
          params: { desde: 1.month.ago.to_date.to_s, hasta: Time.zone.today.to_s }
      JSON.parse(response.body)
    end

    it 'separa el faltante del mostrador de los otros ajustes' do
      d = perdidas

      expect(d['merma_mostrador_g']).to eq(6.0)     # 4 de flor + 2 de prerolls
      expect(d['ajustes_negativos_g']).to eq(10.0)  # el frasco roto, que no es del mostrador
    end

    it 'y el total los suma a los dos' do
      expect(perdidas['total_gramos']).to eq(16.0)
    end

    # `end_of_month` es una Date, y comparada contra un timestamp corta a la medianoche: el
    # informe perdía TODO lo del último día del período. Durante el mes no se nota porque el
    # borde está en el futuro; el día 31 se pierde la jornada entera, que es justo cuando alguien
    # cierra el mes y lo mira.
    it 'incluye lo que pasó hoy, aunque hoy sea el último día del mes' do
      viajar_al_ultimo_dia = Time.zone.today.end_of_month.to_time.change(hour: 18)
      travel_to(viajar_al_ultimo_dia) do
        expect(perdidas['total_gramos']).to be > 0
      end
    end

    # El vínculo es una FK, no el texto de las notas: buscar por "Arqueo del mostrador…" se rompe
    # la primera vez que alguien toca el mensaje.
    it 'el ajuste queda enganchado al turno que lo generó' do
      mov = StockMovimiento.de_mostrador.last

      expect(mov.turno_mostrador_id).to be_present
      expect(mov.turno_mostrador.mostrador_id).to eq(sede.mostrador.id)
    end
  end

  describe 'filtros y permisos' do
    before do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 197,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)
    end

    it 'acota al rango pedido' do
      r = merma(params: { desde: 1.year.ago.to_date.to_s, hasta: 1.month.ago.to_date.to_s })

      expect(r['resumen']['turnos']).to eq(0)
    end

    it 'una fecha inventada no rompe la pantalla' do
      merma(params: { desde: 'ayer nomás' })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Es información de gestión: el que atiende no la ve.
    it 'el dispensador no accede' do
      merma(como: ana)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
