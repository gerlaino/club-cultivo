require 'rails_helper'

# DAR VUELTA UNA SALA: IDA Y VUELTA NO SON SIMÉTRICAS (sep-2026, decisión de Germán).
#
# Vegetativo → floración es un avance. Floración → vegetativo con lotes adentro es DESHACER:
# nadie revegeta a propósito una planta que ya recibió 12/12 — una sala vuelve a vegetativo o
# vacía, o porque alguien se equivocó de botón. Antes se trataba como avance y dejaba al lote
# con un ciclo falso («estuvo un día en floración y revegetó»).
#
# Y es UNA regla para las DOS puertas: el botón «Cambiar fase» y editar el `kind` de la sala.
RSpec.describe 'Dar vuelta una sala', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }

  before { sign_in_as(admin) }

  def body = JSON.parse(response.body)

  # Un lote que entró a vegetativo hace 30 días y a floración hace 3, con las tareas que la app
  # le sugirió al entrar en floración.
  let!(:lote) { create(:lote, club: club, sala: sala, estado: 'floracion', tamanio_maceta: 3) }
  let!(:planta) { create(:plant, lote: lote, club: club, state: 'floracion') }
  before do
    ActsAsTenant.with_tenant(club) do
      lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'enraizado', estado_nuevo: 'vegetativo',
                                user: admin, club: club, registrado_en: 30.days.ago)
      lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
                                user: admin, club: club, registrado_en: 3.days.ago)
      TareasAutoService.new(lote: lote, estado_nuevo: 'floracion', user: admin, club: club).call
      # Una foto y una nota cargadas en floración: hechos reales, no se tocan.
      lote.lote_eventos.create!(tipo: 'nota', descripcion: 'Riego con bloom', user: admin, club: club,
                                registrado_en: 1.day.ago)
    end
  end

  let(:tareas_flor) { Tarea.where(lote_id: lote.id, titulo: TareasAutoService::SUGERENCIAS['floracion'].map { |t| t[:titulo] }) }

  describe 'floración → vegetativo con lotes adentro' do
    it 'frena y dice qué se va a deshacer, lote por lote' do
      post "/api/salas/#{sala.id}/cambiar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['requiere_confirmacion']).to be(true)
      expect(body['deshace']).to be(true)
      expect(body['error']).to match(/como si nunca hubiera pasado a floración/)
      l = body['lotes_afectados'].first
      expect(l).to include('codigo' => lote.codigo, 'dias_en_fase' => 3, 'plantas' => 1)
      expect(l['tareas_a_cancelar']).to eq(tareas_flor.count)
      expect(body['tareas_a_cancelar']).to eq(tareas_flor.count)
      expect(sala.reload.kind).to eq('floracion')
    end

    context 'confirmado' do
      before { post "/api/salas/#{sala.id}/cambiar_fase", params: { confirmar_cambio_fase: 1 } }

      it 'vuelve la sala, el lote y las plantas a vegetativo' do
        expect(response).to have_http_status(:ok)
        expect(sala.reload.kind).to eq('vegetativo')
        expect(lote.reload.estado).to eq('vegetativo')
        expect(planta.reload.state).to eq('vegetativo')
      end

      # ESTO ES LO QUE LO HACE UN DESHACER Y NO UN AVANCE: el evento que marcó la entrada a
      # floración desaparece, así que la fecha de inicio y los días de fase vuelven a contar
      # desde el paso a vegetativo de hace 30 días. No queda un «floración → vegetativo».
      it 'borra el paso a floración: los relojes vuelven a contar desde el vegetativo original' do
        lote.reload
        expect(lote.fecha_inicio_floracion).to be_nil
        expect(lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'vegetativo').count).to eq(1)
        expect(lote.lote_eventos.where(tipo: 'cambio_estado', estado_anterior: 'floracion')).not_to exist

        get "/api/lotes/#{lote.id}"
        expect(JSON.parse(response.body)['dias_en_estado']).to eq(30)
      end

      it 'cancela las tareas de floración que seguían pendientes' do
        expect(tareas_flor.where(estado: 'pendiente')).not_to exist
        expect(tareas_flor.where(estado: 'cancelada').count).to eq(TareasAutoService::SUGERENCIAS['floracion'].size)
        expect(body['tareas_canceladas']).to eq(TareasAutoService::SUGERENCIAS['floracion'].size)
      end

      it 'deja las notas de esos días y anota que se deshizo' do
        notas = lote.reload.lote_eventos.where(tipo: 'nota').order(:registrado_en)
        expect(notas.first.descripcion).to eq('Riego con bloom')
        expect(notas.last.descripcion).to match(/Se deshizo el paso a floración del \d{2}\/\d{2}\/\d{4} \(3 días\)/)
      end
    end

    # Una tarea de floración que alguien YA hizo se hizo: no se cancela.
    it 'no toca las tareas de floración ya completadas' do
      hecha = tareas_flor.first
      hecha.update_columns(estado: 'completada', fecha_completada: Time.current)

      post "/api/salas/#{sala.id}/cambiar_fase", params: { confirmar_cambio_fase: 1 }

      expect(hecha.reload.estado).to eq('completada')
    end

    it 'editar el kind de la sala pasa por la misma regla y también deshace' do
      patch "/api/salas/#{sala.id}", params: { sala: { nombre: sala.nombre, kind: 'vegetativo' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['deshace']).to be(true)

      patch "/api/salas/#{sala.id}",
            params: { sala: { nombre: sala.nombre, kind: 'vegetativo' }, confirmar_cambio_fase: true }, as: :json
      expect(response).to have_http_status(:ok)
      expect(lote.reload.fecha_inicio_floracion).to be_nil
      expect(tareas_flor.where(estado: 'pendiente')).not_to exist
    end
  end

  describe 'vegetativo → floración con lotes adentro' do
    let(:vege) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
    let!(:en_vege) { create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3) }

    # El error humano es simétrico: pasar a 12/12 un lote recién trasplantado también es un
    # error. Antes el botón no preguntaba nada.
    it 'también pide confirmación, con los días que lleva cada lote' do
      post "/api/salas/#{vege.id}/cambiar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['requiere_confirmacion']).to be(true)
      expect(body['deshace']).to be(false)
      expect(body['lotes_afectados'].first).to include('codigo' => en_vege.codigo, 'estado_nuevo' => 'floracion')
    end

    it 'confirmado, es un avance: queda el evento vegetativo → floración' do
      post "/api/salas/#{vege.id}/cambiar_fase", params: { confirmar_cambio_fase: 1 }

      expect(response).to have_http_status(:ok)
      expect(en_vege.reload.estado).to eq('floracion')
      expect(en_vege.lote_eventos.where(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion')).to exist
    end
  end

  describe 'una sala vacía' do
    let(:vacia) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }

    it 'se da vuelta sin preguntar: es el caso legítimo de volver a vegetativo' do
      post "/api/salas/#{vacia.id}/cambiar_fase"

      expect(response).to have_http_status(:ok)
      expect(vacia.reload.kind).to eq('vegetativo')
      expect(body['lotes_afectados']).to eq(0)
    end
  end

  # Si la edición trae algo inválido además del kind, no se da vuelta nada: antes la fase ya
  # había cambiado y los lotes ya estaban arrastrados cuando el nombre vacío rebotaba.
  it 'editar con un dato inválido no da vuelta la sala a medias' do
    patch "/api/salas/#{sala.id}",
          params: { sala: { nombre: '', kind: 'vegetativo' }, confirmar_cambio_fase: true }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(sala.reload.kind).to eq('floracion')
    expect(lote.reload.estado).to eq('floracion')
  end
end
