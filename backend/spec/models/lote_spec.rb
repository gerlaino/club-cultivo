require 'rails_helper'

RSpec.describe Lote, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  def new_lote(attrs = {})
    build(:lote, club: club, sala: sala, **attrs)
  end

  def create_lote(attrs = {})
    create(:lote, club: club, sala: sala, **attrs)
  end

  # ── Validaciones ──────────────────────────────────────────────────────────────

  describe 'fase inicial y avance enraizado → vegetativo → floración' do
    # El origen ya NO define la fase inicial: los dos arrancan enraizando. Es el punto del colapso
    # —una plántula sin raíz y un esqueje sin raíz están en el mismo lugar—, y de dónde viene la
    # planta se guarda aparte, en `origen`.
    it 'estado_inicial_para_origen: venga de donde venga, arranca enraizando' do
      expect(create_lote(origen: 'semilla').estado_inicial_para_origen).to eq('enraizado')
      expect(create_lote(origen: 'esqueje').estado_inicial_para_origen).to eq('enraizado')
    end

    it "avanzar_fase! sigue la secuencia enraizado → vegetativo → floración" do
      lote = create_lote(estado: 'enraizado')
      lote.avanzar_fase!(tamanio_maceta: 3)   # al prender va a maceta: el dato es obligatorio
      expect(lote.reload.estado).to eq('vegetativo')
      lote.avanzar_fase!
      expect(lote.reload.estado).to eq('floracion')
    end

    # El origen es un eje aparte del estado: los dos arrancan enraizando.
    it 'un lote de semilla y uno de esqueje arrancan los dos en enraizado' do
      expect(create_lote(origen: 'semilla', estado: 'enraizado')).to be_valid
      expect(create_lote(origen: 'esqueje', estado: 'enraizado')).to be_valid
    end

    it "germinacion y esqueje ya no son estados de lote" do
      expect(Lote::ESTADOS).not_to include('germinacion', 'esqueje')
      expect(Lote::FASE_A_PLANT_STATE['enraizado']).to eq('enraizado')
    end

    it "'semilla' ya no es un estado válido de lote" do
      expect(new_lote(estado: 'semilla')).not_to be_valid
    end
  end

  describe 'validaciones' do
    it 'es válido con atributos mínimos' do
      expect(new_lote).to be_valid
    end

    it 'requiere start_date' do
      expect(new_lote(start_date: nil)).not_to be_valid
    end

    it 'requiere estado dentro de ESTADOS' do
      expect(new_lote(estado: 'inventado')).not_to be_valid
    end

    it 'acepta todos los estados definidos' do
      Lote::ESTADOS.each do |estado|
        expect(new_lote(estado: estado)).to be_valid
      end
    end

    it 'no permite plants_count negativo' do
      expect(new_lote(plants_count: -1)).not_to be_valid
    end

    it 'no permite tamanio_maceta <= 0' do
      expect(new_lote(tamanio_maceta: 0)).not_to be_valid
    end

    it 'permite tamanio_maceta nil' do
      expect(new_lote(tamanio_maceta: nil)).to be_valid
    end

    context 'unicidad de código por club' do
      it 'no permite el mismo código en el mismo club' do
        create_lote(codigo: 'LOTE-UNICO')
        expect(new_lote(codigo: 'LOTE-UNICO')).not_to be_valid
      end

      it 'permite el mismo código en clubs distintos' do
        otro_club = create(:club)
        otro_admin = create(:user, :admin, club: otro_club)
        ActsAsTenant.with_tenant(otro_club) do
          otra_sede  = create(:sede, club: otro_club, created_by: otro_admin)
          otra_sala  = create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin)
          create(:lote, club: otro_club, sala: otra_sala, codigo: 'LOTE-UNICO')
        end
        expect(new_lote(codigo: 'LOTE-UNICO')).to be_valid
      end

      it 'ignora lotes eliminados al validar unicidad' do
        lote = create_lote(codigo: 'LOTE-BORRADO')
        lote.soft_delete!
        expect(new_lote(codigo: 'LOTE-BORRADO')).to be_valid
      end
    end
  end

  # ── Soft delete ───────────────────────────────────────────────────────────────

  describe '#soft_delete!' do
    it 'asigna deleted_at' do
      lote = create_lote
      expect { lote.soft_delete! }.to change { lote.reload.deleted_at }.from(nil)
    end

    it 'queda excluido de la scope por defecto' do
      lote = create_lote
      lote.soft_delete!
      expect(Lote.where(id: lote.id)).to be_empty
    end

    it 'se puede recuperar con unscoped' do
      lote = create_lote
      lote.soft_delete!
      expect(Lote.unscoped.where(id: lote.id)).to exist
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────────

  describe 'scopes' do
    describe '.activos' do
      it 'excluye lotes finalizados' do
        activo     = create_lote(estado: 'vegetativo')
        finalizado = create_lote(estado: 'finalizado')
        result = Lote.activos
        expect(result).to include(activo)
        expect(result).not_to include(finalizado)
      end
    end

    describe '.en_ciclo' do
      it 'incluye estados de CICLO_FASES y finalizado' do
        (Lote::CICLO_FASES + ['finalizado']).each do |estado|
          lote = create_lote(estado: estado)
          expect(Lote.en_ciclo).to include(lote)
        end
      end

      it 'excluye estados previos al ciclo' do
        lote = create_lote(estado: 'enraizado')
        expect(Lote.en_ciclo).not_to include(lote)
      end
    end

    describe '.por_sala' do
      it 'filtra por sala_id' do
        otra_sala = create(:sala, club: club, sede: sede, created_by: admin)
        lote_en_sala       = create_lote(sala: sala)
        lote_en_otra_sala  = create_lote(sala: otra_sala)
        expect(Lote.por_sala(sala.id)).to     include(lote_en_sala)
        expect(Lote.por_sala(sala.id)).not_to include(lote_en_otra_sala)
      end
    end

    describe '.finalizados' do
      it 'incluye solo finalizados' do
        fin  = create_lote(estado: 'finalizado')
        veg  = create_lote(estado: 'vegetativo')
        expect(Lote.finalizados).to     include(fin)
        expect(Lote.finalizados).not_to include(veg)
      end
    end
  end

  # ── Métodos de instancia ──────────────────────────────────────────────────────

  describe '#dias_desde_inicio' do
    it 'retorna 0 cuando no hay start_date' do
      lote = new_lote(start_date: nil)
      lote.valid? # skip validation for this test
      lote.start_date = nil
      expect(lote.dias_desde_inicio).to eq(0)
    end

    it 'retorna la diferencia de días desde start_date' do
      lote = create_lote(start_date: Date.today - 10)
      expect(lote.dias_desde_inicio).to eq(10)
    end
  end

  describe '#progreso_ciclo' do
    {
      'semilla'           => 0,
      'enraizado'         => 0,
      'vegetativo'        => 20,
      'floracion'         => 40,
      'cosecha'           => 60,
      'en_manicura'       => 72,
      'curado'            => 92,
      'finalizado'        => 100,
    }.each do |estado, pct|
      it "retorna #{pct} para estado '#{estado}'" do
        lote = new_lote(estado: estado)
        expect(lote.progreso_ciclo).to eq(pct)
      end
    end
  end
end
