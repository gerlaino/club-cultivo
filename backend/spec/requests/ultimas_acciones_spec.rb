require 'rails_helper'

# AC (Germán, 12-oct-2026): en el inicio del autocultivo, las últimas acciones registradas —qué se
# hizo, dónde, cuándo y quién—, lo más nuevo primero. Con lo aplicado dicho (receta y productos).
RSpec.describe 'GET /ultimas_acciones', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club, first_name: 'Germán', last_name: 'L') }
  let(:carpa) { create(:sala, club: club, nombre: 'Carpa', created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: carpa, codigo: 'L-1', estado: 'vegetativo') }
  let!(:p1)   { create(:plant, lote: lote, club: club, nombre: 'P1') }
  let!(:p2)   { create(:plant, lote: lote, club: club, nombre: 'P2') }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  it 'lo más nuevo primero, con lo aplicado, dónde (las plantas) y quién' do
    create(:registro_ambiental, lote: lote, user: admin, registrado_en: 2.hours.ago, tareas_realizadas: %w[riego nutricion],
                                nutricion: { 'receta_nombre' => 'Flora 1', 'litros' => 10, 'costo_ars' => 500,
                                             'items' => [{ 'nombre' => 'Big Bloom', 'cantidad' => 20, 'unidad' => 'mililitro' }] })
    p1.activities.create!(activity_type: 'transplant', user: admin, occurred_at: 1.hour.ago, description: 'A 3 L')

    get '/ultimas_acciones', headers: auth_headers

    expect(response).to have_http_status(:ok)
    a = json['acciones']
    expect(a.map { |x| x['titulo'] }).to eq(['Trasplante', 'Riego y Nutrición'])
    expect(a[0]).to include('donde' => 'P1', 'ruta' => "/plantas/#{p1.id}")
    expect(a[1]).to include('donde' => 'P1, P2', 'usuario' => 'Germán L')
    expect(a[1]['detalle']).to eq('Flora 1 · 10 L: Big Bloom 20 ml')
  end

  it 'no trae nada de otra organización' do
    otro = create(:club, plan: 'personal', features: { 'cultivo' => true })
    otro_admin = create(:user, :admin, club: otro)
    ActsAsTenant.with_tenant(otro) do
      s = create(:sala, club: otro, created_by: otro_admin)
      create(:registro_ambiental, lote: create(:lote, club: otro, sala: s), user: otro_admin, registrado_en: 1.minute.ago)
    end

    get '/ultimas_acciones', headers: auth_headers

    expect(json['acciones']).to eq([])
  end

  it 'respeta el límite' do
    3.times { |i| create(:registro_ambiental, lote: lote, user: admin, registrado_en: i.hours.ago) }

    get '/ultimas_acciones', params: { limite: 2 }, headers: auth_headers

    expect(json['acciones'].size).to eq(2)
  end
end
