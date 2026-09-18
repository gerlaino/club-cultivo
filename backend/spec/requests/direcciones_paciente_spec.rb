require 'rails_helper'

# AC (Germán, 17-sep-2026): en la ficha del paciente, una solapa Direcciones con todas las
# direcciones guardadas, agregar más, e indicar una por defecto que el modal preselecciona.
RSpec.describe 'Direcciones del paciente', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin, domicilio_calle: 'Av. Siempreviva', domicilio_altura: '742', domicilio_ciudad: 'CABA') }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)
  def crear(attrs) = post("/api/pacientes/#{paciente.id}/direcciones", params: { direccion: attrs }, as: :json)

  it 'la primera que se carga queda por defecto sola' do
    crear(etiqueta: 'Trabajo', calle: 'Lavalle', altura: '400', ciudad: 'CABA')

    expect(response).to have_http_status(:created)
    expect(json['por_defecto']).to be(true)
    expect(json['texto']).to       eq('Lavalle 400, CABA')
  end

  it 'la segunda no, y marcarla por defecto desmarca la anterior' do
    crear(etiqueta: 'Trabajo', calle: 'Lavalle', altura: '400', ciudad: 'CABA')
    primera = json['id']
    crear(etiqueta: 'Casa de la madre', calle: 'Directorio', altura: '1602', ciudad: 'CABA')
    segunda = json['id']
    expect(json['por_defecto']).to be(false)

    patch "/api/pacientes/#{paciente.id}/direcciones/#{segunda}/por_defecto"

    get "/api/pacientes/#{paciente.id}/direcciones"
    por_defecto = json['guardadas'].select { |d| d['por_defecto'] }.map { |d| d['id'] }
    expect(por_defecto).to eq([segunda])
    expect(json['guardadas'].map { |d| d['id'] }.first).to eq(segunda)   # la por defecto va primera
    expect(json['guardadas'].find { |d| d['id'] == primera }['por_defecto']).to be(false)
  end

  it 'se edita y se borra; al borrar la por defecto, otra pasa a serlo' do
    crear(etiqueta: 'Trabajo', calle: 'Lavalle', altura: '400', ciudad: 'CABA')
    trabajo = json['id']
    crear(etiqueta: 'Club', calle: 'Corrientes', altura: '1', ciudad: 'CABA')
    club_id = json['id']

    patch "/api/pacientes/#{paciente.id}/direcciones/#{trabajo}", params: { direccion: { piso: '3', depto: 'B' } }, as: :json
    expect(json['texto']).to eq('Lavalle 400, Piso 3 Depto B, CABA')

    delete "/api/pacientes/#{paciente.id}/direcciones/#{trabajo}"
    expect(response).to have_http_status(:no_content)

    get "/api/pacientes/#{paciente.id}/direcciones"
    expect(json['guardadas'].map { |d| [d['id'], d['por_defecto']] }).to eq([[club_id, true]])
  end

  it 'sin calle no se guarda' do
    crear(etiqueta: 'Nada', calle: '')

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'no se toca la dirección de un paciente de otra organización' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) { create(:paciente, club: otro, created_by: create(:user, :admin, club: otro)) }

    get "/api/pacientes/#{ajeno.id}/direcciones"

    expect(response).to have_http_status(:not_found)
  end

  # La migración convierte la vieja dirección de envío (`envio_*`) en la primera guardada.
  it 'el alta con «dirección de entrega distinta» la guarda con nombre' do
    post '/api/pacientes', params: { paciente: { nombre: 'Ana', apellido: 'Test', dni: '30111222', fecha_nacimiento: '1990-01-01',
                                                 envio_calle: 'Balbastro', envio_altura: '1265', envio_ciudad: 'CABA', envio_etiqueta: 'Hobby' } }, as: :json

    expect(response).to have_http_status(:created), response.body
    p = Paciente.find(json['data']['id'])
    expect(p.direcciones_guardadas.first.slice(:etiqueta, :calle, :por_defecto)).to eq('etiqueta' => 'Hobby', 'calle' => 'Balbastro', 'por_defecto' => true)
  end
end
