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

  let(:genetica) { create(:genetica, club: club, nombre: 'Critical Kush') }

  def lote!(estado: 'vegetativo', plantas: 0, **attrs)
    l = create(:lote, club: club, sala: sala, estado: estado, genetica: genetica, **attrs)
    plantas.times { create(:plant, lote: l, club: club, state: estado) }
    l
  end

  describe 'GET /informes/produccion' do
    it 'la tabla de hoy suma los mismos lotes que los KPIs de en pie y en proceso' do
      lote!(estado: 'vegetativo')
      lote!(estado: 'floracion')
      lote!(estado: 'curado')
      create(:lote, club: club, sala: nil, sede: sede, estado: 'finalizado')  # historia: no es «hoy»

      get '/api/informes/produccion'

      hoy = json['hoy']
      expect(hoy['por_estado'].sum { |e| e['lotes'] }).to eq(hoy['lotes_en_pie'] + hoy['lotes_en_proceso'])
      expect(hoy['lotes_en_pie']).to eq(2)
      expect(hoy['lotes_en_proceso']).to eq(1)
    end

    # El encabezado habla del PERÍODO y la tabla de abajo habla del PRESENTE: son dos marcos
    # temporales distintos. Un lote curado hace medio año tiene su rendimiento en la tabla de
    # hoy y no suma nada al período.
    it 'el KPI es del período y el desglose muestra el rendimiento acumulado' do
      l = lote!(estado: 'curado')
      l.update_columns(rendimiento_real_g: 500)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin,
                             registrado_en: 8.months.ago)

      get '/api/informes/produccion', params: { periodo: 'mes_actual' }

      expect(json['periodo']['gramos']).to eq(0.0)   # no se cosechó nada este mes
      fila = json['hoy']['por_estado'].find { |e| e['estado'] == 'curado' }
      expect(fila['rendimiento']).to eq(500.0)       # pero el lote tiene su rendimiento
    end
  end

  # El desglose «Por sede» de Producción. Era un informe aparte (`/informes/sedes`) con el mismo
  # dato, y se retiró: una organización de una sola sede abría un informe de una fila.
  describe 'GET /informes/produccion — por sede' do
    it 'las plantas en pie son la suma de las de cada sede' do
      lote!(estado: 'vegetativo', plantas: 3)

      get '/api/informes/produccion'

      expect(json['hoy']['plantas_en_pie']).to eq(3)
      expect(json['hoy']['plantas_en_pie']).to eq(json['por_sede'].sum { |s| s['plantas'] })
    end

    it 'no cuenta sedes de otro club' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ActsAsTenant.with_tenant(otro) { create(:sede, club: otro, created_by: otro_admin, tipo: 'produccion') }
      sede

      get '/api/informes/produccion'

      expect(json['por_sede'].map { |s| s['nombre'] }).to eq([sede.nombre])
    end

    # Cuenta SOLO salas de cultivo. Las de proceso post-cosecha (cosecha/secado/curado) son legacy
    # del flujo viejo y no son lugar donde haya plantas.
    it 'cuenta sólo las salas de cultivo, no las de proceso' do
      create(:sala, club: club, sede: sede, kind: 'vegetativo')
      create(:sala, club: club, sede: sede, kind: 'cosecha')   # legacy — no debe contar
      sala                                                      # la mixta del let

      get '/api/informes/produccion'

      fila = json['por_sede'].find { |s| s['nombre'] == sede.nombre }
      expect(fila['salas']).to eq(2)
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
      expect(json['total_variedades']).to eq(json['agrupadas'].size)
    end
  end

  describe 'GET /informes/plan_vs_real' do
    def cosechado!(g_plan:, g_real:, flora_plan: 60, flora_dias: 60, plantas: 10)
      l = lote!(estado: 'curado', rendimiento_objetivo_g: g_plan, rendimiento_real_g: g_real,
                dias_floracion_objetivo: flora_plan, plants_count_cosechadas: plantas)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: (flora_dias + 2).days.ago)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: 2.days.ago)
      l
    end

    # El desvío se PONDERA: un lote de 3 plantas no pesa igual que uno de 40. Y el plan es tiempo
    # además de gramos: los días de floración plan/real van en la fila y en el veredicto.
    it 'compara gramos y días contra el plan, ponderando, y dice quién cumplió' do
      cosechado!(g_plan: 500, g_real: 480, flora_dias: 63)           # gramos ✓ · floración ✓ (dentro de 7)
      cosechado!(g_plan: 500, g_real: 400, flora_dias: 72)           # −20 % · +12 días

      get '/api/informes/plan_vs_real', params: { periodo: 'mes_actual' }

      sa = json['salio']
      expect(sa['total']).to eq(2)
      expect(sa['gramos']).to include('plan' => 1000.0, 'real' => 880.0, 'desvio_pct' => -12.0)
      expect(sa['cumplieron']).to eq(1)
      expect(sa['evaluables']).to eq(2)
      malo = sa['lotes'].find { |l| l['g_real'] == 400.0 }
      expect(malo['flora_real']).to eq(72)
      expect(malo['veredicto']).to eq('-20.0 % gramos · floración +12 días')
    end

    it 'un lote en cultivo va en «cómo viene», contra su plan hasta hoy' do
      l = lote!(estado: 'floracion', dias_floracion_objetivo: 60)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 70.days.ago)

      get '/api/informes/plan_vs_real'

      v = json['viene'].first
      expect(v['dias_plan']).to eq(60)
      expect(v['dias_hoy']).to eq(70)
      expect(v['como_viene']).to include('10 días pasado del plan')
    end

    # La ficha de la genética es de donde el lote hereda el objetivo: si todos sus lotes rinden
    # menos, es la ficha la que hay que corregir.
    it 'compara lo que rinde cada genética con su ficha' do
      genetica.update!(rendimiento: 40, tiempo_floracion: 60)
      cosechado!(g_plan: 400, g_real: 300, plantas: 10, flora_dias: 70)

      get '/api/informes/plan_vs_real'

      x = json['geneticas'].first
      expect(x['g_por_planta_real']).to eq(30.0)
      expect(x['frase']).to eq('rinde 25.0 % menos que su ficha · tarda 10 días más')
    end
  end

  describe 'GET /informes/dispensaciones' do
    let(:paciente) { create(:paciente, club: club, created_by: admin) }
    let(:stock)    { create(:stock, club: club, sede: sede, cantidad: 1000) }

    def dispensar!(cantidad, fecha: Time.zone.today)
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock,
                           cantidad: cantidad, fecha_dispensacion: fecha)
    end

    def gramos(json) = json['salio']['por_unidad'].find { |u| u['unidad'] == 'g' }['cantidad']

    it 'las entregas y los gramos son los del período' do
      dispensar!(10)
      dispensar!(20)

      get '/api/informes/dispensaciones'

      expect(json['salio']['entregas']['valor']).to eq(2)
      expect(gramos(json)).to eq(30.0)
    end

    it 'la fila del paciente suma los mismos gramos que el total' do
      dispensar!(10)
      dispensar!(20)

      get '/api/informes/dispensaciones'

      expect(json['pacientes'].sum { |r| r['flor_seca_g'] }).to eq(gramos(json))
    end

    it 'una dispensación fuera del período no entra' do
      dispensar!(10)
      dispensar!(99, fecha: 8.months.ago.to_date)

      get '/api/informes/dispensaciones', params: { periodo: 'mes_actual' }

      expect(json['salio']['entregas']['valor']).to eq(1)
      expect(gramos(json)).to eq(10.0)
    end

    # «Del 1 al 15» es lo que pide un auditor. Vale para todos los informes.
    it 'acepta un rango a elección' do
      dispensar!(10, fecha: Time.zone.today.beginning_of_month)
      dispensar!(20, fecha: Time.zone.today.beginning_of_month + 20.days) if Time.zone.today.day > 20

      get '/api/informes/dispensaciones', params: { desde: Time.zone.today.beginning_of_month.to_s, hasta: (Time.zone.today.beginning_of_month + 15.days).to_s }

      expect(gramos(json)).to eq(10.0)
    end
  end
end
