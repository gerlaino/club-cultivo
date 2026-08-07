require 'rails_helper'

# Categorías contables editables por club (Finanzas — Bloque 1):
# - Se siembran solas la primera vez (desde los enums legacy).
# - Sólo admin escribe; auditor lee; otros roles no acceden.
# - Las categorías de sistema no se borran; sí se desactivan.
# - Aislamiento por club: no se ven categorías de otro club.
RSpec.describe 'Categorías contables', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def sembrar_arbol! = ActsAsTenant.with_tenant(club) { Finanzas::SembrarCatalogo.new(club).call(con_arbol: true) }

  describe 'GET /categorias_contables' do
    before { sign_in_as(admin) }

    # El club arranca CON categorías. Antes arrancaba en limpio y el primer gasto se cargaba
    # contra un combo vacío: había que inventar una taxonomía en el momento, cada uno la
    # inventaba distinta, y después no se podía filtrar ni sacar un informe que cerrara.
    it 'el club arranca con categorías para elegir, no con un combo vacío' do
      get '/categorias_contables', headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).not_to be_empty
      expect(club.unidades_negocio).to exist
    end

    it 'el árbol-guía (opt-in) tiene madres con subcategorías que heredan comportamiento' do
      sembrar_arbol!
      get '/categorias_contables', headers: auth_headers, as: :json
      body   = JSON.parse(response.body)
      insumos = body.find { |c| c['comportamiento'] == 'insumo' }
      fert    = insumos['subcategorias'].find { |s| s['nombre'] == 'Fertilizante' }
      expect(fert['clave_efectiva']).to eq('insumo')
      aporte = body.find { |c| c['clave_efectiva'] == 'aporte_socio' }
      expect(aporte).to include('tipo' => 'ingreso', 'es_sistema' => true)
    end

    it 'una subcategoría insumo deriva el string legacy en el movimiento' do
      sembrar_arbol!
      fert = club.categorias_contables.find_by(nombre: 'Fertilizante')
      mov = club.movimientos_contables.create!(created_by: admin, tipo: 'egreso',
        categoria_contable: fert, descripcion: 'Test', monto_ars: 1000, fecha: Time.zone.today)
      expect(mov.categoria).to eq('insumo')
      expect(mov.unidad_negocio.tipo).to eq('cultivo')
    end

    it 'filtra por tipo' do
      sembrar_arbol!
      get '/categorias_contables?tipo=ingreso', headers: auth_headers
      tipos = JSON.parse(response.body).map { |c| c['tipo'] }.uniq
      expect(tipos).to eq(['ingreso'])
    end
  end

  describe 'POST /categorias_contables' do
    before { sign_in_as(admin) }

    it 'crea una categoría propia del club' do
      unidad = club.unidades_negocio.create!(nombre: 'Bar', tipo: 'bar')
      expect {
        post '/categorias_contables',
             params: { categoria_contable: { nombre: 'Mercadería bar', tipo: 'egreso', unidad_negocio_id: unidad.id, color: '#8a4b2f' } },
             headers: auth_headers, as: :json
      }.to change { club.categorias_contables.count }.by(1)
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include('nombre' => 'Mercadería bar', 'es_sistema' => false)
      expect(body['unidad_negocio']).to include('nombre' => 'Bar')
    end

    it 'rechaza tipo inválido con 422' do
      post '/categorias_contables',
           params: { categoria_contable: { nombre: 'X', tipo: 'raro' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /categorias_contables/:id' do
    before { sign_in_as(admin) }

    it 'no permite borrar una categoría de sistema' do
      sembrar_arbol! # las de sistema solo existen si se siembra el árbol-guía
      cat = club.categorias_contables.find_by(clave_sistema: 'insumo')
      delete "/categorias_contables/#{cat.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(cat.reload).to be_present
    end

    it 'borra una categoría propia sin movimientos' do
      cat = club.categorias_contables.create!(nombre: 'Temporal', tipo: 'egreso')
      delete "/categorias_contables/#{cat.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:no_content)
    end

    it 'no borra una categoría asignada a un insumo (evita dejarlo huérfano)' do
      cat = club.categorias_contables.create!(nombre: 'Con insumo', tipo: 'egreso')
      club.insumos.create!(nombre: 'Fertilizante', unidad_medida: 'litro', categoria_contable: cat)
      delete "/categorias_contables/#{cat.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'autorización' do
    it 'un dispensador no puede leer categorías' do
      disp = create(:user, :dispensador, club: club)
      sign_in_as(disp)
      get '/categorias_contables', headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'un auditor lee pero no escribe' do
      auditor = create(:user, :auditor, club: club)
      sign_in_as(auditor)
      get '/categorias_contables', headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      post '/categorias_contables',
           params: { categoria_contable: { nombre: 'X', tipo: 'egreso' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'aislamiento por club' do
    it 'no expone categorías de otro club' do
      otro_club  = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      ajena = ActsAsTenant.with_tenant(otro_club) { otro_club.categorias_contables.create!(nombre: 'Ajena', tipo: 'egreso') }

      sign_in_as(admin)
      get '/categorias_contables', headers: auth_headers, as: :json
      ids = JSON.parse(response.body).map { |c| c['id'] }
      expect(ids).not_to include(ajena.id)
    end
  end
end
