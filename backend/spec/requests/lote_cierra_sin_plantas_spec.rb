require 'rails_helper'

# AC (9-oct-2026, Germán): descarté tres plantas que no germinaron y el lote quedó en la lista,
# «Germinación · 0 plantas». Si descarto (o elimino) la última planta viva, el lote se cierra, con
# un aviso antes para confirmar. Esos lotes no entran en los promedios, pero tienen que figurar en
# algún lado: si se finalizó porque se descartaron las plantas, lo tengo que saber.
RSpec.describe 'La última planta viva cierra el lote', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'enraizado', plants_count: 0) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def plantas(n, en: lote, state: 'enraizado')
    ps = Array.new(n) { create(:plant, lote: en, club: club, state: state) }
    en.update_column(:plants_count, en.plants.where.not(state: 'descartada').count)
    ps
  end

  def descartar(planta, **extra)
    patch "/api/plants/#{planta.id}", params: { plant: { state: 'descartada' }, motivo: 'no germinó', **extra }, as: :json
  end

  before { sign_in_as(admin) }

  describe 'descartar' do
    it 'la última, sin confirmar: avisa y no toca nada' do
      a, b, c = plantas(3)
      descartar(a); descartar(b)

      descartar(c)

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body['codigo']).to eq('ultima_planta')
      expect(body['error']).to include(lote.codigo).and include('se cierra sin cosecha')
      expect(c.reload.state).to eq('enraizado')
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'la última, confirmada: la descarta y cierra el lote sin cosecha' do
      (a,) = plantas(1)

      descartar(a, cerrar_lote: true)

      expect(response).to have_http_status(:ok), response.body
      expect(a.reload.state).to eq('descartada')
      lote.reload
      expect(lote).to have_attributes(estado: 'finalizado', sala_id: nil)
      expect(lote.rendimiento_real_g.to_f).to eq(0)
      expect(lote).to be_cerrado_sin_cosecha
      expect(lote.lote_eventos.where(tipo: 'cambio_estado', estado_anterior: 'enraizado', estado_nuevo: 'finalizado')
                 .pluck(:descripcion)).to eq(['Se descartaron todas las plantas — lote cerrado sin cosecha.'])
    end

    it 'con otras plantas vivas no avisa ni cierra' do
      a, = plantas(2)

      descartar(a)

      expect(response).to have_http_status(:ok)
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'una planta cosechada sigue contando: no es la última viva' do
      lote.update_columns(estado: 'vegetativo')
      plantas(1, state: 'cosechado')
      (a,) = plantas(1, state: 'vegetativo')

      descartar(a)

      expect(response).to have_http_status(:ok)
      expect(lote.reload.estado).to eq('vegetativo')
    end

    it 'un lote cargado sólo con el número no se cierra por descartar la única individualizada' do
      (a,) = plantas(1)
      lote.update_column(:plants_count, 40)

      descartar(a)

      expect(response).to have_http_status(:ok)
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'cancela lo que quedaba programado para el lote y sus plantas' do
      (a,) = plantas(1)
      del_lote   = create(:tarea, club: club, creada_por: admin, lote: lote)
      de_planta  = create(:tarea, club: club, creada_por: admin, plant: a)
      hecha      = create(:tarea, club: club, creada_por: admin, lote: lote, estado: 'completada')

      descartar(a, cerrar_lote: true)

      expect(del_lote.reload.estado).to eq('cancelada')
      expect(de_planta.reload.estado).to eq('cancelada')
      expect(hecha.reload.estado).to eq('completada')
    end

    it 'en un lote cerrado el descarte no se revierte' do
      (a,) = plantas(1)
      descartar(a, cerrar_lote: true)

      patch "/api/plants/#{a.id}", params: { plant: { state: 'enraizado' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(a.reload.state).to eq('descartada')
    end

    it 'en el autocultivo el aviso no habla de lotes' do
      club.update_column(:plan, 'personal')
      (a,) = plantas(1)

      descartar(a)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['error']).not_to match(/lote/i)
    end
  end

  describe 'eliminar' do
    it 'la última viva: avisa, y confirmada cierra el lote' do
      (a,) = plantas(1)

      delete "/api/plants/#{a.id}"
      expect(response).to have_http_status(:conflict)
      expect(Plant.find_by(id: a.id)).to be_present

      delete "/api/plants/#{a.id}", params: { cerrar_lote: true }
      expect(response).to have_http_status(:no_content)
      expect(lote.reload.estado).to eq('finalizado')
    end

    it 'eliminar una ya descartada no avisa' do
      a, = plantas(2)
      descartar(a)

      delete "/api/plants/#{a.id}"

      expect(response).to have_http_status(:no_content)
      expect(lote.reload.estado).to eq('enraizado')
    end
  end

  describe 'dónde figura' do
    let!(:cosechado) { create(:lote, club: club, sala: sala, estado: 'finalizado', rendimiento_real_g: 300, plants_count: 0) }

    before do
      (a,) = plantas(1)
      descartar(a, cerrar_lote: true)
    end

    it 'en el informe de pérdidas, con el lote, la genética y en qué estaba' do
      get '/api/informes/perdidas'
      cerrados = JSON.parse(response.body).dig('plantas', 'lotes_cerrados')

      expect(cerrados.map { |l| l['codigo'] }).to eq([lote.codigo])
      expect(cerrados.first).to include('plantas' => 1, 'estaba_en' => Lote.etiqueta_estado('enraizado', lote.origen))
    end

    it 'fuera del rendimiento promedio' do
      get '/api/benchmark'
      mi_club = JSON.parse(response.body)['mi_club']

      expect(mi_club['rendimiento_promedio_g']).to eq(300.0)
      expect(mi_club['lotes_finalizados']).to eq(1)
    end
  end

  it 'aislamiento: la planta de otra organización no se toca' do
    otro    = create(:club)
    ajena   = ActsAsTenant.with_tenant(otro) do
      osede = create(:sede, club: otro, created_by: create(:user, :admin, club: otro))
      osala = create(:sala, club: otro, sede: osede, created_by: osede.created_by)
      olote = create(:lote, club: otro, sala: osala, estado: 'enraizado', plants_count: 1)
      create(:plant, lote: olote, club: otro, state: 'enraizado')
    end

    descartar(ajena, cerrar_lote: true)

    expect(response).to have_http_status(:not_found)
    ActsAsTenant.with_tenant(otro) { expect(ajena.reload.lote.estado).to eq('enraizado') }
  end
end
