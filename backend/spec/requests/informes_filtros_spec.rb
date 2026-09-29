require 'rails_helper'

# Los filtros viajan igual a la pantalla y a la descarga, y un informe filtrado lo dice.
RSpec.describe 'Informes: filtros por request', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { ActsAsTenant.with_tenant(club) { create(:sede, club: club, created_by: admin) } }

  before { sign_in_as(admin) }

  it 'el JSON dice qué se filtró' do
    ActsAsTenant.with_tenant(club) do
      Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop', forma_producto: 'flor_seca', unidad: 'g', cantidad: 80)
    end
    get '/api/informes/produccion', params: { origen: 'externo' }

    body = JSON.parse(response.body)
    expect(body['filtros']).to eq('activo' => true, 'descripcion' => 'sólo stock externo')
    expect(body['externo']['stocks'].size).to eq(1)
  end

  it 'la descarga en PDF acepta los mismos filtros' do
    get '/api/informes/dispensaciones.pdf', params: { origen: 'propio', formas: ['flor_seca'] }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/pdf')
  end

  it 'el Excel dice que está filtrado' do
    get '/api/informes/produccion.xlsx', params: { origen: 'externo' }
    expect(response).to have_http_status(:ok)
  end

  describe 'GET /informes/filtros (opciones)' do
    it 'ofrece los lotes y pacientes de la organización, con el DNI parcial' do
      l, p = ActsAsTenant.with_tenant(club) do
        [create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin)),
         create(:paciente, club: club, created_by: admin, dni: '30111222')]
      end
      get '/api/informes/filtros'

      body = JSON.parse(response.body)
      expect(body['lotes'].map { |x| x['id'] }).to eq([l.id])
      expect(body['pacientes'].first).to include('id' => p.id, 'dni_ultimos_3' => '222')
      expect(body['pacientes'].first.keys).not_to include('dni')
    end

    it 'aislamiento: no ofrece lotes ni pacientes de otra organización' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ActsAsTenant.with_tenant(otro) do
        os = create(:sede, club: otro, created_by: otro_admin)
        create(:lote, club: otro, sala: create(:sala, club: otro, sede: os, created_by: otro_admin))
        create(:paciente, club: otro, created_by: otro_admin)
      end
      get '/api/informes/filtros'

      body = JSON.parse(response.body)
      expect(body['lotes']).to be_empty
      expect(body['pacientes']).to be_empty
    end
  end

  it 'aislamiento: filtrar por un paciente ajeno no trae nada (ni lo propio)' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) { create(:paciente, club: otro, created_by: create(:user, :admin, club: otro)) }
    get '/api/informes/dispensaciones', params: { paciente_ids: [ajeno.id] }

    body = JSON.parse(response.body)
    expect(body['pacientes']).to be_empty
    expect(body['filtros']['activo']).to be(true)
  end
end

RSpec.describe 'GET /informes/stock', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { ActsAsTenant.with_tenant(club) { create(:sede, club: club, created_by: admin) } }

  before do
    ActsAsTenant.with_tenant(club) do
      Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop', forma_producto: 'flor_seca', unidad: 'g', cantidad: 80)
    end
    sign_in_as(admin)
  end

  it 'responde en pantalla, PDF y Excel con los mismos filtros' do
    get '/api/informes/stock', params: { origen: 'externo' }
    body = JSON.parse(response.body)
    expect(body['stocks'].size).to eq(1)
    expect(body['filtros']['descripcion']).to eq('sólo stock externo')

    get '/api/informes/stock.pdf', params: { origen: 'externo' }
    expect(response.media_type).to eq('application/pdf')
    get '/api/informes/stock.xlsx'
    expect(response).to have_http_status(:ok)
  end

  it 'aislamiento: no muestra el stock de otra organización' do
    otro = create(:club)
    oa   = create(:user, :admin, club: otro)
    ActsAsTenant.with_tenant(otro) do
      os = create(:sede, club: otro, created_by: oa)
      Stock.create!(sede: os, origen: 'compra_externa', proveedor: 'Ajeno', forma_producto: 'flor_seca', unidad: 'g', cantidad: 999)
    end
    get '/api/informes/stock'
    expect(JSON.parse(response.body)['stocks'].map { |s| s['de_donde'] }).to eq(['Coop'])
  end
end
