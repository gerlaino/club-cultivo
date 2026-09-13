require 'rails_helper'

# LA DECLARACIÓN JURADA SEMESTRAL COMPONE LOS INFORMES YA REVISADOS con el semestre como período,
# y todo AL CIERRE: un semestre terminado tiene que dar lo mismo hoy que dentro de un año. Antes
# tenía su propia versión de cada cosa, con las reglas viejas (otra población que REPROCANN, la
# vigencia contra HOY, entregas mal sumadas y sin excluir canceladas, la producción de este momento).
RSpec.describe Informes::Semestral do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)  { create(:sala, club: club, sede: sede, kind: 'mixta') }

  # Un semestre YA CERRADO: el primero del año pasado.
  let(:anio)  { Time.zone.today.year - 1 }
  let(:cierre) { Date.new(anio, 6, 30) }

  def declaracion(a = anio, s = 1) = described_class.new(club: club, anio: a, semestre: s).call

  def paciente!(nombre, vence:, numero: 'RP-1', creado: Date.new(anio, 1, 10), **attrs)
    p = create(:paciente, club: club, created_by: admin, nombre: nombre, apellido: 'Test',
                          reprocann_numero: numero, reprocann_vencimiento: vence, **attrs)
    p.update_column(:created_at, creado.to_time)
    p
  end

  describe 'la población' do
    it 'es la del REPROCANN: activos y registrados; los sin registro van como número' do
      paciente!('Ana', vence: cierre + 300)
      paciente!('Beto', vence: nil, numero: nil)                       # nunca inició el trámite
      paciente!('Cata', vence: cierre + 300, es_paciente: false)       # dada de baja

      pac = declaracion[:pacientes]
      expect(pac[:registrados]).to eq(1)
      expect(pac[:nomina].map { |p| p[:nombre_completo] }).to eq(['Ana Test'])
      expect(pac[:sin_registro]).to eq(1)
    end

    # El 1° semestre 2025 bajado hoy marcaba «vencido» a quien venció en agosto de 2026.
    it 'juzga la vigencia AL CIERRE del semestre, no hoy' do
      paciente!('Ana', vence: cierre + 60)     # vigente al 30/6, vencido hoy
      paciente!('Beto', vence: cierre - 5)     # ya vencido al cierre

      pac = declaracion[:pacientes]
      expect(pac[:vigentes]).to eq(1)
      expect(pac[:vencidos]).to eq(1)
      expect(pac[:nomina].find { |p| p[:nombre_completo] == 'Ana Test' }[:reprocann_estado]).to eq('vigente')
    end

    it 'no incluye a quien se dio de alta después del cierre' do
      paciente!('Ana', vence: cierre + 300, creado: cierre + 10)

      expect(declaracion[:pacientes][:registrados]).to eq(0)
    end

    it 'no tiene «por vencer»: quien vence en 20 días está vigente para la declaración' do
      paciente!('Ana', vence: cierre + 20)

      pac = declaracion[:pacientes]
      expect(pac[:vigentes]).to eq(1)
      expect(pac).not_to have_key(:por_vencer)
    end
  end

  describe 'las entregas' do
    it 'cuentan por línea y por unidad, sin canceladas, a esa población' do
      ana   = paciente!('Ana', vence: cierre + 300)
      lote  = create(:lote, club: club, sala: sala)
      flor  = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g', cantidad: 500, estado: 'asignado')
      pre   = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll', unidad: 'un', cantidad: 50, estado: 'asignado')
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: ana, user: admin, stock: flor, sede: sede, cantidad: 10, medio_pago: 'efectivo',
                             fecha_dispensacion: Date.new(anio, 3, 1))
        Dispensacion.create!(paciente: ana, user: admin, stock: pre, sede: sede, cantidad: 4, medio_pago: 'efectivo',
                             fecha_dispensacion: Date.new(anio, 3, 2))
        Dispensacion.create!(paciente: ana, user: admin, stock: flor, sede: sede, cantidad: 99, medio_pago: 'efectivo',
                             fecha_dispensacion: Date.new(anio, 3, 3), estado_envio: 'cancelada')
        Dispensacion.create!(paciente: ana, user: admin, stock: flor, sede: sede, cantidad: 7, medio_pago: 'efectivo',
                             fecha_dispensacion: Date.new(anio, 8, 1))   # otro semestre
      end

      ent = declaracion[:entregas]
      expect(ent[:entregas]).to eq(2)
      expect(ent[:pacientes]).to eq(1)
      expect(ent[:por_unidad]).to contain_exactly({ unidad: 'g', cantidad: 10.0 }, { unidad: 'un', cantidad: 4.0 })
    end
  end

  describe 'el cultivo' do
    def cosechado!(cuando:, gramos:, genetica: nil)
      l = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'curado', rendimiento_real_g: gramos,
                        plants_count_cosechadas: 5, start_date: cuando - 90)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: cuando)
      l
    end

    it 'es lo cosechado EN EL SEMESTRE, por variedad, no la foto de hoy' do
      g = create(:genetica, club: club, nombre: 'Lemon', registrada_inase: true)
      cosechado!(cuando: Date.new(anio, 4, 1), gramos: 300, genetica: g)
      cosechado!(cuando: Date.new(anio, 9, 1), gramos: 999, genetica: g)   # 2° semestre

      cul = declaracion[:cultivo]
      expect(cul[:cosechados][:lotes]).to eq(1)
      expect(cul[:cosechados][:gramos]).to eq(300.0)
      expect(cul[:variedades].first).to include(nombre: 'Lemon', vinculada: true)
    end

    # Un lote que empezó en mayo y se cortó en agosto ESTABA en pie el 30 de junio.
    it 'lo en pie al cierre se reconstruye desde la cronología' do
      cosechado!(cuando: Date.new(anio, 8, 10), gramos: 200)          # en pie al 30/6
      cosechado!(cuando: Date.new(anio, 2, 10), gramos: 200)          # ya cortado al 30/6
      create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: cierre + 30)   # arrancó después

      expect(declaracion[:cultivo][:en_pie][:lotes]).to eq(1)
    end

    it 'lo que sale sin vinculación INASE viaja para el aviso y el candado' do
      casera = create(:genetica, club: club, nombre: 'Casera')
      cosechado!(cuando: Date.new(anio, 4, 1), gramos: 100, genetica: casera)

      d = declaracion
      expect(d[:sin_vincular].map { |g| g[:nombre] }).to eq(['Casera'])
      expect(d[:geneticas_sin_vincular_ids]).to eq([casera.id])
    end
  end

  it 'el semestre en curso corta en hoy y lo dice' do
    d = declaracion(Time.zone.today.year, Time.zone.today.month <= 6 ? 1 : 2)
    expect(d[:periodo][:al]).to eq(Time.zone.today)
    expect(d[:periodo][:cerrado]).to be(false)
  end

  it 'lleva la resolución que la organización cargó en Configuración' do
    club.update!(numero_resolucion_reprocann: '1780/2025')
    expect(declaracion[:club][:numero_resolucion_reprocann]).to eq('1780/2025')
  end
end
