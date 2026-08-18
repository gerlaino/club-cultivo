require 'rails_helper'

# Auditoría de informes (#29). Un informe que no cierra es peor que no tenerlo: se presenta
# ante un auditor. Lo que se verifica acá es que los totales sean coherentes con su propio
# detalle, que el período se aplique parejo y que no se cuele nada de otro club.
RSpec.describe 'Informes — los totales tienen que cerrar', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)  { create(:sala, sede: sede, club: club, kind: 'mixta') }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  def lote!(estado: 'vegetativo', plantas: 0, **attrs)
    l = create(:lote, club: club, sala: sala, estado: estado, **attrs)
    plantas.times { create(:plant, lote: l, club: club, state: estado) }
    l
  end

  describe 'GET /informes/produccion' do
    it 'el desglose por estado suma los mismos lotes que el total' do
      lote!(estado: 'vegetativo')
      lote!(estado: 'floracion')
      lote!(estado: 'vegetativo')

      get '/api/informes/produccion'

      expect(json['por_estado'].sum { |e| e['lotes'] }).to eq(json['total_lotes'])
    end

    it 'los lotes activos son el total menos los finalizados' do
      lote!(estado: 'vegetativo')
      lote!(estado: 'floracion')
      create(:lote, club: club, sala: nil, sede: sede, estado: 'finalizado')

      get '/api/informes/produccion'

      expect(json['lotes_activos']).to eq(json['total_lotes'] - 1)
    end

    # El encabezado habla del PERÍODO y la tabla de abajo habla del PRESENTE: son dos marcos
    # temporales distintos y ahora está dicho en la pantalla. Antes la tabla traía una columna
    # "Gramos" filtrada por período, así que un lote curado el mes pasado aparecía con 0 g al
    # lado — y el informe se contradecía consigo mismo.
    it 'el KPI es del período y el desglose muestra el rendimiento acumulado' do
      l = lote!(estado: 'curado')
      l.update_columns(rendimiento_real_g: 500, updated_at: 8.months.ago)

      get '/api/informes/produccion', params: { periodo: 'mes_actual' }

      expect(json['gramos_producidos']).to eq(0.0)   # no se cosechó nada este mes
      fila = json['por_estado'].find { |e| e['estado'] == 'curado' }
      expect(fila['rendimiento']).to eq(500.0)       # pero el lote tiene su rendimiento
    end
  end

  describe 'GET /informes/sedes' do
    it 'las plantas totales son la suma de las de cada sede' do
      lote!(estado: 'vegetativo', plantas: 3)

      get '/api/informes/sedes'

      expect(json['plantas_totales']).to eq(json['por_sede'].sum { |s| s['plantas'] })
    end

    it 'no cuenta sedes de otro club' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ActsAsTenant.with_tenant(otro) { create(:sede, club: otro, created_by: otro_admin, tipo: 'produccion') }
      sede

      get '/api/informes/sedes'

      expect(json['total_sedes']).to eq(1)
    end
  end

  describe 'GET /informes/inase' do
    it 'los totales son la suma de las filas' do
      g1 = create(:genetica, club: club, nombre: 'A', registrada_inase: true)
      g2 = create(:genetica, club: club, nombre: 'B', registrada_inase: false)
      lote!(estado: 'floracion', genetica: g1)
      lote!(estado: 'floracion', genetica: g2)

      get '/api/informes/inase'

      # El total tiene que cerrar contra LA TABLA QUE SE MUESTRA, que es la de variedades. Antes
      # cerraba contra las genéticas propias mientras la tabla agrupaba por variedad: los dos
      # números eran correctos por separado y se contradecían en pantalla.
      expect(json['total_variedades']).to eq(json['agrupadas'].size)
      expect(json['lotes_totales']).to eq(json['agrupadas'].sum { |v| v['lotes'] })
      expect(json['con_registro'] + json['falta_registro']).to eq(json['total_variedades'])
    end
  end

  describe 'GET /informes/plan_vs_real' do
    # `lotes` ya viene con `.limit(50)`; contar sobre esa relación con otro `where` encima
    # es la clase de cosa que devuelve un número que no corresponde a la lista mostrada.
    it 'el total de lotes con objetivo coincide con los que muestra el detalle' do
      3.times { lote!(estado: 'floracion', rendimiento_objetivo_g: 500) }

      get '/api/informes/plan_vs_real'

      expect(json['total_lotes_con_objetivo']).to eq(json['detalle'].size)
    end

    it 'los cerrados son los que tienen rendimiento real cargado' do
      lote!(estado: 'floracion', rendimiento_objetivo_g: 500, rendimiento_real_g: 480)
      lote!(estado: 'floracion', rendimiento_objetivo_g: 500)

      get '/api/informes/plan_vs_real'

      expect(json['total_lotes_cerrados']).to eq(1)
    end
  end

  describe 'GET /informes/dispensaciones' do
    let(:paciente) { create(:paciente, club: club, created_by: admin) }
    let(:stock)    { create(:stock, club: club, sede: sede, cantidad: 1000) }

    def dispensar!(cantidad, fecha: Time.zone.today)
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock,
                           cantidad: cantidad, fecha_dispensacion: fecha)
    end

    it 'el promedio es los gramos sobre la cantidad de dispensaciones' do
      dispensar!(10)
      dispensar!(20)

      get '/api/informes/dispensaciones'

      expect(json['total_dispensaciones']).to eq(2)
      expect(json['gramos_dispensados']).to eq(30.0)
      expect(json['promedio_por_dispensacion']).to eq(15.0)
    end

    it 'el resumen por paciente suma los mismos gramos que el total' do
      dispensar!(10)
      dispensar!(20)

      get '/api/informes/dispensaciones'

      expect(json['resumen_anonimizado'].sum { |r| r['total_gramos'] }).to eq(json['gramos_dispensados'])
    end

    it 'una dispensación fuera del período no entra' do
      dispensar!(10)
      dispensar!(99, fecha: 8.months.ago.to_date)

      get '/api/informes/dispensaciones', params: { periodo: 'mes_actual' }

      expect(json['total_dispensaciones']).to eq(1)
      expect(json['gramos_dispensados']).to eq(10.0)
    end
  end
end
