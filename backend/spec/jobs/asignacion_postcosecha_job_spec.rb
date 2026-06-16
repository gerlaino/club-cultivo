require 'rails_helper'

RSpec.describe AsignacionPostcosechaJob do
  # Crea un lote en 'cosecha' con el evento de entrada a cosecha datado `dias` atrás.
  def lote_cosechado(club, sala, registrado_por, dias:)
    lote = create(:lote, club: club, sala: sala, estado: 'cosecha')
    lote.lote_eventos.create!(
      tipo:          'cambio_estado',
      estado_nuevo:  'cosecha',
      registrado_en: dias.days.ago,
      user:          registrado_por,
      club:          club
    )
    lote
  end

  let(:club)  { create(:club, alertas_config: config) }
  let!(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club, created_by: admin, kind: 'floracion') }

  context 'cuando la feature está desactivada (postcosecha_dias 0 o ausente)' do
    let(:config) { {} }

    it 'no hace nada' do
      lote_cosechado(club, sala, admin, dias: 30)
      expect { described_class.new.perform }.not_to change(AlertaInterna, :count)
    end
  end

  context 'modo avisar' do
    let(:config) { { 'postcosecha_dias' => 7, 'postcosecha_modo' => 'avisar' } }

    it 'avisa al admin cuando el lote supera los días de gracia' do
      lote = lote_cosechado(club, sala, admin, dias: 10)

      expect { described_class.new.perform }.to change(AlertaInterna, :count).by(1)

      alerta = AlertaInterna.last
      expect(alerta.tipo).to eq('cosecha_pendiente')
      expect(alerta.destinada_a_role).to eq('admin')
      expect(alerta.lote_id).to eq(lote.id)
      expect(lote.reload.estado).to eq('cosecha') # no lo mueve, sólo avisa
    end

    it 'no avisa si todavía no superó los días de gracia' do
      lote_cosechado(club, sala, admin, dias: 3)
      expect { described_class.new.perform }.not_to change(AlertaInterna, :count)
    end

    it 'es idempotente: no duplica la alerta el mismo día' do
      lote_cosechado(club, sala, admin, dias: 10)
      described_class.new.perform
      expect { described_class.new.perform }.not_to change(AlertaInterna, :count)
    end
  end

  context 'modo asignar_automatico' do
    let(:config) { { 'postcosecha_dias' => 7, 'postcosecha_modo' => 'asignar_automatico' } }

    context 'con un único manicura' do
      let!(:manicura) { create(:user, :manicura, club: club) }

      it 'mueve el lote a en_manicura y le crea una tarea asignada' do
        lote = lote_cosechado(club, sala, admin, dias: 10)

        described_class.new.perform

        lote.reload
        expect(lote.estado).to eq('en_manicura')
        expect(lote.manicurador_id).to eq(manicura.id)

        tarea = Tarea.find_by(lote_id: lote.id, asignada_a_id: manicura.id)
        expect(tarea).to be_present
        expect(tarea.estado).to eq('pendiente')
      end

      it 'es idempotente: el lote ya no está en cosecha, no se reprocesa' do
        lote_cosechado(club, sala, admin, dias: 10)
        described_class.new.perform
        expect { described_class.new.perform }.not_to change(Tarea, :count)
      end
    end

    context 'con varios manicuras y sin default' do
      before do
        create(:user, :manicura, club: club)
        create(:user, :manicura, club: club)
      end

      it 'no asigna y pide elección al admin' do
        lote = lote_cosechado(club, sala, admin, dias: 10)

        described_class.new.perform

        expect(lote.reload.estado).to eq('cosecha')
        alerta = AlertaInterna.where(lote_id: lote.id).last
        expect(alerta.contexto['accion']).to eq('postcosecha_elegir_manicura')
      end
    end

    context 'con varios manicuras y un default configurado' do
      it 'asigna al manicura default' do
        create(:user, :manicura, club: club)
        m2 = create(:user, :manicura, club: club)
        club.update!(alertas_config: config.merge('postcosecha_manicura_default_id' => m2.id))

        lote = lote_cosechado(club, sala, admin, dias: 10)
        described_class.new.perform
        expect(lote.reload.manicurador_id).to eq(m2.id)
      end
    end

    context 'sin manicuras' do
      let!(:supervisor) { create(:user, club: club, role: 'supervisor') }

      it 'asigna al supervisor' do
        lote = lote_cosechado(club, sala, admin, dias: 10)
        described_class.new.perform
        expect(lote.reload.manicurador_id).to eq(supervisor.id)
      end
    end
  end
end
