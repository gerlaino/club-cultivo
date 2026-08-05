require 'rails_helper'

RSpec.describe User, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def sede_con_sala(kind:)
    sede = create(:sede, club: club, created_by: admin)
    sala = create(:sala, club: club, sede: sede, created_by: admin, kind: kind)
    [sede, sala]
  end

  # ── salas_ids_asignadas ───────────────────────────────────────────────────────

  describe '#salas_ids_asignadas' do
    context 'cultivador' do
      let(:cultivador) { create(:user, :cultivador, club: club) }

      it 'retorna salas de kind cultivador en sedes asignadas' do
        sede, sala_veg = sede_con_sala(kind: 'vegetativo')
        cultivador.sedes_asignadas << sede
        expect(cultivador.salas_ids_asignadas).to include(sala_veg.id)
      end

      it 'no retorna salas de manicura aunque estén en la sede asignada' do
        sede, sala_man = sede_con_sala(kind: 'manicura')
        cultivador.sedes_asignadas << sede
        expect(cultivador.salas_ids_asignadas).not_to include(sala_man.id)
      end

      it 'no retorna salas de OTRAS sedes cuando tiene alguna asignada' do
        sede_propia, sala_propia = sede_con_sala(kind: 'vegetativo')
        _sede_ajena, sala_ajena  = sede_con_sala(kind: 'vegetativo')
        cultivador.sedes_asignadas << sede_propia

        ids = cultivador.salas_ids_asignadas

        expect(ids).to     include(sala_propia.id)
        expect(ids).not_to include(sala_ajena.id)
      end

      # Sin ninguna sede asignada el cultivador ve todo el cultivo del club. Es la regla que ya
      # aplicaban a mano salas#index, salas#set_sala, lotes#index y lotes#set_lote; faltaba en
      # plants#index y plants#kpis, y por eso se veían lotes pero ninguna planta.
      it 'sin sedes asignadas retorna todas las salas de cultivo del club' do
        _sede, sala_veg = sede_con_sala(kind: 'vegetativo')
        _sede2, sala_man = sede_con_sala(kind: 'manicura')

        ids = cultivador.salas_ids_asignadas

        expect(ids).to     include(sala_veg.id)
        expect(ids).not_to include(sala_man.id)
      end

      it 'retorna salas de todos los kinds permitidos' do
        sede = create(:sede, club: club, created_by: admin)
        cultivador.sedes_asignadas << sede
        salas = User::KINDS_CULTIVADOR.map do |kind|
          create(:sala, club: club, sede: sede, created_by: admin, kind: kind)
        end
        ids = cultivador.salas_ids_asignadas
        salas.each { |s| expect(ids).to include(s.id) }
      end
    end

    context 'manicura' do
      let(:manicurero) { create(:user, :manicura, club: club) }

      it 'retorna todas las salas de manicura del club sin importar sede' do
        _sede1, sala_man1 = sede_con_sala(kind: 'manicura')
        _sede2, sala_man2 = sede_con_sala(kind: 'manicura')
        ids = manicurero.salas_ids_asignadas
        expect(ids).to include(sala_man1.id, sala_man2.id)
      end

      it 'no retorna salas de other kinds' do
        _sede, sala_veg = sede_con_sala(kind: 'vegetativo')
        expect(manicurero.salas_ids_asignadas).not_to include(sala_veg.id)
      end

      it 'no retorna salas de manicura de otros clubs' do
        otro_club  = create(:club)
        otro_admin = create(:user, :admin, club: otro_club)
        sala_otro  = ActsAsTenant.with_tenant(otro_club) do
          otra_sede = create(:sede, club: otro_club, created_by: otro_admin)
          create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin, kind: 'manicura')
        end
        expect(manicurero.salas_ids_asignadas).not_to include(sala_otro.id)
      end
    end

    context 'admin' do
      it 'retorna las salas vía sala_cultivadores (vacío si no hay asignaciones)' do
        # Admin accede a todas las salas a nivel de autorización;
        # salas_ids_asignadas refleja sala_cultivadores que requiere rol cultivador/manicura
        expect(admin.salas_ids_asignadas).to eq([])
      end
    end

    context 'supervisor' do
      it 'retorna las salas vía sala_cultivadores (vacío si no hay asignaciones)' do
        supervisor = create(:user, role: 'supervisor', club: club)
        expect(supervisor.salas_ids_asignadas).to eq([])
      end
    end
  end

  # ── Validaciones ──────────────────────────────────────────────────────────────

  describe 'validaciones' do
    it 'requiere club para roles no super_admin' do
      user = build(:user, :cultivador, club: nil)
      expect(user).not_to be_valid
      expect(user.errors[:club]).to be_present
    end

    it 'no requiere club para super_admin' do
      user = build(:user, :super_admin)
      user.club = nil
      user.club_id = nil
      expect(user).to be_valid
    end

    it 'requiere email único' do
      create(:user, :admin, club: club, email: 'dup@test.com')
      expect(build(:user, :admin, club: club, email: 'dup@test.com')).not_to be_valid
    end
  end
end
