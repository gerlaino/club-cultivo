require 'rails_helper'

# AC: el cultivador ve las PLANTAS de los mismos lotes que ve en su lista de lotes.
# El bug era la asimetría: lotes#index tenía fallback cuando no hay sedes asignadas y
# plants#index no, así que se veían lotes y cero plantas.
RSpec.describe 'Visibilidad de plantas del cultivador', type: :request do
  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:sede)       { create(:sede, club: club, created_by: admin) }
  let(:sala)       { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }

  def crear_lote(estado: 'floracion', sala_del_lote: sala, sede_del_lote: nil)
    lote = create(:lote, club: club, sala: sala_del_lote, estado: estado)
    lote.update_columns(sala_id: sala_del_lote&.id, sede_id: sede_del_lote&.id) if sala_del_lote.nil?
    lote
  end

  def crear_planta(lote, state: 'floracion')
    Plant.create!(lote: lote, club: club, nombre: "P-#{SecureRandom.hex(3)}", state: state)
  end

  describe 'cultivador SIN sedes asignadas' do
    it 've las plantas de los lotes que también le aparecen en la lista' do
      lote = crear_lote
      crear_planta(lote)
      sign_in_as(cultivador)

      get '/api/lotes'
      expect(JSON.parse(response.body).size).to eq(1), 'precondición: debería ver el lote'

      get '/api/plants'
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it 'cuenta esas plantas en los KPIs' do
      lote = crear_lote
      crear_planta(lote)
      sign_in_as(cultivador)

      get '/api/plants/kpis'

      expect(JSON.parse(response.body)['activas']).to eq(1)
    end
  end

  describe 'lotes post-cosecha' do
    # Al cosechar, avanzar_fase! deja sala_id = nil y conserva la sede. Filtrando sólo por sala,
    # esas plantas desaparecían para el cultivador aunque él mismo las hubiera cosechado.
    it 've las plantas de un lote ya cosechado, que no tiene sala' do
      lote = create(:lote, club: club, sala: sala, estado: 'floracion')
      crear_planta(lote, state: 'cosechado')
      lote.update_columns(estado: 'cosecha', sala_id: nil, sede_id: sede.id)
      sign_in_as(cultivador)

      get '/api/plants'

      expect(JSON.parse(response.body).size).to eq(1)
    end

    it 'las cuenta como cosechadas en los KPIs' do
      lote = create(:lote, club: club, sala: sala, estado: 'floracion')
      crear_planta(lote, state: 'cosechado')
      lote.update_columns(estado: 'cosecha', sala_id: nil, sede_id: sede.id)
      sign_in_as(cultivador)

      get '/api/plants/kpis'

      expect(JSON.parse(response.body)['cosechadas']).to eq(1)
    end
  end

  describe 'cultivador CON sedes asignadas' do
    it 'no ve plantas de lotes de otra sede' do
      sede_ajena = create(:sede, club: club, created_by: admin)
      sala_ajena = create(:sala, club: club, sede: sede_ajena, created_by: admin, kind: 'floracion')
      crear_planta(crear_lote(sala_del_lote: sala_ajena))

      propia = crear_planta(crear_lote)
      cultivador.sedes_asignadas << sede
      sign_in_as(cultivador)

      get '/api/plants'

      ids = JSON.parse(response.body).map { |p| p['id'] }
      expect(ids).to eq([propia.id])
    end
  end

  describe 'aislamiento de tenant' do
    it 'no ve plantas de otro club' do
      crear_planta(crear_lote)
      otro_club = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      ActsAsTenant.with_tenant(otro_club) do
        otra_sede = create(:sede, club: otro_club, created_by: otro_admin)
        otra_sala = create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin, kind: 'floracion')
        otro_lote = create(:lote, club: otro_club, sala: otra_sala, estado: 'floracion')
        Plant.create!(lote: otro_lote, club: otro_club, nombre: 'Ajena', state: 'floracion')
      end
      sign_in_as(cultivador)

      get '/api/plants'

      expect(JSON.parse(response.body).size).to eq(1)
    end
  end
end
