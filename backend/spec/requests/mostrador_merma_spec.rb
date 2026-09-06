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

  # Un turno completo: administración carga la mesa, quien atiende abre contando, dispensa y
  # cierra contando.
  def turno!(flor_carga:, flor_disp:, flor_contado:, preroll_carga:, preroll_disp:, preroll_contado:,
             quien: nil, cierra: nil)
    quien ||= ana
    ActsAsTenant.with_tenant(club) do
      mostrador = sede.mostrador!
      Mostradores::Cargar.call(
        mostrador: mostrador, usuario: admin, motivo: 'carga del día',
        cambios: [{ stock_id: flor.id, cantidad: flor_carga },
                  { stock_id: preroll.id, cantidad: preroll_carga }]
      )
      turno = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: quien,
                                          efectivo_contado_ars: 0).turno

      [[flor, flor_disp], [preroll, preroll_disp]].each do |st, cant|
        next if cant.zero?
        Dispensacion.create!(paciente: paciente, user: quien, stock: st, sede: sede, cantidad: cant,
                             medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                             fecha_dispensacion: Time.zone.today)
      end

      Mostradores::CerrarCaja.call(
        turno: turno, usuario: cierra || quien, efectivo_contado_ars: 0, fondo_siguiente_ars: 0,
        conteos: [{ stock_id: flor.id, contado: flor_contado },
                  { stock_id: preroll.id, contado: preroll_contado }],
        notas: 'merma de fraccionamiento'
      )
      # La mesa se vacía para que cada turno del período arranque de cero y sean comparables.
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'cierre del día',
                               cambios: [{ stock_id: flor.id, cantidad: 0 },
                                         { stock_id: preroll.id, cantidad: 0 }])
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
    # `atendio` es quien ABRIÓ contando la mesa: el arqueo del turno es suyo. Se llamaba
    # `recibido_por` cuando había una recepción separada que firmar; ya no la hay — abrir es
    # contar, en un solo gesto.
    it 'dice cuándo, quién cerró, quién atendió y con qué motivo' do
      turno!(flor_carga: 300, flor_disp: 100, flor_contado: 197,
             preroll_carga: 10, preroll_disp: 0, preroll_contado: 10)

      t = merma['por_turno'].first
      expect(t['cerrado_por']).to eq(ana.nombre_completo)
      expect(t['atendio']).to eq(ana.nombre_completo)
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

    # Si quien abre corrige seguido lo que decía la mesa, el cuello de botella no es la merma:
    # es que la mesa se está declarando mal.
    it 'cuenta las correcciones del conteo de apertura' do
      ActsAsTenant.with_tenant(club) do
        mostrador = sede.mostrador!
        Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'carga',
                                 cambios: [{ stock_id: flor.id, cantidad: 300 }])
        # El admin declaró 300 y quien abre cuenta 297.
        turno = Mostradores::AbrirCaja.call(
          mostrador: mostrador, usuario: ana, efectivo_contado_ars: 0,
          conteos: [{ stock_id: flor.id, contado: 297 }]
        ).turno
        Mostradores::CerrarCaja.call(turno: turno, usuario: ana,
                                     conteos: [{ stock_id: flor.id, contado: 297 }],
                                     efectivo_contado_ars: 0, fondo_siguiente_ars: 0)
      end

      expect(merma['por_turno'].first['correcciones']).to eq(1)
    end
  end

  # EL TABLERO POR PERSONA: para saber dónde ajustar.
  #
  # El problema de un ranking de gente no es moral, es estadístico: quien más volumen mueve
  # encabeza siempre, y quien fracciona flor pierde más que quien entrega prerolls. Por eso la
  # fila lleva el volumen, la comparación contra el promedio del MISMO mostrador en el MISMO
  # período, y si hay turnos suficientes como para concluir algo.
  describe 'por persona' do
    let(:beto) { create(:user, :dispensador, club: club) }

    before do
      # Ana: tres turnos prolijos. Entrega 100, falta 1 → 1%.
      3.times do
        turno!(flor_carga: 150, flor_disp: 100, flor_contado: 49,
               preroll_carga: 0, preroll_disp: 0, preroll_contado: 0)
      end
      # Beto: uno solo, y desprolijo. Entrega 100 y faltan 10 → 10%.
      turno!(flor_carga: 150, flor_disp: 100, flor_contado: 40,
             preroll_carga: 0, preroll_disp: 0, preroll_contado: 0, quien: beto)
    end

    it 'atribuye el turno a QUIEN ATENDIÓ, que es quien abrió contando' do
      gente = merma['por_persona']

      expect(gente.map { |g| g['persona'] }).to contain_exactly(ana.nombre_completo, beto.nombre_completo)
      expect(gente.find { |g| g['usuario_id'] == ana.id }['turnos']).to eq(3)
    end

    # El número que dice dónde ajustar. Un porcentaje solo mide cuánto se vendió tanto como
    # cuánto se perdió.
    it 'compara a cada uno contra el promedio del período' do
      gente = merma['por_persona']
      b = gente.find { |g| g['usuario_id'] == beto.id }

      expect(b['merma_pct']).to eq(10.0)
      expect(b['contra_promedio']).to be > 0
      expect(gente.find { |g| g['usuario_id'] == ana.id }['contra_promedio']).to be < 0
    end

    it 'y ordena por porcentaje, con el volumen al lado para no leerlo mal' do
      gente = merma['por_persona']

      expect(gente.first['usuario_id']).to eq(beto.id)
      expect(gente.first['dispensado']).to eq(100.0)
      expect(gente.second['dispensado']).to eq(300.0)
    end

    # Un +9 pts con un solo turno es ruido: la pantalla lo muestra igual —esconderlo sería
    # peor— pero sin conclusión.
    it 'marca quién tiene turnos suficientes como para concluir algo' do
      gente = merma['por_persona']

      expect(gente.find { |g| g['usuario_id'] == beto.id }['suficientes']).to be(false)
      expect(gente.find { |g| g['usuario_id'] == ana.id }['suficientes']).to be(true)
    end

    # Si no, el admin lee el número de alguien que no hizo ese arqueo.
    it 'avisa cuando el turno lo cerró otra persona' do
      turno!(flor_carga: 150, flor_disp: 100, flor_contado: 49,
             preroll_carga: 0, preroll_disp: 0, preroll_contado: 0, quien: beto, cierra: admin)

      b = merma['por_persona'].find { |g| g['usuario_id'] == beto.id }
      expect(b['cerro_otro']).to eq(1)
    end

    it 'no lo ve quien atiende: es información de gestión' do
      merma(como: ana)
      expect(response).to have_http_status(:forbidden)
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
      expect(mov.turno_mostrador.mostrador_id).to eq(sede.mostrador!.id)
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
