require 'rails_helper'

# AC: cuando alguien dicta "regué", el sistema NO decide solo qué tareas dar por hechas. Propone
# las candidatas, la persona confirma en la pantalla de revisión, y recién ahí se cierran.
#
# El bug que motiva esto: `cerrar_por_registro!` cerraba en tanda y DESPUÉS de guardar todas las
# tareas del tipo dictado. Con tres riegos pendientes se cerraban los tres, y quien dictó se
# enteraba por una línea de texto con el hecho consumado. Deshacerlo era ir a Tareas y reabrirlas
# de a una. Para admin y supervisor cerraba además las de otra gente.
RSpec.describe Tarea, 'cierre por dictado' do
  let(:club)       { create(:club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:sala)       { create(:sala, club: club) }
  let(:lote)       { create(:lote, club: club, sala: sala) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def tarea!(tipo:, asignada_a: cultivador, estado: 'pendiente', a_lote: lote)
    Tarea.create!(club: club, creada_por: admin, asignada_a: asignada_a, lote: a_lote,
                  titulo: "#{tipo} de #{a_lote&.codigo}", tipo: tipo, estado: estado,
                  prioridad: 'normal')
  end

  def candidatas(realizadas, usuario: cultivador, privilegiado: false)
    described_class.candidatas_por_registro(
      tareas_realizadas: realizadas, usuario: usuario,
      es_privilegiado: privilegiado, lote: lote
    )
  end

  describe '.candidatas_por_registro' do
    it 'propone las tareas del tipo dictado SIN cerrarlas' do
      t = tarea!(tipo: 'riego')

      expect(candidatas(['riego'])).to include(t)
      # Lo importante: sigue abierta hasta que alguien confirme.
      expect(t.reload.estado).to eq('pendiente')
    end

    it 'no propone tareas de otro tipo' do
      tarea!(tipo: 'poda')

      expect(candidatas(['riego'])).to be_empty
    end

    it 'al cultivador sólo le propone las suyas' do
      otro = create(:user, :cultivador, club: club)
      mia  = tarea!(tipo: 'riego')
      tarea!(tipo: 'riego', asignada_a: otro)

      expect(candidatas(['riego'])).to contain_exactly(mia)
    end

    it 'al admin le propone también las de otra gente, porque puede cerrarlas' do
      otro    = create(:user, :cultivador, club: club)
      del_otro = tarea!(tipo: 'riego', asignada_a: otro)

      expect(candidatas(['riego'], usuario: admin, privilegiado: true)).to include(del_otro)
    end

    it 'no propone las que ya estaban completadas' do
      tarea!(tipo: 'riego', estado: 'completada')

      expect(candidatas(['riego'])).to be_empty
    end
  end

  describe '.cerrar_confirmadas!' do
    it 'cierra SÓLO las confirmadas, no todas las candidatas' do
      # El caso que motiva el cambio entero: tres riegos pendientes, se regó uno.
      uno, dos, tres = 3.times.map { tarea!(tipo: 'riego') }

      described_class.cerrar_confirmadas!(ids: [uno.id], usuario: cultivador,
                                          es_privilegiado: false, club: club)

      expect(uno.reload.estado).to eq('completada')
      expect(dos.reload.estado).to eq('pendiente')
      expect(tres.reload.estado).to eq('pendiente')
    end

    it 'sin ids confirmados no cierra nada' do
      t = tarea!(tipo: 'riego')

      described_class.cerrar_confirmadas!(ids: [], usuario: cultivador,
                                          es_privilegiado: false, club: club)

      expect(t.reload.estado).to eq('pendiente')
    end

    it 'un cultivador no cierra la tarea de otro aunque mande el id' do
      # La lista la arma el backend, pero lo que llega es un POST: el permiso se revalida acá y
      # no alcanza con que la pantalla no lo haya ofrecido.
      otro     = create(:user, :cultivador, club: club)
      del_otro = tarea!(tipo: 'riego', asignada_a: otro)

      described_class.cerrar_confirmadas!(ids: [del_otro.id], usuario: cultivador,
                                          es_privilegiado: false, club: club)

      expect(del_otro.reload.estado).to eq('pendiente')
    end

    it 'no cierra una tarea de OTRA organización' do
      otro_club = create(:club)
      ajena = ActsAsTenant.with_tenant(otro_club) do
        Tarea.create!(club: otro_club, creada_por: create(:user, :admin, club: otro_club),
                      titulo: 'riego ajeno', tipo: 'riego', estado: 'pendiente', prioridad: 'normal')
      end

      described_class.cerrar_confirmadas!(ids: [ajena.id], usuario: admin,
                                          es_privilegiado: true, club: club)

      expect(ajena.reload.estado).to eq('pendiente')
    end

    it 'devuelve los títulos de lo que cerró, para poder decirlo' do
      t = tarea!(tipo: 'riego')

      cerradas = described_class.cerrar_confirmadas!(ids: [t.id], usuario: cultivador,
                                                     es_privilegiado: false, club: club)

      expect(cerradas).to eq([t.titulo])
    end
  end
end
