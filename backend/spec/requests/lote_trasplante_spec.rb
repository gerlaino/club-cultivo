require 'rails_helper'

RSpec.describe 'POST /lotes/:id/registrar_trasplante', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, tamanio_maceta: 1) }
  let!(:p1)   { create(:plant, lote: lote) }
  let!(:p2)   { create(:plant, lote: lote) }

  it 'registra el trasplante (PlantActivity por planta) y actualiza la maceta del lote' do
    sign_in_as(admin)
    expect {
      post "/lotes/#{lote.id}/registrar_trasplante",
           params: { fecha: Date.current.to_s, maceta_origen_l: 1, maceta_destino_l: 3 },
           headers: auth_headers
    }.to change(PlantActivity.where(activity_type: 'transplant'), :count).by(2)

    expect(response).to have_http_status(:ok)
    expect(lote.reload.tamanio_maceta.to_f).to eq(3.0)
    act = p1.activities.where(activity_type: 'transplant').last
    expect(act.metadata['maceta_origen_l']).to eq(1.0)
    expect(act.metadata['maceta_destino_l']).to eq(3.0)
  end

  it 'aparece en la timeline del lote agrupado por maceta' do
    sign_in_as(admin)
    post "/lotes/#{lote.id}/registrar_trasplante",
         params: { fecha: Date.current.to_s, maceta_origen_l: 1, maceta_destino_l: 3 },
         headers: auth_headers
    get "/lotes/#{lote.id}/timeline", headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['transplantes']).to be_present
    expect(body['transplantes'].first['maceta_destino']).to eq(3.0)
  end

  it 'un lote enraizando trasplantado con fecha pasada figura en vegetativo desde esa fecha' do
    enraizando = create(:lote, club: club, sala: sala, estado: 'enraizado')
    create(:plant, lote: enraizando, state: 'enraizado')
    dia = 4.days.ago.to_date
    sign_in_as(admin)

    post "/lotes/#{enraizando.id}/registrar_trasplante",
         params: { fecha: dia.to_s, maceta_destino_l: 0.335 },
         headers: auth_headers

    expect(response).to have_http_status(:ok)
    enraizando.reload
    expect(enraizando.estado).to eq('vegetativo')
    expect(enraizando.fecha_inicio_vegetativo).to eq(dia)
  end

  it 'rechaza una fecha futura sin tocar el lote' do
    sign_in_as(admin)
    post "/lotes/#{lote.id}/registrar_trasplante",
         params: { fecha: 1.day.from_now.to_date.to_s, maceta_destino_l: 3 },
         headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(lote.reload.tamanio_maceta.to_f).to eq(1.0)
  end

  it 'pasa el medio, el sustrato, las raíces y las observaciones al historial' do
    enraizando = create(:lote, club: club, sala: sala, estado: 'enraizado', metodo_enraizado: 'incubadora', grow_type: 'hidroponia')
    create(:plant, lote: enraizando, state: 'enraizado')
    sign_in_as(admin)

    post "/lotes/#{enraizando.id}/registrar_trasplante",
         params: { fecha: Date.current.to_s, maceta_destino_l: 0.335, medio: 'sustrato', sustrato: 'turba',
                   estado_raices: 'excelente', observaciones: 'todas prendieron' },
         headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(enraizando.reload.grow_type).to eq('sustrato')
    ev = enraizando.lote_eventos.find_by(categoria: 'trasplante')
    expect(ev.metadata).to include('medio_origen' => 'incubadora', 'medio_destino' => 'sustrato', 'estado_raices' => 'excelente')
    expect(ev.descripcion).to eq('todas prendieron')
  end

  it 'la ficha trae el método de enraizado y el medio que sugiere el trasplante' do
    enraizando = create(:lote, club: club, sala: sala, estado: 'enraizado', metodo_enraizado: 'jiffy')
    sign_in_as(admin)

    get "/lotes/#{enraizando.id}", headers: auth_headers

    body = JSON.parse(response.body)
    expect(body).to include('metodo_enraizado' => 'jiffy', 'medio_al_trasplantar' => 'sustrato')
  end

  it 'el método de enraizado se guarda editando el lote' do
    sign_in_as(admin)

    patch "/lotes/#{lote.id}", params: { lote: { metodo_enraizado: 'incubadora' } }, headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(lote.reload.metodo_enraizado).to eq('incubadora')
  end

  it 'no deja trasplantar un lote de otra organización' do
    otro_club = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro_club) do
      otra_sala = create(:sala, club: otro_club, sede: create(:sede, club: otro_club, created_by: create(:user, :admin, club: otro_club)))
      l = create(:lote, club: otro_club, sala: otra_sala, tamanio_maceta: 1)
      create(:plant, lote: l)
      l
    end
    sign_in_as(admin)

    post "/lotes/#{ajeno.id}/registrar_trasplante", params: { maceta_destino_l: 3 }, headers: auth_headers

    expect(response.status).to be_in([403, 404])
    expect(ActsAsTenant.with_tenant(otro_club) { ajeno.reload.tamanio_maceta.to_f }).to eq(1.0)
  end

  it 'rechaza sin maceta destino' do
    sign_in_as(admin)
    post "/lotes/#{lote.id}/registrar_trasplante", params: { fecha: Date.current.to_s }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'permite registrar un trasplante pasado en un lote ya cosechado (plantas cosechadas)' do
    lote.update!(estado: 'cosecha')
    [p1, p2].each { |p| p.update!(state: 'cosechado') }
    sign_in_as(admin)

    expect {
      post "/lotes/#{lote.id}/registrar_trasplante",
           params: { fecha: 20.days.ago.to_date.to_s, maceta_origen_l: 1, maceta_destino_l: 3 },
           headers: auth_headers
    }.to change(PlantActivity.where(activity_type: 'transplant'), :count).by(2)

    expect(response).to have_http_status(:ok)
    # En un lote cosechado NO se toca la maceta "actual"
    expect(lote.reload.tamanio_maceta.to_f).to eq(1.0)
  end
end
