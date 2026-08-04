require 'rails_helper'

# SIN ASIGNACIÓN = VE TODO. Asignar sedes es un recorte OPCIONAL: un club chico no asigna nada y su
# cultivador tiene que ver el club entero. Antes, cultivador y supervisor sin sedes recibían una
# lista vacía y la app decía "Sin sedes asignadas" — parecía un problema de permisos cuando en
# realidad nadie había recortado nada.
RSpec.describe 'GET /sedes — sin sedes asignadas', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let!(:produccion) do
    ActsAsTenant.with_tenant(club) { create(:sede, club: club, created_by: admin, nombre: 'Finca', tipo: 'produccion') }
  end
  let!(:social) do
    ActsAsTenant.with_tenant(club) { create(:sede, club: club, created_by: admin, nombre: 'Salón', tipo: 'social') }
  end

  def nombres
    get '/api/sedes'
    JSON.parse(response.body).map { |s| s['nombre'] }
  end

  %w[cultivador supervisor].each do |rol|
    it "el #{rol} sin asignación ve todas las sedes" do
      sign_in_as(create(:user, club: club, role: rol))
      expect(nombres).to match_array(%w[Finca Salón])
    end
  end

  it 'pero si tiene una asignada, ve solo esa' do
    cultivador = create(:user, club: club, role: 'cultivador')
    ActsAsTenant.with_tenant(club) { cultivador.sedes_asignadas << produccion }

    sign_in_as(cultivador)
    expect(nombres).to eq(['Finca'])
  end

  # El dispensador ya tenía el fallback, pero acotado a donde se dispensa.
  it 'el dispensador sin asignación ve las sedes sociales/mixtas' do
    sign_in_as(create(:user, club: club, role: 'dispensador'))
    expect(nombres).to eq(['Salón'])
  end
end
