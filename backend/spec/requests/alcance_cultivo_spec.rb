require 'rails_helper'

# AC (Germán, 20-oct-2026): «tiene que estar realmente bien hecho». Lo que una pantalla le muestra
# a alguien, la ficha se lo abre; y lo que no le corresponde no se abre por NINGÚN camino (lista,
# ficha, buscador, plantas, QR, fotos, riegos, eventos). Una sola regla: `Lote.al_alcance_de`.
RSpec.describe 'Alcance del cultivo: una sola regla para todo', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:finca) { create(:sede, club: club, created_by: admin, nombre: 'Finca') }
  let(:galpon) { create(:sede, club: club, created_by: admin, nombre: 'Galpón') }
  let(:sala_finca)  { ActsAsTenant.with_tenant(club) { create(:sala, club: club, created_by: admin, sede: finca) } }
  let(:sala_galpon) { ActsAsTenant.with_tenant(club) { create(:sala, club: club, created_by: admin, sede: galpon) } }
  let(:lote_mio)   { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala_finca, sede: finca) } }
  let(:lote_ajeno) { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala_galpon, sede: galpon) } }
  let!(:planta_mia)   { ActsAsTenant.with_tenant(club) { create(:plant, lote: lote_mio, club: club, nombre: 'Gorilla finca', codigo_qr: 'QR-FINCA') } }
  let!(:planta_ajena) { ActsAsTenant.with_tenant(club) { create(:plant, lote: lote_ajeno, club: club, nombre: 'Gorilla galpón', codigo_qr: 'QR-GALPON') } }
  let(:cultivador) { create(:user, :cultivador, club: club).tap { |u| UserSede.create!(user: u, sede: finca) } }

  def ids_buscados(q, seccion)
    get '/buscar', params: { q: q }, headers: auth_headers
    (json.dig('resultados', seccion) || []).map { |r| r['id'] }
  end

  context 'cultivador asignado a una sede' do
    before { sign_in_as(cultivador) }

    it 'abre la ficha y las plantas de lo suyo' do
      get "/lotes/#{lote_mio.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      get "/plants/#{planta_mia.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it 'lo de la otra sede no se abre por ningún camino' do
      [
        "/lotes/#{lote_ajeno.id}",
        "/lotes/#{lote_ajeno.id}/historial",
        "/lotes/#{lote_ajeno.id}/fotos",
        "/lotes/#{lote_ajeno.id}/registros_ambientales",
        "/lotes/#{lote_ajeno.id}/lote_eventos",
        "/plants/#{planta_ajena.id}",
        '/plants/por_qr/QR-GALPON',
      ].each do |ruta|
        get ruta, headers: auth_headers
        expect(response).to have_http_status(:not_found), "#{ruta} respondió #{response.status}"
      end

      post "/lotes/#{lote_ajeno.id}/registros_ambientales", params: { registro_ambiental: { temperatura: 24 } }, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'la lista de plantas pedida por lote no trae las de un lote ajeno' do
      get '/plants', params: { lote_id: lote_ajeno.id }, headers: auth_headers
      expect(json).to eq([])
    end

    it 'el buscador no muestra lo ajeno' do
      expect(ids_buscados('gorilla', 'plantas')).to eq([planta_mia.id])
    end
  end

  # El caso que destapó el buscador: un lote cosechado suelta la sala y se queda con la sede. La
  # lista y el buscador lo alcanzaban; la ficha tenía otra regla y daba 404.
  context 'un lote cosechado de su sede, sin sala' do
    before do
      ActsAsTenant.with_tenant(club) { lote_mio.update_columns(estado: 'curado', sala_id: nil) }
      sign_in_as(cultivador)
    end

    it 'lo que el buscador muestra, la ficha lo abre' do
      expect(ids_buscados('finca', 'plantas')).to eq([planta_mia.id])

      get "/lotes/#{lote_mio.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  context 'manicura' do
    let(:manicura) { create(:user, :manicura, club: club) }

    before do
      ActsAsTenant.with_tenant(club) { lote_mio.update_columns(estado: 'en_manicura', sala_id: nil, manicurador_id: manicura.id) }
      sign_in_as(manicura)
    end

    it 'encuentra y abre sólo el lote que le asignaron' do
      expect(ids_buscados('gorilla', 'plantas')).to eq([planta_mia.id])

      get "/lotes/#{lote_mio.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      get "/plants/#{planta_ajena.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'el admin alcanza todo lo de su organización y nada de otra' do
    otro = create(:club, features: { 'cultivo' => true })
    otro_admin = create(:user, :admin, club: otro)
    ajena = ActsAsTenant.with_tenant(otro) do
      create(:plant, lote: create(:lote, club: otro, sala: create(:sala, club: otro, created_by: otro_admin)), club: otro, nombre: 'Gorilla de otra org')
    end
    sign_in_as(admin)

    expect(ids_buscados('gorilla', 'plantas')).to contain_exactly(planta_mia.id, planta_ajena.id)
    get "/plants/#{ajena.id}", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
