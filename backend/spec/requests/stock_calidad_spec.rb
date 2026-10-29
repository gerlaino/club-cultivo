require 'rails_helper'

# AC (29-oct-2026, pedido de Javi; Germán: «obligatorio a partir de ahora, poder agregarlo al editar
# el stock» y «SOLO desde Otro quiero que se pueda producir además de flor_seca, cualquiera de su
# calidad»):
#   1. La flor seca nueva —externa o de una cosecha— nace con su calidad: Altos, Medios, Bajos u Otro.
#   2. Los stocks viejos (sin calidad) se siguen editando, y la calidad se les agrega desde la edición.
#   3. Se produce desde flor seca de cualquier calidad y desde lo cargado como «Otro» (en gramos);
#      desde ninguna otra forma.
RSpec.describe 'Calidad de la flor seca', type: :request do
  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:genetica) { create(:genetica, club: club) }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)
  def t(&) = ActsAsTenant.with_tenant(club, &)
  def alta(extra = {})
    post '/stocks', params: { stock: { origen: 'compra_externa', proveedor: 'Vivero', forma_producto: 'flor_seca',
                                       unidad: 'g', cantidad: 100, genetica_id: genetica.id, sede_id: sede.id }.merge(extra) },
                    headers: auth_headers, as: :json
  end

  describe 'alta de stock' do
    it 'flor seca sin calidad: se rechaza y dice qué falta' do
      expect { alta }.not_to change(Stock, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to match(/calidad/i)
    end

    it 'flor seca con calidad: nace con ella y la devuelve con su nombre' do
      alta(calidad: 'medios')
      expect(response).to have_http_status(:created)
      expect(json['calidad']).to eq('medios')
      expect(json['calidad_label']).to eq('Medios')
      expect(t { Stock.find(json['id']).calidad }).to eq('medios')
    end

    it 'una calidad que no existe se rechaza' do
      alta(calidad: 'premium')
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '«Otro» pide en la descripción qué es' do
      alta(calidad: 'otro')
      expect(response).to have_http_status(:unprocessable_entity)

      alta(calidad: 'otro', descripcion: 'Restos de prerolls')
      expect(response).to have_http_status(:created)
    end

    it 'lo que no es flor seca no la pide (y no la guarda)' do
      alta(forma_producto: 'preroll', unidad: 'un', calidad: 'altos')
      expect(response).to have_http_status(:created)
      expect(json['calidad']).to be_nil
    end

    it 'el uso personal no la pide' do
      personal = create(:club, plan: 'personal')
      yo = create(:user, :admin, club: personal)
      gen, sede_p = ActsAsTenant.with_tenant(personal) { [create(:genetica, club: personal), create(:sede, club: personal, created_by: yo)] }
      sign_in_as(yo)

      post '/stocks', params: { stock: { origen: 'compra_externa', proveedor: 'Vivero', forma_producto: 'flor_seca',
                                         unidad: 'g', cantidad: 10, genetica_id: gen.id, sede_id: sede_p.id } },
                      headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
    end
  end

  describe 'edición' do
    let!(:viejo) { t { create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 50) } }

    it 'un stock viejo sin calidad se sigue editando sin ella' do
      patch "/stocks/#{viejo.id}", params: { stock: { precio_sugerido_ars: 900 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(viejo.reload.precio_sugerido_ars.to_f).to eq(900.0)
    end

    it 'y se le agrega la calidad desde la edición' do
      patch "/stocks/#{viejo.id}", params: { stock: { calidad: 'bajos' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(viejo.reload.calidad).to eq('bajos')
      expect(viejo.etiqueta).to include('Bajos')
    end

    it 'otra organización no lo toca' do
      ajeno = create(:club)
      sign_in_as(create(:user, :admin, club: ajeno))
      patch "/stocks/#{viejo.id}", params: { stock: { calidad: 'altos' } }, headers: auth_headers, as: :json
      expect(response.status).to be_in([403, 404])
      expect(viejo.reload.calidad).to be_nil
    end
  end

  describe 'frasco nuevo de una cosecha' do
    let(:sala) { create(:sala, club: club, sede: sede, created_by: admin) }
    let(:lote) { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 2, genetica: genetica) }
    let!(:plantas) { 2.times.map { |i| create(:plant, lote: lote, state: 'secado', nombre: "P#{i}") } }

    before { t { lote.update_columns(estado: 'en_manicura', sala_id: nil, sede_id: sede.id) } }

    def jornada_enviada(g)
      post "/lotes/#{lote.id}/pesajes_manicura", params: { peso_total_g: g, enviar: true, force_new: true }, headers: auth_headers, as: :json
      t { lote.pesajes_manicura.order(:id).last }
    end

    def confirmar(j, g, extra = {})
      post "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/confirmar", params: { peso_confirmado_g: g }.merge(extra), headers: auth_headers, as: :json
    end

    it 'al confirmar a un frasco nuevo sin calidad, se rechaza y no se crea nada' do
      j = jornada_enviada(100)
      expect { confirmar(j, 100) }.not_to change(Stock, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(j.reload.estado).not_to eq('confirmado')
    end

    it 'con calidad, el frasco nuevo nace con ella' do
      confirmar(jornada_enviada(100), 100, calidad: 'altos')
      expect(response).to have_http_status(:ok)
      expect(t { Stock.where(lote_id: lote.id).sole.calidad }).to eq('altos')
    end

    it '«Otro» en un solo frasco nuevo: va con lo que es' do
      confirmar(jornada_enviada(100), 100, calidad: 'otro')
      expect(response).to have_http_status(:unprocessable_entity)
      confirmar(t { lote.pesajes_manicura.order(:id).last }, 100, calidad: 'otro', descripcion: 'Recortes de manicura')
      expect(response).to have_http_status(:ok)
      expect(t { Stock.where(lote_id: lote.id).sole }).to have_attributes(calidad: 'otro', descripcion: 'Recortes de manicura')
    end

    it 'repartido en dos frascos, cada uno con su calidad' do
      confirmar(jornada_enviada(100), 100, destinos: [{ gramos: 70, calidad: 'altos' }, { gramos: 30, calidad: 'bajos' }])
      expect(response).to have_http_status(:ok)
      expect(t { Stock.where(lote_id: lote.id).pluck(:calidad, :cantidad).map { |c, g| [c, g.to_f] } })
        .to contain_exactly(['altos', 70.0], ['bajos', 30.0])
    end

    it 'sumar a un frasco viejo sin calidad sigue andando (lo viejo no se bloquea)' do
      frasco = t { create(:stock, club: club, sede: sede, lote: lote, cantidad: 0) }
      confirmar(jornada_enviada(100), 100, stock_id: frasco.id)
      expect(response).to have_http_status(:ok)
      expect(frasco.reload.cantidad.to_f).to eq(100.0)
    end

    it 'registrado directo por el admin a un frasco nuevo: también la pide' do
      post "/lotes/#{lote.id}/pesajes_manicura/registrar_directo", params: { resto: { peso_total_g: 80 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to match(/calidad/i)

      post "/lotes/#{lote.id}/pesajes_manicura/registrar_directo", params: { resto: { peso_total_g: 80 }, calidad: 'medios' }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(t { Stock.find(json['stock_id']).calidad }).to eq('medios')
    end
  end

  describe 'producir' do
    def producir(stock, gramos: 10)
      post "/stocks/#{stock.id}/producir",
           params: { gramos_usados: gramos, forma_producto: 'comestible', cantidad_producida: 5, unidad: 'un' },
           headers: auth_headers, as: :json
    end

    def externo(attrs) = t { create(:stock, :externo, club: club, sede: sede, cantidad: 100, **attrs) }

    it 'desde flor seca de cualquier calidad' do
      %w[altos medios bajos].each do |c|
        producir(externo(forma_producto: 'flor_seca', calidad: c))
        expect(response).to have_http_status(:created), "#{c}: #{response.body}"
      end
      producir(externo(forma_producto: 'flor_seca', calidad: 'otro', descripcion: 'Recortes'))
      expect(response).to have_http_status(:created)
    end

    it 'desde lo cargado como «Otro» (prerolls sobrantes abiertos, en gramos)' do
      otro = externo(forma_producto: 'otro', unidad: 'g', descripcion: 'Prerolls abiertos')
      producir(otro, gramos: 40)
      expect(response).to have_http_status(:created)
      expect(otro.reload.cantidad.to_f).to eq(60.0)
      expect(t { Stock.find(json['id']).producido_desde_stock_id }).to eq(otro.id)
    end

    it '«Otro» de un lote: el elaborado sigue siendo del lote' do
      lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin))
      otro = t { create(:stock, club: club, sede: sede, lote: lote, origen: 'derivado_lote', forma_producto: 'otro', unidad: 'g', cantidad: 50, lote_origen_consumido_g: 50, es_split: true) }
      producir(otro)
      expect(response).to have_http_status(:created)
      expect(t { Stock.find(json['id']) }).to have_attributes(origen: 'derivado_lote', lote_id: lote.id)
    end

    it 'desde ninguna otra forma (preroll, hash), ni desde «Otro» en unidades' do
      [externo(forma_producto: 'preroll', unidad: 'un'),
       externo(forma_producto: 'hash', unidad: 'g'),
       externo(forma_producto: 'otro', unidad: 'un')].each do |st|
        expect { producir(st) }.not_to change(Stock, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'la pantalla sabe si puede producir (`materia_prima`) con el mismo criterio' do
      get "/stocks/#{externo(forma_producto: 'otro', unidad: 'g', descripcion: 'x').id}", headers: auth_headers
      expect(json.fetch('data', json)['materia_prima']).to be(true)
      get "/stocks/#{externo(forma_producto: 'preroll', unidad: 'un').id}", headers: auth_headers
      expect(json.fetch('data', json)['materia_prima']).to be(false)
    end
  end

  it '/me manda las calidades, si son obligatorias y de qué se produce' do
    get '/me', headers: auth_headers
    reglas = json['reglas_stock'] || json.dig('user', 'reglas_stock')
    expect(reglas['calidades'].keys).to eq(%w[altos medios bajos otro])
    expect(reglas['calidad_obligatoria']).to be(true)
    expect(reglas['formas_que_producen']).to eq(%w[flor_seca otro])
  end

  it '/me en uso personal no ofrece calidades' do
    personal = create(:club, plan: 'personal')
    sign_in_as(create(:user, :admin, club: personal))
    get '/me', headers: auth_headers
    reglas = json['reglas_stock'] || json.dig('user', 'reglas_stock')
    expect(reglas).to include('calidades' => {}, 'calidad_obligatoria' => false)
  end
end
