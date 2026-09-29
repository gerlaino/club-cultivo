require 'rails_helper'

# COMPARAR LO QUE RECIBIÓ CADA LOTE (Germán, 29-sep-2026). Lo que se afirma:
# - de 2 a 4 lotes lado a lado: lo recibido por producto (por planta y total) y el rendimiento;
# - las filas son TODOS los productos que recibió alguno: el que recibió sólo uno de los lotes
#   aparece igual, vacío en el otro;
# - la curva va por semana de fase, en el orden del ciclo (vege antes que flora);
# - un lote en curso entra, sin rendimiento;
# - el selector ofrece sólo lotes con alguna fertilización;
# - es de administración, y un id de otra organización no aparece.
RSpec.describe 'Analítica: nutrición lote contra lote', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:gen)   { ActsAsTenant.with_tenant(club) { Genetica.create!(club: club, nombre: 'Kush') } }
  let(:cerrado) { create(:lote, club: club, sala: sala, genetica: gen, estado: 'curado', plants_count: 4, rendimiento_real_g: 400) }
  let(:en_curso) { create(:lote, club: club, sala: sala, genetica: gen, estado: 'vegetativo', plants_count: 2) }
  let(:sin_nada) { create(:lote, club: club, sala: sala, estado: 'vegetativo') }
  let(:grow)  { insumo('Bio-Grow') }
  let(:bloom) { insumo('Bloom') }

  def insumo(nombre)
    ActsAsTenant.with_tenant(club) do
      i = club.insumos.create!(nombre: nombre, unidad_medida: 'mililitro', sede: sede)
      i.registrar_compra!(cantidad: 5000, costo_total_ars: 5000, created_by: admin, generar_egreso: false)
      i
    end
  end

  before { sign_in_as(admin) }

  def regar(lote, items, ec:, cuando:)
    post "/lotes/#{lote.id}/registros_ambientales",
         params: { registro_ambiental: { fertilizacion: true, ec: ec, registrado_en: cuando.iso8601 }, nutricion: { litros: 10, items: items } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
  end

  def fase(lote, de, a, cuando)
    ActsAsTenant.with_tenant(club) do
      lote.lote_eventos.create!(club: club, user: admin, tipo: 'cambio_estado', estado_anterior: de, estado_nuevo: a, registrado_en: cuando)
    end
  end

  before do
    fase(cerrado, 'enraizado', 'vegetativo', Time.zone.parse('2026-06-01 10:00'))
    fase(cerrado, 'vegetativo', 'floracion', Time.zone.parse('2026-07-01 10:00'))
    fase(en_curso, 'enraizado', 'vegetativo', Time.zone.parse('2026-09-01 10:00'))
    regar(cerrado, [{ insumo_id: grow.id, cantidad: 40 }], ec: 1.2, cuando: Time.zone.parse('2026-06-10 12:00'))   # V2
    regar(cerrado, [{ insumo_id: bloom.id, cantidad: 80 }], ec: 1.8, cuando: Time.zone.parse('2026-07-03 12:00'))  # F1
    regar(en_curso, [{ insumo_id: grow.id, cantidad: 10 }], ec: 1.0, cuando: Time.zone.parse('2026-09-03 12:00'))  # V1
    sin_nada
  end

  def comparar(ids)
    get '/analytics/nutricion', params: { lote_ids: ids }, headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    json
  end

  it 'pone los lotes lado a lado: lo recibido por producto y cómo rindió' do
    d = comparar([cerrado.id, en_curso.id])
    expect(d['lotes'].map { |l| l['codigo'] }).to eq([cerrado.codigo, en_curso.codigo])
    c, e = d['lotes']
    expect(c['por_producto']['bio-grow|mililitro']).to include('cantidad' => 40.0, 'por_planta' => 10.0)
    expect(c['g_por_planta']).to eq(100.0)
    expect(e['por_producto']['bio-grow|mililitro']).to include('cantidad' => 10.0, 'por_planta' => 5.0)
    expect(e['rendimiento_g']).to be_nil
  end

  it 'el producto que recibió sólo uno de los lotes también es fila (vacía en el otro)' do
    d = comparar([cerrado.id, en_curso.id])
    expect(d['productos'].map { |p| p['nombre'] }).to match_array(%w[Bio-Grow Bloom])
    expect(d['lotes'].last['por_producto']).not_to have_key('bloom|mililitro')
  end

  it 'la curva de EC va por semana de fase, vege antes que flora' do
    d = comparar([cerrado.id, en_curso.id])
    expect(d['semanas']).to eq(%w[V1 V2 F1])
    expect(d['lotes'].first['por_semana'].map { |w| [w['semana_label'], w['ec']] }).to eq([['V2', 1.2], ['F1', 1.8]])
  end

  it 'compara hasta 4 lotes' do
    extra = Array.new(4) { create(:lote, club: club, sala: sala) }
    d = comparar([cerrado.id, en_curso.id, *extra.map(&:id)])
    expect(d['lotes'].size).to eq(4)
  end

  it 'el selector ofrece sólo los lotes con alguna fertilización' do
    get '/analytics/nutricion_lotes', headers: auth_headers
    expect(json['lotes'].map { |l| l['id'] }).to match_array([cerrado.id, en_curso.id])
    expect(json['lotes'].first).to include('genetica' => 'Kush', 'genetica_id' => gen.id)
  end

  it 'es de administración: el cultivador no entra' do
    sign_in_as(create(:user, :cultivador, club: club))
    get '/analytics/nutricion', params: { lote_ids: [cerrado.id] }, headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'un lote de otra organización no aparece' do
    otro = create(:club, features: { 'cultivo' => true })
    ajeno = ActsAsTenant.with_tenant(otro) do
      a = create(:user, :admin, club: otro)
      s = create(:sede, club: otro, created_by: a)
      create(:lote, club: otro, sala: create(:sala, club: otro, sede: s, created_by: a))
    end
    d = comparar([cerrado.id, ajeno.id])
    expect(d['lotes'].map { |l| l['id'] }).to eq([cerrado.id])
  end
end
