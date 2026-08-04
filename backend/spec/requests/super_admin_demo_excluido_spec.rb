require 'rails_helper'

# Un club demo (el Club Modelo, una copia de prueba) tiene cientos de pacientes y dispensaciones
# INVENTADOS. Si entran en las métricas de plataforma, todo aparece inflado; y en el benchmark del
# sector es peor, porque números que nunca existieron quedarían dentro del promedio contra el que se
# compara un club real.
RSpec.describe 'Los clubes demo no cuentan en las métricas', type: :request do
  include AuthHelpers

  let(:super_admin) { create(:user, :super_admin) }
  let(:real)  { create(:club, name: 'Club Real') }
  let(:demo)  { create(:club, name: 'Club Modelo', demo: true) }

  before do
    ActsAsTenant.with_tenant(real) { create(:paciente, club: real, created_by: create(:user, :admin, club: real)) }
    ActsAsTenant.with_tenant(demo) do
      3.times { create(:paciente, club: demo, created_by: create(:user, :admin, club: demo)) }
    end
    sign_in_as(super_admin)
  end

  it 'el resumen cuenta solo los clubes reales' do
    get '/api/super_admin/stats'

    data = JSON.parse(response.body)
    # El total no incluye al demo (el super_admin de la factory trae su propio club, de ahí que se
    # compare contra la cantidad de clubes reales y no contra un número fijo).
    expect(data['resumen']['total_clubs']).to eq(Club.reales.count)
    expect(data['resumen']['total_clubs']).to be < Club.unscoped.count
    expect(data['resumen']['total_pacientes']).to eq(1)   # no los 3 inventados del demo
  end

  # Pero el listado sí los muestra: hay que poder entrar a administrarlos.
  it 'el listado los muestra, marcados' do
    get '/api/super_admin/stats'

    clubes = JSON.parse(response.body)['clubs']
    modelo = clubes.find { |c| c['name'] == 'Club Modelo' }
    expect(modelo).to be_present
    expect(modelo['demo']).to be true
  end

  it 'las métricas de plataforma tampoco los cuentan' do
    get '/api/super_admin/metricas'

    data = JSON.parse(response.body)
    expect(data['total_clubes']).to eq(Club.reales.count)
    expect(data['total_clubes']).to be < Club.unscoped.count
    expect(data['total_pacientes']).to eq(1)
  end

  # El opt-in del benchmark no alcanza: nada impide que un club demo lo tenga prendido.
  it 'no entran al benchmark del sector aunque tengan el opt-in prendido' do
    real.update!(benchmark_opt_in: true)
    demo.update!(benchmark_opt_in: true)

    expect(Club.reales.where(benchmark_opt_in: true).count).to eq(1)
  end
end
