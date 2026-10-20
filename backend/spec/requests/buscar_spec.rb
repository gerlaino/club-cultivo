require 'rails_helper'

# AC (Germán, 12-oct-2026): sale la lista de todas las plantas; arriba hay un buscador general
# para llegar a UNA planta (y a su ficha). Cada rol encuentra lo que ya ve en sus pantallas.
RSpec.describe 'Buscador general', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)
  def buscar(q) = get('/buscar', params: { q: q }, headers: auth_headers)
  def titulos(seccion) = (json.dig('resultados', seccion) || []).map { |r| r['titulo'] }

  let(:club)  { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { ActsAsTenant.with_tenant(club) { create(:sala, club: club, created_by: admin, nombre: 'Flora grande') } }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala, codigo: 'L-26-043') } }
  let!(:planta) do
    ActsAsTenant.with_tenant(club) { create(:plant, lote: lote, club: club, nombre: 'Madre Gorilla', codigo_qr: 'QR-ABC-77') }
  end

  it 'encuentra una planta por su nombre y lleva a su ficha' do
    sign_in_as(admin)
    buscar('gorilla')

    expect(titulos('plantas')).to eq(['Madre Gorilla'])
    expect(json.dig('resultados', 'plantas', 0, 'ruta')).to eq("/plantas/#{planta.id}")
  end

  it 'la encuentra también por su código QR' do
    sign_in_as(admin)
    buscar('abc-77')

    expect(titulos('plantas')).to eq(['Madre Gorilla'])
  end

  it 'encuentra el lote por su código' do
    sign_in_as(admin)
    buscar('26-043')

    expect(titulos('lotes')).to eq(['L-26-043'])
  end

  it 'no trae nada de otra organización' do
    otro       = create(:club, features: { 'cultivo' => true })
    otro_admin = create(:user, :admin, club: otro)
    ActsAsTenant.with_tenant(otro) do
      s = create(:sala, club: otro, created_by: otro_admin)
      create(:plant, lote: create(:lote, club: otro, sala: s), club: otro, nombre: 'Gorilla ajena')
    end
    sign_in_as(admin)
    buscar('gorilla')

    expect(titulos('plantas')).to eq(['Madre Gorilla'])
  end

  # AC (Germán, 20-oct-2026): el buscador llega al teléfono; el cultivador encuentra lo que ve en
  # su pantalla y nada más. Con dos sedes y él asignado a una sola, la planta de la otra no viene.
  it 'el cultivador asignado a una sede no encuentra las plantas de la otra' do
    cultivador = create(:user, :cultivador, club: club)
    ActsAsTenant.with_tenant(club) do
      finca = create(:sede, club: club, created_by: admin, nombre: 'Finca')
      otra  = create(:sede, club: club, created_by: admin, nombre: 'Galpón')
      sala.update!(sede: finca)
      sala_otra = create(:sala, club: club, created_by: admin, sede: otra, nombre: 'Flora chica')
      create(:plant, lote: create(:lote, club: club, sala: sala_otra), club: club, nombre: 'Gorilla del galpón')
      UserSede.create!(user: cultivador, sede: finca)
    end
    sign_in_as(cultivador)
    buscar('gorilla')

    expect(titulos('plantas')).to eq(['Madre Gorilla'])

    buscar('flora')
    expect(titulos('salas')).to eq(['Flora grande'])
  end

  it 'con menos de dos letras no busca' do
    sign_in_as(admin)
    buscar('g')

    expect(json['resultados']).to eq({})
  end

  describe 'pacientes' do
    let!(:vinculado) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, nombre: 'Ana', apellido: 'Gorostiza') } }
    let!(:ajeno)     { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, nombre: 'Beto', apellido: 'Gorostiaga') } }

    it 'el admin los encuentra por apellido' do
      sign_in_as(admin)
      buscar('goros')

      expect(titulos('pacientes')).to contain_exactly('Gorostiza, Ana', 'Gorostiaga, Beto')
    end

    it 'el médico encuentra SÓLO a sus pacientes vinculados' do
      medico = create(:user, :medico, club: club)
      ActsAsTenant.with_tenant(club) do
        vinculado.update!(con_seguimiento_medico: true)
        ajeno.update!(con_seguimiento_medico: true)
        MedicoPaciente.create!(club: club, medico: medico, paciente: vinculado)
      end
      sign_in_as(medico)
      buscar('goros')

      expect(titulos('pacientes')).to eq(['Gorostiza, Ana'])
      expect(json['resultados']).not_to have_key('plantas')
    end

    it 'el cultivador no busca pacientes' do
      sign_in_as(create(:user, :cultivador, club: club))
      buscar('goros')

      expect(json['resultados']).not_to have_key('pacientes')
    end
  end

  it 'el dispensador no busca en el cultivo' do
    sign_in_as(create(:user, :dispensador, club: club))
    buscar('gorilla')

    expect(json['resultados']).not_to have_key('plantas')
    expect(json['resultados']).not_to have_key('lotes')
  end
end
