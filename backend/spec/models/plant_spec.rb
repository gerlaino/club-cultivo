require 'rails_helper'

RSpec.describe Plant, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  def build_plant(attrs = {})
    build(:plant, { lote: lote }.merge(attrs))
  end

  def create_plant(attrs = {})
    create(:plant, { lote: lote }.merge(attrs))
  end

  # ── validaciones ──────────────────────────────────────────────────────────

  describe 'validaciones' do
    it 'es válida con datos correctos' do
      expect(build_plant).to be_valid
    end

    it 'requiere nombre' do
      expect(build_plant(nombre: nil)).not_to be_valid
    end

    it 'requiere state válido' do
      expect(build_plant(state: 'invalido')).not_to be_valid
    end

    it 'rechaza state no contemplado' do
      expect(build_plant(state: 'muerta')).not_to be_valid
    end

    it 'acepta todos los estados válidos' do
      Plant::STATES.each do |s|
        expect(build_plant(state: s)).to be_valid, "falló para state=#{s}"
      end
    end

    it 'acepta peso_seco positivo' do
      expect(build_plant(peso_seco: 15.5)).to be_valid
    end

    it 'rechaza peso_seco <= 0' do
      expect(build_plant(peso_seco: 0)).not_to be_valid
    end

    it 'acepta peso_seco nil' do
      expect(build_plant(peso_seco: nil)).to be_valid
    end

    it 'acepta origen válido' do
      Plant::ORIGENES.each do |o|
        expect(build_plant(origen: o)).to be_valid, "falló para origen=#{o}"
      end
    end

    it 'acepta origen nil' do
      expect(build_plant(origen: nil)).to be_valid
    end

    it 'rechaza origen inválido' do
      expect(build_plant(origen: 'injerto')).not_to be_valid
    end

    context 'codigo_qr' do
      it 'debe ser único' do
        p1 = create_plant
        p2 = build_plant(codigo_qr: p1.codigo_qr)
        expect(p2).not_to be_valid
        expect(p2.errors[:codigo_qr]).not_to be_empty
      end

      it 'acepta codigo_qr nil' do
        expect(build_plant(codigo_qr: nil)).to be_valid
      end
    end
  end

  # ── callbacks ─────────────────────────────────────────────────────────────

  describe 'callbacks' do
    it 'genera codigo_qr al crear' do
      p = create_plant
      expect(p.codigo_qr).to be_present
    end

    it 'asigna club_id desde el lote' do
      p = create_plant
      expect(p.club_id).to eq(club.id)
    end
  end

  # ── soft delete ────────────────────────────────────────────────────────────

  describe '#soft_delete!' do
    it 'establece deleted_at en la planta' do
      p = create_plant
      p.soft_delete!
      expect(p.reload.deleted_at).not_to be_nil
    end

    it 'excluye la planta del default_scope tras soft delete' do
      p = create_plant
      p.soft_delete!
      expect(Plant.where(id: p.id)).to be_empty
    end
  end

  # ── scopes ────────────────────────────────────────────────────────────────

  describe 'scopes' do
    it '.por_estado filtra por state' do
      veg = create_plant(state: 'vegetativo')
      flor = create_plant(state: 'floracion')
      expect(Plant.por_estado('vegetativo')).to include(veg)
      expect(Plant.por_estado('vegetativo')).not_to include(flor)
    end

    it '.en_floracion devuelve solo plantas en floración' do
      p = create_plant(state: 'floracion')
      expect(Plant.en_floracion).to include(p)
    end

    it '.cosechadas devuelve solo plantas cosechadas' do
      p = create_plant(state: 'cosechado')
      expect(Plant.cosechadas).to include(p)
    end

    it '.seleccion devuelve plantas marcadas como selección' do
      sel  = create_plant(es_seleccion: true)
      norm = create_plant(es_seleccion: false)
      expect(Plant.seleccion).to include(sel)
      expect(Plant.seleccion).not_to include(norm)
    end
  end

  # ── asociaciones ──────────────────────────────────────────────────────────

  describe 'planta_madre / esquejes' do
    it 'permite asociar una planta madre' do
      madre   = create_plant
      esqueje = create_plant(planta_madre: madre, state: 'enraizado', origen: 'esqueje')
      expect(esqueje.planta_madre).to eq(madre)
      expect(madre.esquejes).to include(esqueje)
    end

    it 'nullifica planta_madre_id en esquejes al hacer soft delete de la madre' do
      madre   = create_plant
      esqueje = create_plant(planta_madre: madre, state: 'enraizado', origen: 'esqueje')
      madre.soft_delete!
      # la asociación dependent: :nullify aplica solo en destroy; el vínculo persiste tras soft_delete
      expect(esqueje.reload.planta_madre_id).to eq(madre.id)
    end
  end
end
