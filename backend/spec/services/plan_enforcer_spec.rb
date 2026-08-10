require 'rails_helper'

# AC del modelo comercial (ago-2026): DOS planes, y el plan dice CUÁNTO, nunca QUÉ.
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

  describe 'los dos planes' do
    it 'sólo existen básico y total' do
      expect(described_class::PLANES.keys).to contain_exactly('basico', 'total')
    end

    it 'el total no limita nada' do
      described_class::RECURSOS.each do |recurso|
        expect(described_class::PLANES['total'][recurso]).to be_nil,
                                                             "el plan total no debería limitar #{recurso}"
      end
    end

    it 'el básico limita los seis recursos' do
      described_class::RECURSOS.each do |recurso|
        expect(described_class::PLANES['basico'][recurso]).to be_a(Integer),
                                                              "el plan básico debería limitar #{recurso}"
      end
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

  describe 'plan total' do
    let(:club) { create(:club, plan: 'total') }

    it 'no frena nada' do
      admin = create(:user, :admin, club: club)
      10.times { create(:sala, club: club, created_by: admin) }
      create(:sede, club: club, created_by: admin)

      enforcer = described_class.new(club.reload)

      expect(enforcer.puede_crear_sala?).to     be(true)
      expect(enforcer.puede_crear_sede?).to     be(true)
      expect(enforcer.puede_crear_lote?).to     be(true)
      expect(enforcer.puede_crear_planta?).to   be(true)
      expect(enforcer.puede_crear_paciente?).to be(true)
      expect(enforcer.puede_crear_usuario?).to  be(true)
    end
  end

  # El caso que motivó volver a limitar las plantas: dos lotes de mil plantas es un club que
  # tendría que estar pagando el plan Total, y con el límite sólo en lotes pasaba por básico.
  describe 'límite de plantas' do
    it 'frena la carga masiva que excede el tope aunque entre en los lotes permitidos' do
      tope = described_class::PLANES['basico'][:plantas]

      expect(described_class.new(club).puede_crear_planta_bulk?(tope + 1)).to be(false)
      expect(described_class.new(club).puede_crear_planta_bulk?(tope)).to     be(true)
    end
  end

  describe '#info' do
    it 'informa los seis límites y el uso de cada uno' do
      info = described_class.new(club).info

      expect(info[:plan]).to  eq('basico')
      expect(info[:label]).to eq('Básico')
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
      expect(basico.feature?(:mailer)).to be(true)
    end
  end
end
