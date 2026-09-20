require 'rails_helper'

# Ver crecer la planta (20-sep-2026): cada foto sabe en qué día y semana del lote se sacó, en
# qué fase, de qué planta, con qué etiquetas y qué nota. La pantalla agrupa y filtra con eso;
# no calcula nada.
RSpec.describe 'Fotos de lote — galería', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, start_date: Date.new(2026, 9, 1), estado: 'vegetativo') }

  def imagen(nombre = 'planta.png')
    Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1a\n"), 'image/png', original_filename: nombre)
  end

  before { sign_in_as(admin) }

  it 'sube con fecha, etiquetas y nota, y vuelve con día, semana y fase' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-15', etiquetas: ['Hoja', 'problema'], nota: 'Puntas quemadas' }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body

    expect(json).to include('dia' => 15, 'semana' => 3, 'fase' => 'vegetativo', 'etiquetas' => %w[hoja problema], 'nota' => 'Puntas quemadas')
    expect(json['url']).to be_present
  end

  it 'una foto con fecha vieja lleva la fase de ESE día, no la de hoy' do
    ActsAsTenant.with_tenant(club) do
      LoteEvento.create!(club: club, lote: lote, tipo: 'cambio_estado', estado_anterior: 'enraizado', estado_nuevo: 'vegetativo',
                         registrado_en: Time.zone.local(2026, 9, 8), user: admin, descripcion: 'x')
      lote.update_column(:estado, 'floracion')
      LoteEvento.create!(club: club, lote: lote, tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
                         registrado_en: Time.zone.local(2026, 9, 18), user: admin, descripcion: 'x')
    end
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-03' }, headers: auth_headers
    expect(json['fase']).to eq('enraizado')
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-12' }, headers: auth_headers
    expect(json['fase']).to eq('vegetativo')
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-20' }, headers: auth_headers
    expect(json['fase']).to eq('floracion')
  end

  it 'el botón rápido del teléfono manda `foto` y sin fecha: hoy, etiqueta general' do
    post "/lotes/#{lote.id}/fotos", params: { foto: imagen }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body
    expect(json['tomada_el']).to eq(Time.zone.today.to_s)
    expect(json['etiquetas']).to eq(['general'])
  end

  it 'el listado viene en orden cronológico con lo que la galería necesita' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen('b.png'), tomada_el: '2026-09-20' }, headers: auth_headers
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen('a.png'), tomada_el: '2026-09-03' }, headers: auth_headers

    get "/lotes/#{lote.id}/fotos", headers: auth_headers
    expect(json['fotos'].map { |f| f['dia'] }).to eq([3, 20])
    expect(json['etiquetas'].map { |e| e['clave'] }).to include('hoja', 'cogollo', 'problema')
    expect(json['dia_actual']).to be_a(Integer)
  end

  it 'una etiqueta propia queda para la próxima' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, etiquetas: 'Trichomas' }, headers: auth_headers
    get "/lotes/#{lote.id}/fotos", headers: auth_headers
    expect(json['etiquetas_usadas']).to include('trichomas')
  end

  it 'se puede corregir la nota, la fecha y las etiquetas' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen }, headers: auth_headers
    id = json['id']
    patch "/lotes/#{lote.id}/fotos/#{id}", params: { nota: 'Día 5', tomada_el: '2026-09-05', etiquetas: ['cogollo'] }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json).to include('nota' => 'Día 5', 'dia' => 5, 'etiquetas' => ['cogollo'])
  end

  it 'una planta de otro lote no se acepta' do
    otro  = create(:lote, club: club, sala: sala)
    plant = create(:plant, club: club, lote: otro)
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, plant_id: plant.id }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'la foto con nota entra a la línea de tiempo del lote; la que no, no' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen, tomada_el: '2026-09-10', nota: 'Primeras hojas verdaderas' }, headers: auth_headers
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen('sin.png'), tomada_el: '2026-09-11' }, headers: auth_headers

    get "/lotes/#{lote.id}/historial", headers: auth_headers
    fotos = json['historial'].select { |i| i['kind'] == 'foto' }
    expect(fotos.size).to eq(1)
    expect(fotos.first).to include('titulo' => 'Primeras hojas verdaderas', 'detalle' => 'Día 10')
    expect(fotos.first.dig('metadata', 'imagen_url')).to be_present
  end

  it 'recientes: la última de cada lote en cultivo' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen('1.png'), tomada_el: '2026-09-02' }, headers: auth_headers
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen('2.png'), tomada_el: '2026-09-09' }, headers: auth_headers

    get '/lotes/fotos_recientes', headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json.size).to eq(1)
    expect(json.first).to include('lote_codigo' => lote.codigo, 'dia' => 9)
  end

  it 'otra organización no ve estas fotos' do
    post "/lotes/#{lote.id}/fotos", params: { imagen: imagen }, headers: auth_headers
    otro_club = create(:club)
    otro      = create(:user, :admin, club: otro_club)
    sign_in_as(otro)

    get "/lotes/#{lote.id}/fotos", headers: auth_headers
    expect(response).to have_http_status(:not_found)
    get '/lotes/fotos_recientes', headers: auth_headers
    expect(json).to eq([])
  end
end
