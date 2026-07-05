require 'rails_helper'

# Flujo nuevo de manicura: el manicura crea un pesaje (jornada), registra el peso de
# plantas contra ese pesaje (pesada_id nil, pesaje_manicura_id seteado) y lista los
# pesajes del lote. Regresión de dos bugs:
#   - pesadas_plantas.pesada_id era NOT NULL → registrar_peso del flujo nuevo reventaba.
#   - el serializer sumaba peso_seco_g en Ruby y explotaba con un valor nil.
RSpec.describe 'Flujo de pesajes de manicura', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, kind: 'manicura') }
  let(:lote)     { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura) }
  let!(:planta)  { create(:plant, lote: lote, club: club, state: 'cosechado') }

  before { sign_in_as(manicura) }

  it 'crea un pesaje, registra el peso de una planta y lista sin error 500' do
    # 1. Crear pesaje (jornada)
    post "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:created)
    pesaje_id = JSON.parse(response.body)['id']

    # 2. Registrar el peso de la planta contra ese pesaje (flujo nuevo, pesada nil)
    post "/plants/#{planta.id}/registrar_peso",
         params: { peso_seco_g: 12.5, pesaje_manicura_id: pesaje_id },
         headers: auth_headers
    expect(response).to have_http_status(:ok)

    pp = PesadaPlanta.find_by(plant_id: planta.id, pesaje_manicura_id: pesaje_id)
    expect(pp).to be_present
    expect(pp.pesada_id).to be_nil

    # 3. Listar pesajes del lote — no debe dar 500
    get "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.first['peso_calculado_g']).to eq(12.5)
  end

  it 'registrar peso SIN pesaje_manicura_id (scan QR) alimenta la jornada abierta y refleja KPIs' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current)

    post "/plants/#{planta.id}/registrar_peso", params: { peso_seco_g: 8 }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(pesaje.reload.pesadas_plantas.count).to eq(1)

    get "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    body = JSON.parse(response.body).find { |p| p['id'] == pesaje.id }
    expect(body['peso_calculado_g']).to eq(8.0)
    expect(body['plantas_registradas']).to eq(1)
  end

  it 'registrar peso sin jornada abierta en lote en_manicura crea una automáticamente' do
    expect {
      post "/plants/#{planta.id}/registrar_peso", params: { peso_seco_g: 5 }, headers: auth_headers
    }.to change { lote.pesajes_manicura.where(estado: 'borrador').count }.by(1)
    expect(response).to have_http_status(:ok)
  end

  it 'el manicura puede borrar una jornada propia no confirmada (y sus pesadas)' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current)
    pesaje.pesadas_plantas.create!(plant: planta, peso_seco_g: 3)

    expect {
      delete "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}", headers: auth_headers
    }.to change(PesajeManicura, :count).by(-1)
    expect(response).to have_http_status(:no_content)
    expect(PesadaPlanta.where(pesaje_manicura_id: pesaje.id)).to be_empty
  end

  it 'reabrir devuelve un pesaje enviado a borrador' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'enviado', enviado_at: Time.current)
    post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}/reabrir", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(pesaje.reload.estado).to eq('borrador')
    expect(pesaje.enviado_at).to be_nil
  end

  it 'no permite reabrir un pesaje confirmado' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'confirmado')
    post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}/reabrir", headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'no permite borrar un pesaje confirmado' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'confirmado')
    delete "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}", headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(PesajeManicura.exists?(pesaje.id)).to be true
  end

  it 'lista sin romper aunque una pesada_planta tenga peso_seco_g nil' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current)
    pesaje.pesadas_plantas.create!(plant: planta, peso_humedo_g: 5, peso_seco_g: nil)

    get "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).first['peso_calculado_g']).to eq(0.0)
  end

  it 'carga conjunta (sin QR): reparte el total como promedio por planta y lo envía' do
    create(:plant, lote: lote, club: club, state: 'cosechado')
    create(:plant, lote: lote, club: club, state: 'cosechado') # planta + 2 = 3 sin pesar

    expect {
      post "/lotes/#{lote.id}/pesajes_manicura",
           params: { plantas_count: 3, peso_total_g: 300, enviar: true },
           headers: auth_headers
    }.to change(PesajeManicura, :count).by(1)
    expect(response).to have_http_status(:created)
    pesaje = PesajeManicura.last
    expect(pesaje.estado).to eq('enviado')
    expect(pesaje.peso_total_g.to_f).to eq(300.0)
    expect(pesaje.plantas_count).to eq(3)
    # cada planta queda con el promedio (100g) marcado como estimado
    expect(pesaje.pesadas_plantas.pluck(:es_promedio)).to all(be(true))
    expect(pesaje.pesadas_plantas.pluck(:peso_seco_g).map(&:to_f)).to all(eq(100.0))
  end

  it 'carga conjunta con plant_ids: reparte SOLO entre las plantas seleccionadas' do
    p2 = create(:plant, lote: lote, club: club, state: 'cosechado')
    p3 = create(:plant, lote: lote, club: club, state: 'cosechado') # planta + p2 + p3 = 3 sin pesar

    post "/lotes/#{lote.id}/pesajes_manicura",
         params: { plant_ids: [p2.id, p3.id], peso_total_g: 200, enviar: true },
         headers: auth_headers
    expect(response).to have_http_status(:created)

    pesaje = PesajeManicura.last
    # solo las 2 seleccionadas quedan pesadas (100g promedio); la tercera sigue sin peso
    expect(pesaje.pesadas_plantas.pluck(:plant_id)).to match_array([p2.id, p3.id])
    expect(pesaje.pesadas_plantas.pluck(:peso_seco_g).map(&:to_f)).to all(eq(100.0))
    expect(planta.reload.peso_seco).to be_blank
  end

  it 'el admin confirma un pesaje y genera stock pendiente_asignacion (sin sede)' do
    pesaje = lote.pesajes_manicura.create!(
      manicurador: manicura, club: club, fecha_pesaje: Date.current,
      estado: 'enviado', enviado_at: Time.current, peso_total_g: 200, plantas_count: 1,
    )
    delete '/api/users/sign_out'
    sign_in_as(admin)
    expect {
      post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}/confirmar",
           params: { peso_confirmado_g: 200 }, headers: auth_headers
    }.to change(Stock, :count).by(1)
    expect(response).to have_http_status(:ok), "confirm falló: #{response.status} #{response.body}"
    stock = Stock.last
    expect(stock.estado).to eq('pendiente_asignacion')
    expect(stock.sede_id).to be_nil
    expect(stock.cantidad.to_f).to eq(200.0)
  end

  it 'transiciones con manicurado=true ya no carga manicura (devuelve 422)' do
    post "/lotes/#{lote.id}/transiciones",
         params: { nueva_fase: 'secado', pesada: { peso_seco_g: 100, manicurado: true } },
         headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Provisorio: si el lote está asignado a un manicura, SOLO ese responsable registra el
  # pesaje (evita ediciones concurrentes / pesos que se pisan).
  it 'un manicura NO asignado a un lote ya asignado a otro NO puede crear un pesaje' do
    otro_manicura = create(:user, :manicura, club: club)
    delete '/api/users/sign_out'
    sign_in_as(otro_manicura)

    post "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'cualquier manicura puede crear un pesaje si el lote no tiene manicurador asignado' do
    lote.update!(manicurador: nil)
    otro_manicura = create(:user, :manicura, club: club)
    delete '/api/users/sign_out'
    sign_in_as(otro_manicura)

    post "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:created)
  end

  it 'el admin NO puede crear un pesaje batch si el lote está asignado a un manicura' do
    delete '/api/users/sign_out'
    sign_in_as(admin)
    post "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'el admin SÍ puede crear un pesaje si el lote no tiene manicura asignado' do
    lote.update!(manicurador: nil)
    delete '/api/users/sign_out'
    sign_in_as(admin)
    post "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:created)
  end

  it 'NO permite editar el peso_seco de una planta en manicura desde el detalle (plants#update)' do
    delete '/api/users/sign_out'
    sign_in_as(admin)
    put "/plants/#{planta.id}", params: { plant: { peso_seco: 999 } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(planta.reload.peso_seco.to_f).not_to eq(999.0)
  end

  # Guard de jornada: si hay una jornada ENVIADA sin confirmar y no hay borrador, el backend
  # avisa (409 needs_choice) para que el front pregunte "¿seguir la anterior o una nueva?".
  context 'jornada enviada sin confirmar (guard needs_choice)' do
    let!(:enviada) do
      lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'enviado')
    end

    it 'registrar_peso responde 409 needs_choice (no crea una jornada nueva en silencio)' do
      post "/plants/#{planta.id}/registrar_peso", params: { peso_seco_g: 10 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body['needs_choice']).to be(true)
      expect(body.dig('jornada_enviada', 'id')).to eq(enviada.id)
      expect(lote.pesajes_manicura.borradores.count).to eq(0)
    end

    it 'registrar_peso con force_new abre una jornada nueva sin preguntar' do
      post "/plants/#{planta.id}/registrar_peso", params: { peso_seco_g: 10, force_new: true }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(lote.pesajes_manicura.borradores.count).to eq(1)
    end

    it 'registrar_peso NO pregunta si ya hay un borrador abierto (continúa esa jornada)' do
      borr = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'borrador')
      post "/plants/#{planta.id}/registrar_peso", params: { peso_seco_g: 10 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(lote.pesajes_manicura.borradores.count).to eq(1)
      expect(PesadaPlanta.find_by(plant_id: planta.id).pesaje_manicura_id).to eq(borr.id)
    end

    it 'batch (carga conjunta) también responde 409 needs_choice' do
      post "/lotes/#{lote.id}/pesajes_manicura",
           params: { peso_total_g: 100, plant_ids: [planta.id] }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['needs_choice']).to be(true)
    end

    it 'batch con force_new abre una jornada nueva' do
      post "/lotes/#{lote.id}/pesajes_manicura",
           params: { peso_total_g: 100, plant_ids: [planta.id], force_new: true }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
    end
  end

  # Mixto: el manicura pesa algunas plantas por QR y el resto por batch. El batch cubre
  # SOLO las restantes; al confirmar ambos, el total procesado debe llegar al total del
  # lote (no quedarse corto) y el lote pasa a curado con los gramos sumados.
  it 'pesadas individuales + batch del resto finaliza el lote en el total (curado)' do
    create(:plant, lote: lote, club: club, state: 'cosechado') # planta + 2 = 3 en total
    create(:plant, lote: lote, club: club, state: 'cosechado')
    expect(lote.plants.count).to eq(3)

    # 1 planta por QR
    post "/plants/#{planta.id}/registrar_peso", params: { peso_seco_g: 10 }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    pesaje_qr = lote.pesajes_manicura.find_by(estado: 'borrador')
    post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje_qr.id}/enviar", headers: auth_headers

    # las 2 restantes por batch, en una jornada NUEVA aparte (la anterior ya está enviada →
    # force_new representa la elección "empezar una nueva" del nuevo guard de jornada).
    post "/lotes/#{lote.id}/pesajes_manicura",
         params: { plantas_count: 2, peso_total_g: 20, enviar: true, force_new: true }, headers: auth_headers
    pesaje_batch = lote.pesajes_manicura.where.not(plantas_count: nil).last

    # admin confirma ambos
    delete '/api/users/sign_out'
    sign_in_as(admin)
    post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje_qr.id}/confirmar",
         params: { peso_confirmado_g: 10 }, headers: auth_headers
    expect(lote.reload.estado).to eq('en_manicura') # 1 de 3, todavía no finaliza
    post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje_batch.id}/confirmar",
         params: { peso_confirmado_g: 20 }, headers: auth_headers

    lote.reload
    expect(lote.estado).to eq('curado')
    expect(lote.rendimiento_real_g.to_f).to eq(30.0)
  end

  # registrar_directo: atajo del admin (pesa + confirma en un paso). Acepta pesos
  # individuales y/o carga del resto, contenedor y sede; genera stock y finaliza el lote.
  it 'registrar_directo: el admin pesa individual + resto (promedio) y confirma en un paso con sede' do
    genetica = create(:genetica, club: club)
    lote3 = create(:lote, club: club, sala: sala, estado: 'en_manicura',
                   manicurador: nil, genetica: genetica)
    p1 = create(:plant, lote: lote3, club: club, state: 'cosechado')
    p2 = create(:plant, lote: lote3, club: club, state: 'cosechado')
    p3 = create(:plant, lote: lote3, club: club, state: 'cosechado') # 3 plantas

    delete '/api/users/sign_out'
    sign_in_as(admin)
    expect {
      post "/lotes/#{lote3.id}/pesajes_manicura/registrar_directo",
           params: {
             pesos: [{ plant_id: p1.id, peso_seco_g: 10 }],
             resto: { peso_total_g: 20 },   # 2 restantes → 10g c/u (promedio)
             sede_id: sede.id,
           }, headers: auth_headers, as: :json
    }.to change(Stock, :count).by(1)
    expect(response).to have_http_status(:created), response.body

    stock = Stock.last
    expect(stock.estado).to eq('asignado')
    expect(stock.sede_id).to eq(sede.id)
    expect(stock.cantidad.to_f).to eq(30.0)
    expect(lote3.reload.estado).to eq('curado')

    # El individual NO es promedio; los del resto SÍ, con el peso promedio.
    expect(PesadaPlanta.find_by(plant_id: p1.id).es_promedio).to be(false)
    resto = PesadaPlanta.where(plant_id: [p2.id, p3.id])
    expect(resto.pluck(:es_promedio)).to all(be(true))
    expect(resto.sum(:peso_seco_g).to_f).to eq(20.0)
    expect(p2.reload.peso_seco.to_f).to eq(10.0)
  end

  it 'registrar_directo: bloqueado si el lote tiene un manicura asignado' do
    delete '/api/users/sign_out'
    sign_in_as(admin)
    post "/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
         params: { resto: { plantas_count: 1, peso_total_g: 10 } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  # Al confirmar un pesaje sin elegir contenedor se crea un Stock 'pendiente_asignacion'
  # (sin sede). Ese contenedor debe poder elegirse al confirmar el siguiente pesaje del
  # mismo lote → GET /stocks?lote_id lo lista (el listado general lo excluía) y trae
  # genetica_nombre (que la UI usa para agrupar por genética).
  it 'el contenedor pendiente_asignacion creado al confirmar aparece en GET /stocks?lote_id' do
    genetica = create(:genetica, club: club)
    lote2 = create(:lote, club: club, sala: sala, estado: 'en_manicura',
                   manicurador: manicura, genetica: genetica)
    pesaje = lote2.pesajes_manicura.create!(
      manicurador: manicura, club: club, fecha_pesaje: Date.current,
      estado: 'enviado', enviado_at: Time.current, peso_total_g: 100, plantas_count: 1,
    )

    delete '/api/users/sign_out'
    sign_in_as(admin)
    post "/lotes/#{lote2.id}/pesajes_manicura/#{pesaje.id}/confirmar",
         params: { peso_confirmado_g: 100 }, headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    stock = Stock.where(lote_id: lote2.id).last
    expect(stock.estado).to eq('pendiente_asignacion')

    get '/stocks', params: { lote_id: lote2.id }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    cont = JSON.parse(response.body).find { |s| s['id'] == stock.id }
    expect(cont).to be_present
    expect(cont['genetica_nombre']).to eq(genetica.nombre)
  end

  # Borrar un lote (soft-delete) no debe dejar jornadas de manicura huérfanas: sin lote no se
  # pueden confirmar y rompían el board del admin (set_lote no encontraba el lote → 500).
  context 'borrado de lote con manicura pendiente' do
    it 'Lote#soft_delete! limpia las jornadas pendientes (borrador/enviado)' do
      lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'enviado')
      lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'borrador')
      expect { lote.soft_delete! }
        .to change { PesajeManicura.where(lote_id: lote.id, estado: %w[borrador enviado]).count }.from(2).to(0)
    end

    it 'el board del admin NO muestra pesajes de un lote borrado (join defensivo)' do
      pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current, estado: 'enviado')
      # Simula un huérfano preexistente: se oculta el lote SIN pasar por el cleanup nuevo.
      lote.update_column(:deleted_at, Time.current)
      delete '/api/users/sign_out'
      sign_in_as(admin)
      get '/pesajes_manicura', headers: auth_headers # index_admin
      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |p| p['id'] }
      expect(ids).not_to include(pesaje.id)
    end
  end
end
