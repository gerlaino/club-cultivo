require 'rails_helper'

# AC (11-oct-2026, Germán aprobó el plan): en autocultivo hay UN gesto para florar. Con una sola
# carpa, la floración es cambiar la luz del espacio: la ficha de las plantas ofrece «Pasar <espacio>
# a floración» (`avanza_con_el_espacio`), no un «Avanzar a Floración» que pide mudar las plantas a
# un espacio que no existe. Con una carpa de vege y otra de flora, se mudan como siempre. Una
# organización no cambia.
RSpec.describe 'Autocultivo: florar es cambiar la luz', type: :request do
  def json = JSON.parse(response.body)

  def ficha(club, sala_kind:, otra_kind: nil)
    admin = create(:user, :admin, club: club)
    ActsAsTenant.with_tenant(club) do
      sede = create(:sede, club: club, created_by: admin)
      sala = create(:sala, club: club, sede: sede, kind: sala_kind, created_by: admin)
      create(:sala, club: club, sede: sede, kind: otra_kind, created_by: admin) if otra_kind
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 1, tamanio_maceta: 10)
      sign_in_as(admin)
      get "/lotes/#{lote.id}"
    end
    json
  end

  it 'con una sola carpa (vege), las plantas florecen con el espacio' do
    club = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
    expect(ficha(club, sala_kind: 'vegetativo')['avanza_con_el_espacio']).to be(true)
  end

  it 'con una carpa de floración aparte, se mudan: no se da vuelta la de vege' do
    club = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
    expect(ficha(club, sala_kind: 'vegetativo', otra_kind: 'floracion')['avanza_con_el_espacio']).to be(false)
  end

  it 'en una organización con una sola sala de vege, sigue siendo mudar el lote' do
    club = create(:club, plan: 'basico', features: { 'cultivo' => true })
    expect(ficha(club, sala_kind: 'vegetativo')['avanza_con_el_espacio']).to be(false)
  end
end
