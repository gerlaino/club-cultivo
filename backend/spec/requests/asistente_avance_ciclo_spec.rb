require 'rails_helper'

# AC (9-oct-2026, Germán): dicté «avanzá de fase el lote que tenemos germinando» y saltó «Tamanio
# maceta es obligatorio…». Avanzar por voz es lo mismo que el botón: al paso siguiente, y pasar de
# germinación a vegetativo es ponerlo en maceta. Si se dice a cuál, avanza; si no, se pide en
# castellano y no se toca nada. La cosecha no se registra por voz (va con su pesada).
RSpec.describe 'Asistente: avanzar de fase dictando', type: :request do
  let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true, 'ia' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let!(:carpa) { create(:sala, club: club, sede: sede, nombre: 'Carpa', kind: 'mixta', created_by: admin) }
  let(:gen)   { create(:genetica, club: club, nombre: 'Kings Juice') }
  let!(:lote) { create(:lote, club: club, sala: carpa, genetica: gen, estado: 'enraizado', origen: 'semilla', tamanio_maceta: nil, plants_count: 3) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before do
    3.times { create(:plant, lote: lote, club: club, state: 'enraizado') }
    sign_in_as(admin)
  end

  def avanzar(**datos)
    post '/api/asistente/ejecutar', params: { acciones: [{ tipo: 'avance_ciclo', lote_codigo: lote.codigo, datos: datos }] }, as: :json
    response.parsed_body
  end

  it 'de germinación a vegetativo sin decir la maceta: la pide en castellano y no toca nada' do
    r = avanzar(estado_nuevo: 'vegetativo')

    expect(r['ejecutadas']).to eq(0)
    error = r['errores_detalle'].first['error']
    expect(error).to include('falta la maceta', 'Kings Juice').and include('al vaso')
    expect(error).not_to match(/tamanio/i)
    expect(error).not_to include(lote.codigo) # en autocultivo no se nombra el lote
    expect(lote.reload.estado).to eq('enraizado')
  end

  it 'diciendo la maceta avanza como el botón: maceta, plantas y evento' do
    r = avanzar(estado_nuevo: 'vegetativo', maceta_litros: 0.335)

    expect(r['ejecutadas']).to eq(1), r.inspect
    lote.reload
    expect(lote.estado).to eq('vegetativo')
    expect(lote.tamanio_maceta.to_f).to eq(0.335)
    expect(lote.plants.pluck(:state).uniq).to eq(['vegetativo'])
    expect(lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'vegetativo').count).to eq(1)
  end

  # AC (11-oct-2026, Germán): «que las tareas las generen los usuarios, no nosotros». Pasar a
  # vegetativo agendaba «Primer riego» y «Medir EC y pH» aunque el riego se acabara de registrar.
  it 'avanzar de fase no crea tareas' do
    expect { avanzar(estado_nuevo: 'vegetativo', maceta_litros: 0.335) }.not_to change(Tarea, :count)
  end

  it 'saltear un paso no se hace por voz' do
    r = avanzar(estado_nuevo: 'floracion', maceta_litros: 7)
    expect(r['ejecutadas']).to eq(0)
    expect(r['errores_detalle'].first['error']).to include('paso siguiente')
    expect(lote.reload.estado).to eq('enraizado')
  end

  it 'la cosecha no se registra por voz' do
    lote.update_columns(estado: 'floracion', tamanio_maceta: 7)
    r = avanzar(estado_nuevo: 'cosecha')
    expect(r['ejecutadas']).to eq(0)
    expect(r['errores_detalle'].first['error']).to include('pesada')
    expect(lote.reload.estado).to eq('floracion')
  end

  it 'el lote de otra organización no se encuentra' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) do
      s = create(:sala, club: otro, sede: create(:sede, club: otro))
      create(:lote, club: otro, sala: s, estado: 'enraizado', codigo: 'L-AJENO')
    end
    post '/api/asistente/ejecutar', params: { acciones: [{ tipo: 'avance_ciclo', lote_codigo: 'L-AJENO', datos: { estado_nuevo: 'vegetativo', maceta_litros: 1 } }] }, as: :json
    expect(response.parsed_body['ejecutadas']).to eq(0)
    ActsAsTenant.with_tenant(otro) { expect(ajeno.reload.estado).to eq('enraizado') }
  end
end
