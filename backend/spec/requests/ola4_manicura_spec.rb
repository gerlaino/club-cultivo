require 'rails_helper'

# Ola 4 — Manicura role: pesadas CRUD, lote scope, stock create, cerrar_curado multi-stock

RSpec.describe 'Ola 4 — Manicura backend', type: :request do
  let(:club)       { create(:club) }
  let(:sede)       { create(:sede, club: club) }
  let(:sala)       { create(:sala, club: club, sede: sede) }
  let(:admin)      { create(:user, :admin,      club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:manicura)   { create(:user, :manicura,   club: club) }
  let(:auditor)    { create(:user, :auditor,    club: club) }
  let(:dispensador){ create(:user, :dispensador, club: club) }

  let(:lote_cosecha) { create(:lote, club: club, sala: sala, estado: 'cosecha') }
  let(:lote_secado)  { create(:lote, club: club, sala: sala, estado: 'secado') }
  let(:lote_curado)  { create(:lote, club: club, sala: sala, estado: 'curado') }
  let(:lote_floracion) { create(:lote, club: club, sala: sala, estado: 'floracion') }

  # ─────────────────────────────────────────────────────────────
  # GET /lotes/:lote_id/pesadas — autorización por rol
  # ─────────────────────────────────────────────────────────────
  describe 'GET /lotes/:lote_id/pesadas' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'devuelve 200 con array' do
        get "/lotes/#{lote_cosecha.id}/pesadas", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_an(Array)
      end
    end

    context 'cultivador del mismo club' do
      before { sign_in_as(cultivador) }
      it 'devuelve 200' do
        get "/lotes/#{lote_cosecha.id}/pesadas", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'manicura del mismo club' do
      before { sign_in_as(manicura) }
      it 'devuelve 200' do
        get "/lotes/#{lote_cosecha.id}/pesadas", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'auditor del mismo club' do
      before { sign_in_as(auditor) }
      it 'devuelve 200 — solo lectura' do
        get "/lotes/#{lote_cosecha.id}/pesadas", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'dispensador (sin acceso)' do
      before { sign_in_as(dispensador) }
      it 'devuelve 403' do
        get "/lotes/#{lote_cosecha.id}/pesadas", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'lote de otro club' do
      let(:otro_club) { create(:club) }
      let(:otro_admin) { create(:user, :admin, club: otro_club) }
      before { sign_in_as(otro_admin) }
      it 'devuelve 404' do
        get "/lotes/#{lote_cosecha.id}/pesadas", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /lotes/:lote_id/pesadas — schema real (fase_origen, fase_destino, peso_*_g)
  # ─────────────────────────────────────────────────────────────
  describe 'POST /lotes/:lote_id/pesadas' do
    let(:pesada_cosecha_params) do
      { pesada: { fase_origen: 'cosecha', fase_destino: 'secado', peso_humedo_g: 850.0, notas: 'primera pesada' } }
    end

    context 'manicura — lote en cosecha (cosecha → secado)' do
      before { sign_in_as(manicura) }

      it 'devuelve 201 con los campos correctos' do
        post "/lotes/#{lote_cosecha.id}/pesadas", params: pesada_cosecha_params, headers: auth_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['fase_origen']).to eq('cosecha')
        expect(body['fase_destino']).to eq('secado')
        expect(body['peso_humedo_g']).to eq(850.0)
        expect(body['notas']).to eq('primera pesada')
      end
    end

    context 'manicura — lote en secado (secado → curado, con manicurado)' do
      before { sign_in_as(manicura) }

      it 'devuelve 201' do
        params = { pesada: { fase_origen: 'secado', fase_destino: 'curado', peso_seco_g: 600.0, manicurado: true } }
        post "/lotes/#{lote_secado.id}/pesadas", params: params, headers: auth_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['peso_seco_g']).to eq(600.0)
        expect(body['manicurado']).to be true
      end
    end

    context 'manicura — lote en curado (curado → finalizado)' do
      before { sign_in_as(manicura) }

      it 'devuelve 201' do
        params = { pesada: { fase_origen: 'curado', fase_destino: 'finalizado', peso_curado_g: 550.0 } }
        post "/lotes/#{lote_curado.id}/pesadas", params: params, headers: auth_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['peso_curado_g']).to eq(550.0)
      end
    end

    context 'cultivador del mismo club' do
      before { sign_in_as(cultivador) }
      it 'devuelve 201' do
        post "/lotes/#{lote_cosecha.id}/pesadas", params: pesada_cosecha_params, headers: auth_headers
        expect(response).to have_http_status(:created)
      end
    end

    context 'admin del mismo club' do
      before { sign_in_as(admin) }
      it 'devuelve 201' do
        post "/lotes/#{lote_cosecha.id}/pesadas", params: pesada_cosecha_params, headers: auth_headers
        expect(response).to have_http_status(:created)
      end
    end

    context 'auditor (solo lectura)' do
      before { sign_in_as(auditor) }
      it 'devuelve 403' do
        post "/lotes/#{lote_cosecha.id}/pesadas", params: pesada_cosecha_params, headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'fase_origen inválida' do
      before { sign_in_as(manicura) }
      it 'devuelve 422' do
        params = { pesada: { fase_origen: 'inventada', fase_destino: 'secado', peso_humedo_g: 500.0 } }
        post "/lotes/#{lote_cosecha.id}/pesadas", params: params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'falta peso_humedo_g cuando fase_destino=secado' do
      before { sign_in_as(manicura) }
      it 'devuelve 422' do
        params = { pesada: { fase_origen: 'cosecha', fase_destino: 'secado' } }
        post "/lotes/#{lote_cosecha.id}/pesadas", params: params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'falta peso_seco_g cuando fase_destino=curado' do
      before { sign_in_as(manicura) }
      it 'devuelve 422' do
        params = { pesada: { fase_origen: 'secado', fase_destino: 'curado' } }
        post "/lotes/#{lote_secado.id}/pesadas", params: params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /lotes/:lote_id/pesadas/:id
  # ─────────────────────────────────────────────────────────────
  describe 'DELETE /lotes/:lote_id/pesadas/:id' do
    let!(:pesada) do
      lote_cosecha.pesadas.create!(
        fase_origen: 'cosecha', fase_destino: 'secado',
        peso_humedo_g: 300.0,
        registrado_por: manicura, registrado_at: Time.current
      )
    end

    context 'admin' do
      before { sign_in_as(admin) }
      it 'devuelve 204' do
        delete "/lotes/#{lote_cosecha.id}/pesadas/#{pesada.id}", headers: auth_headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'manicura (no puede borrar pesadas)' do
      before { sign_in_as(manicura) }
      it 'devuelve 403' do
        delete "/lotes/#{lote_cosecha.id}/pesadas/#{pesada.id}", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'cultivador (no puede borrar pesadas)' do
      before { sign_in_as(cultivador) }
      it 'devuelve 403' do
        delete "/lotes/#{lote_cosecha.id}/pesadas/#{pesada.id}", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /lotes — scope manicura (cosecha + secado + curado)
  # ─────────────────────────────────────────────────────────────
  describe 'GET /lotes — scope para manicura' do
    before do
      lote_cosecha; lote_secado; lote_curado; lote_floracion
    end

    context 'manicura sin filtro' do
      before { sign_in_as(manicura) }
      it 'devuelve solo secado + manicura_pendiente (no cosecha, no curado)' do
        get '/lotes', headers: auth_headers
        body = JSON.parse(response.body)
        estados = body.map { |l| l['estado'] }.uniq.sort
        expect(estados).to match_array(%w[secado].sort)
      end
    end

    context 'manicura con filtro estado=secado' do
      before { sign_in_as(manicura) }
      it 'devuelve solo lotes en secado' do
        get '/lotes', params: { estado: 'secado' }, headers: auth_headers
        body = JSON.parse(response.body)
        expect(body.map { |l| l['estado'] }.uniq).to eq(%w[secado])
      end
    end

    context 'manicura con filtro estado=floracion' do
      before { sign_in_as(manicura) }
      it 'devuelve array vacío — floracion fuera de scope' do
        get '/lotes', params: { estado: 'floracion' }, headers: auth_headers
        expect(JSON.parse(response.body)).to be_empty
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /lotes/:id — manicura solo puede ver cosecha/secado/curado
  # ─────────────────────────────────────────────────────────────
  describe 'GET /lotes/:id — scope individual para manicura' do
    context 'manicura accede a lote en cosecha' do
      before { sign_in_as(manicura) }
      it 'devuelve 404 (cosecha ya no está en scope de manicura)' do
        get "/lotes/#{lote_cosecha.id}", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'manicura accede a lote en secado' do
      before { sign_in_as(manicura) }
      it 'devuelve 200' do
        get "/lotes/#{lote_secado.id}", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'manicura accede a lote en floracion' do
      before { sign_in_as(manicura) }
      it 'devuelve 404' do
        get "/lotes/#{lote_floracion.id}", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /stocks — manicura puede crear stocks
  # ─────────────────────────────────────────────────────────────
  describe 'POST /stocks' do
    let(:stock_params) do
      {
        stock: {
          origen: 'lote',
          lote_id: lote_curado.id,
          forma_producto: 'flor_seca',
          unidad: 'g',
          cantidad: 200.0,
          sede_id: sede.id,
        }
      }
    end

    context 'manicura del mismo club' do
      before { sign_in_as(manicura) }
      it 'devuelve 201 y crea el stock' do
        post '/stocks', params: stock_params, headers: auth_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['origen']).to eq('lote')
        expect(body['cantidad']).to eq(200.0)
      end
    end

    context 'cultivador (no puede crear stocks)' do
      before { sign_in_as(cultivador) }
      it 'devuelve 403' do
        post '/stocks', params: stock_params, headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'dispensador (no puede crear stocks)' do
      before { sign_in_as(dispensador) }
      it 'devuelve 403' do
        post '/stocks', params: stock_params, headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /stocks — acceso por rol
  # ─────────────────────────────────────────────────────────────
  describe 'GET /stocks' do
    context 'manicura' do
      before { sign_in_as(manicura) }
      it 'devuelve 200' do
        get '/stocks', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'dispensador' do
      before { sign_in_as(dispensador) }
      it 'devuelve 200' do
        get '/stocks', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'cultivador (sin acceso a stocks)' do
      before { sign_in_as(cultivador) }
      it 'devuelve 403' do
        get '/stocks', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /lotes/:id/cerrar_curado — formato nuevo (peso_curado_g + stocks array)
  # ─────────────────────────────────────────────────────────────
  describe 'POST /lotes/:id/cerrar_curado (multi-stock)' do
    let(:cerrar_params) do
      {
        pesada: { fase_origen: 'curado', fase_destino: 'finalizado', peso_curado_g: 400.0 },
        stocks: [
          { sede_id: sede.id, forma_producto: 'flor_seca', cantidad: 200.0, unidad: 'g' },
          { sede_id: sede.id, forma_producto: 'hash',      cantidad: 150.0, unidad: 'g' },
        ]
      }
    end

    context 'admin cierra curado con múltiples stocks' do
      before { sign_in_as(admin) }

      it 'devuelve 201 con lote finalizado, pesada y stocks' do
        post "/lotes/#{lote_curado.id}/cerrar_curado", params: cerrar_params, headers: auth_headers
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['lote']['estado']).to eq('finalizado')
        expect(body['pesada']['peso_curado_g']).to eq(400.0)
        expect(body['stocks'].length).to eq(2)
        expect(body['stocks'].map { |s| s['forma_producto'] }).to match_array(%w[flor_seca hash])
      end

      it 'transiciona el lote a finalizado en DB' do
        post "/lotes/#{lote_curado.id}/cerrar_curado", params: cerrar_params, headers: auth_headers
        expect(lote_curado.reload.estado).to eq('finalizado')
      end

      it 'crea 2 stocks en base de datos' do
        expect {
          post "/lotes/#{lote_curado.id}/cerrar_curado", params: cerrar_params, headers: auth_headers
        }.to change(Stock, :count).by(2)
      end
    end

    context 'stock excede peso_curado_g disponible' do
      before { sign_in_as(admin) }

      it 'devuelve 422 y no modifica el lote' do
        overflow = {
          pesada: { fase_origen: 'curado', fase_destino: 'finalizado', peso_curado_g: 100.0 },
          stocks: [{ sede_id: sede.id, forma_producto: 'flor_seca', cantidad: 200.0, unidad: 'g' }]
        }
        post "/lotes/#{lote_curado.id}/cerrar_curado", params: overflow, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(lote_curado.reload.estado).to eq('curado')
      end
    end

    context 'lote no está en curado' do
      before { sign_in_as(admin) }
      it 'devuelve 422' do
        post "/lotes/#{lote_cosecha.id}/cerrar_curado", params: cerrar_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'manicura cierra curado' do
      before { sign_in_as(manicura) }
      it 'devuelve 404 (curado fuera del scope de manicura — no accede al recurso)' do
        post "/lotes/#{lote_curado.id}/cerrar_curado", params: cerrar_params, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'cultivador (no puede cerrar curado)' do
      before { sign_in_as(cultivador) }
      it 'devuelve 403' do
        post "/lotes/#{lote_curado.id}/cerrar_curado", params: cerrar_params, headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
