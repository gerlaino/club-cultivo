require 'rails_helper'

# AC del modelo comercial (ago-2026): el plan dice CUÁNTO, nunca QUÉ.
#
# LOS ESCALONES (6-oct-2026, Germán y su socio):
#   Autocultivo ......... 9 plantas en floración, vege libre, 2 espacios.
#   Hasta 50 pacientes .. 450 en floración, 3 salas, 1 sede, 2 usuarios de cada rol.
#   Hasta 100 pacientes . 900 en floración, salas libres, 3 sedes, 2 de cada rol POR SEDE.
#   Encima: packs de 10 pacientes (+10 pacientes, +90 plantas en floración) y sedes extra.
#   El tope de floración es un candado; las automáticas cuentan todo su ciclo.
#
# Antes convivían dos sistemas que se contradecían: los cuatro planes viejos fijaban los
# límites duros y las suites decidían las capacidades, así que un club "federación" sin suites
# quedaba sin límites y sin poder hacer nada. Ahora los límites son del plan y los módulos son
# de las suites, y no se cruzan.
RSpec.describe PlanEnforcer do
  let(:club) { create(:club, plan: 'basico') }

  # El hook de spec/support/tenant.rb fija `test_tenant`, pero `current_tenant` le gana, y con
  # el orden aleatorio de RSpec puede llegar sucio de un ejemplo anterior cuya transacción ya
  # se revirtió: acts_as_tenant pisa el club_id de la sede/sala con un id que ya no existe y la
  # validación de presencia falla. `with_tenant` lo fija para este ejemplo y lo restaura al
  # salir, así el spec no depende del orden.
  around { |ejemplo| ActsAsTenant.with_tenant(club) { ejemplo.run } }

  describe 'los planes' do
    # Dos de organización y, desde sep-2026, el personal: el cultivador de casa.
    it 'existen básico, total y personal' do
      expect(described_class::PLANES.keys).to contain_exactly('basico', 'total', 'personal')
    end

    it 'cada escalón tiene los topes que se acordaron' do
      expect(described_class::PLANES['personal']).to include(plantas: 9,   salas: 2,   sedes: 1, pacientes: 0, equipo: false)
      expect(described_class::PLANES['basico']).to   include(plantas: 450, salas: 3,   sedes: 1, pacientes: 50,
                                                             usuarios_por_rol: 2, por_sede: false)
      expect(described_class::PLANES['total']).to    include(plantas: 900, salas: nil, sedes: 3, pacientes: 100,
                                                             usuarios_por_rol: 2, por_sede: true)
    end

    # `lotes` NO se limita: el lote es una unidad de organización, no de capacidad, y ponerle
    # tope empuja a meter todo en un lote gigante — que rompe la trazabilidad. Lo que mide la
    # capacidad real del cultivo son las plantas. `usuarios` tampoco: pasó a ser uno por rol.
    it 'el básico limita sedes, salas, plantas y pacientes' do
      %i[sedes salas plantas pacientes].each do |recurso|
        expect(described_class::PLANES['basico'][recurso]).to be_a(Integer),
                                                              "el plan básico debería limitar #{recurso}"
      end
    end

    it 'el básico NO limita los lotes' do
      expect(described_class::PLANES['basico'][:lotes]).to be_nil
      expect(described_class.new(club).puede_crear_lote?).to be(true)
    end
  end

  describe '.normalizar' do
    # Los cuatro planes viejos siguen apareciendo en copias y seeds. Ninguno puede caer en
    # "sin límites" por accidente: el que no se reconoce cae al plan chico, que es el
    # conservador.
    it 'mapea los planes viejos a los dos nuevos' do
      expect(described_class.normalizar('semilla')).to    eq('basico')
      expect(described_class.normalizar('brote')).to      eq('basico')
      expect(described_class.normalizar('cosecha')).to    eq('total')
      expect(described_class.normalizar('federacion')).to eq('total')
    end

    it 'un plan desconocido o vacío cae al básico, no al ilimitado' do
      expect(described_class.normalizar('cualquier_cosa')).to eq('basico')
      expect(described_class.normalizar(nil)).to              eq('basico')
    end

    it 'deja pasar los planes vigentes' do
      expect(described_class.normalizar('total')).to eq('total')
    end
  end

  describe 'límites del plan básico' do
    it 'deja crear la primera sede y frena la segunda' do
      expect(described_class.new(club).puede_crear_sede?).to be(true)

      create(:sede, club: club, created_by: create(:user, :admin, club: club))

      expect(described_class.new(club.reload).puede_crear_sede?).to be(false)
    end

    # El límite que faltaba: sin él, un club de una sola sede abría salas sin techo — el plan
    # medía el continente y no el contenido.
    it 'frena las salas al llegar al tope' do
      admin = create(:user, :admin, club: club)
      tope  = described_class::PLANES['basico'][:salas]

      (tope - 1).times { create(:sala, club: club, created_by: admin) }
      expect(described_class.new(club.reload).puede_crear_sala?).to be(true)

      create(:sala, club: club, created_by: admin)
      expect(described_class.new(club.reload).puede_crear_sala?).to be(false)
    end

    # Sólo la sala dada de baja libera lugar.
    it 'la sala cerrada deja de ocupar lugar' do
      admin = create(:user, :admin, club: club)
      described_class::PLANES['basico'][:salas].times { create(:sala, club: club, created_by: admin) }
      expect(described_class.new(club.reload).puede_crear_sala?).to be(false)

      club.salas.first.update!(state: 'cerrada')

      expect(described_class.new(club.reload).puede_crear_sala?).to be(true)
    end

    # El agujero obvio si el límite contara sólo las salas activas: se ponen todas en
    # mantenimiento y se abren salas sin techo. Una sala en mantenimiento vuelve mañana.
    it 'la sala en mantenimiento SIGUE ocupando lugar' do
      admin = create(:user, :admin, club: club)
      described_class::PLANES['basico'][:salas].times { create(:sala, club: club, created_by: admin) }

      club.salas.each { |s| s.update!(state: 'mantenimiento') }

      expect(described_class.new(club.reload).puede_crear_sala?).to be(false)
    end
  end

  describe 'Hasta 100 pacientes' do
    let(:club) { create(:club, plan: 'total') }

    it 'salas libres y tres sedes; la cuarta, no' do
      admin = create(:user, :admin, club: club)
      10.times { create(:sala, club: club, created_by: admin) }
      2.times { create(:sede, club: club, created_by: admin) }
      enforcer = described_class.new(club.reload)
      expect(enforcer.puede_crear_sala?).to be(true)
      expect(enforcer.puede_crear_sede?).to be(true)

      create(:sede, club: club, created_by: admin)
      expect(described_class.new(club.reload).puede_crear_sede?).to be(false)
    end
  end

  describe 'lo comprado encima del escalón' do
    it 'cada pack de 10 pacientes suma 10 pacientes y 90 plantas en floración' do
      club.update!(packs_pacientes_extra: 3)
      limites = described_class.new(club).info[:limites]

      expect(limites[:pacientes]).to eq(50 + 30)
      expect(limites[:plantas]).to   eq(450 + 270)
    end

    it 'cada sede extra suma una sede' do
      admin = create(:user, :admin, club: club)
      create(:sede, club: club, created_by: admin)
      expect(described_class.new(club.reload).puede_crear_sede?).to be(false)

      club.update!(sedes_extra: 1)
      expect(described_class.new(club.reload).puede_crear_sede?).to be(true)
    end

    it 'el autocultivo no compra extras: sus topes no se mueven' do
      personal = create(:club, plan: 'personal', packs_pacientes_extra: 5, sedes_extra: 2)
      limites  = described_class.new(personal).info[:limites]

      expect(limites).to include(plantas: 9, sedes: 1, pacientes: 0)
    end
  end

  # El tope es de plantas EN FLORACIÓN: el vegetativo es libre. Es un candado, también en el
  # autocultivo, y vale por cualquier puerta (está en los modelos).
  describe 'el cupo de floración' do
    let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true }) }
    let(:sala)  { create(:sala, club: club, kind: 'mixta') }
    let(:auto)  { create(:genetica, club: club, automatica: true) }

    def lote_con(n, estado:, genetica: nil)
      lote = create(:lote, club: club, sala: sala, estado: estado, genetica: genetica, plants_count: n)
      n.times { |i| create(:plant, lote: lote, club: club, state: estado, nombre: "#{lote.codigo}-#{i}") }
      lote
    end

    it 'el vegetativo es libre' do
      lote_con(20, estado: 'vegetativo')
      expect(described_class.new(club).info[:uso][:plantas]).to eq(0)
    end

    it 'entran 9 en floración y la décima no' do
      lote = lote_con(9, estado: 'floracion')

      decima = Plant.new(lote: lote, club: club, state: 'floracion', nombre: 'X-10')
      expect(decima).not_to be_valid
      expect(decima.errors.full_messages.join).to include('9 plantas en floración')
    end

    it 'un lote de 10 en vegetativo no puede pasar a floración' do
      lote = lote_con(10, estado: 'vegetativo')

      expect(lote.update(estado: 'floracion')).to be(false)
      expect(lote.errors.full_messages.join).to include('floración')
    end

    it 'un lote de 9 sí pasa' do
      lote = lote_con(9, estado: 'vegetativo')
      expect(lote.update(estado: 'floracion')).to be(true)
    end

    # Las automáticas nunca pasan a «floración» en la app: cuentan todo el ciclo.
    it 'las automáticas cuentan aunque estén en vegetativo' do
      lote_con(9, estado: 'vegetativo', genetica: auto)

      expect(described_class.new(club).info[:uso][:plantas]).to eq(9)
      lote = lote_con(1, estado: 'vegetativo') # una fotoperiódica en vege sigue entrando
      expect(lote.plants.count).to eq(1)
      expect(Plant.new(lote: club.lotes.where(genetica: auto).first, club: club,
                       state: 'vegetativo', nombre: 'A-10')).not_to be_valid
    end

    # Semántica de la suma: alcanza con que el cupo lo llenen las de OTRO lote.
    it 'suma las de todos los lotes: automáticas y en floración juntas' do
      lote_con(5, estado: 'vegetativo', genetica: auto)
      lote = lote_con(4, estado: 'vegetativo')

      expect(lote.update(estado: 'floracion')).to be(true)
      lote.plants.update_all(state: 'floracion') # lo que hace cada puerta después de mover el lote
      expect(Plant.new(lote: lote, club: club, state: 'floracion', nombre: 'Y-5')).not_to be_valid
    end

    it 'las cosechadas y descartadas no ocupan cupo' do
      lote = lote_con(9, estado: 'floracion')
      lote.plants.first.update_columns(state: 'descartada')

      expect(Plant.new(lote: lote, club: club, state: 'floracion', nombre: 'Z-10')).to be_valid
    end
  end

  # El cupo de usuarios es del EQUIPO y va POR ROL. Un número global ("5 usuarios") no se puede
  # vender ni explicar, y dejaba dar de alta cinco cultivadores y ningún dispensador.
  #
  # El paciente tiene cuenta para su portal y ya gasta su propio límite (`pacientes`):
  # contándolo también acá se cobraba dos veces.
  describe 'límite de usuarios' do
    it '«Hasta 50 pacientes» deja DOS de cada rol' do
      create(:user, club: club, role: 'cultivador')
      expect(described_class.new(club.reload).puede_crear_usuario?('cultivador')).to be(true)
      create(:user, club: club, role: 'cultivador')

      enforcer = described_class.new(club.reload)
      expect(enforcer.puede_crear_usuario?('cultivador')).to be(false)
      # El cupo es por rol: que esté lleno el de cultivador no toca al de dispensador.
      expect(enforcer.puede_crear_usuario?('dispensador')).to be(true)
    end

    it '«Hasta 100 pacientes» deja dos de cada rol por cada sede' do
      total = create(:club, plan: 'total')
      ActsAsTenant.with_tenant(total) do
        2.times { create(:user, club: total, role: 'cultivador') }
        expect(described_class.new(total.reload).puede_crear_usuario?('cultivador')).to be(false)

        create(:sede, club: total)
        create(:sede, club: total)
        expect(described_class.new(total.reload).puede_crear_usuario?('cultivador')).to be(true)
      end
    end

    it 'no cuenta las cuentas de portal de los pacientes' do
      5.times { create(:user, club: club, role: 'paciente') }

      expect(described_class.new(club.reload).puede_crear_usuario?('cultivador')).to be(true)
    end

    it 'el uso que se informa cuenta igual que el tope' do
      create(:user, club: club, role: 'paciente')
      create(:user, club: club, role: 'cultivador')

      expect(described_class.new(club.reload).info[:uso][:usuarios]).to eq(1)
    end

    it 'informa cuántos permite por rol' do
      expect(described_class.new(club).info[:usuarios_por_rol]).to eq(2)
      expect(described_class.new(create(:club, plan: 'total')).info[:por_sede]).to be(true)
    end
  end

  describe '#info' do
    it 'informa los seis límites y el uso de cada uno' do
      info = described_class.new(club).info

      expect(info[:plan]).to  eq('basico')
      expect(info[:label]).to eq('Hasta 50 pacientes')
      expect(info[:limites].keys).to match_array(described_class::RECURSOS)
      expect(info[:uso].keys).to     match_array(described_class::RECURSOS)
    end

    it 'un club con plan viejo se reporta ya normalizado' do
      club.update_columns(plan: 'federacion')

      expect(described_class.new(club.reload).info[:plan]).to eq('total')
    end
  end

  # El plan no decide capacidades: eso es de las suites. Un club Total sin suites no puede
  # hacer nada, y un club Básico con las dos suites puede hacer todo (poco, pero todo).
  describe 'el plan no toca los módulos' do
    it 'un club total sin suites no tiene ningún módulo' do
      total = create(:club, plan: 'total', features: {})

      expect(total.feature?(:bar)).to    be(false)
      expect(total.suite?(:cultivo)).to  be(false)
      expect(described_class.new(total).puede_crear_lote?).to be(true)
    end

    it 'un club básico con las dos suites tiene los módulos incluidos' do
      basico = create(:club, plan: 'basico',
                             features: { 'cultivo' => true, 'produccion_dispensa' => true })

      expect(basico.feature?(:medico)).to be(true)
    end

    # 6-oct-2026: lo terminado viene con los packs, sea cual sea el escalón.
    it 'delivery, correo e IA vienen con los packs en cualquier escalón' do
      %w[basico total].each do |plan|
        c = create(:club, plan: plan, features: { 'produccion_dispensa' => true })
        %i[delivery mailer ia medico].each { |m| expect(c.feature?(m)).to be(true), "#{plan}: #{m}" }
      end
      expect(create(:club, plan: 'total', features: { 'cultivo' => true }).feature?(:delivery)).to be(false)
    end
  end
end
