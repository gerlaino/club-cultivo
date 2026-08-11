require 'rails_helper'

# AC: el buscador de Pacientes encuentra por nombre, por apellido y por DNI. El campo dice
# "Buscar por nombre, apellido, DNI…", así que las tres tienen que andar.
RSpec.describe 'GET /api/pacientes — búsqueda', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  let!(:paciente) do
    create(:paciente, club: club, created_by: admin,
           nombre: 'Franco Augusto', apellido: 'CARLINO CURRENTI', dni: '90000027')
  end

  before do
    create(:paciente, club: club, created_by: admin, nombre: 'Otra', apellido: 'Persona', dni: '33111222')
    sign_in_as(admin)
  end

  def buscar(q)
    get '/api/pacientes', params: { query: q }
    JSON.parse(response.body)['data'].map { |p| p['id'] }
  end

  it 'encuentra por apellido' do
    expect(buscar('carlino')).to include(paciente.id)
  end

  it 'encuentra por nombre' do
    expect(buscar('franco')).to include(paciente.id)
  end

  it 'encuentra por DNI completo' do
    expect(buscar('90000027')).to eq([paciente.id])
  end

  it 'encuentra por DNI con puntos, como se escribe a mano' do
    expect(buscar('90.000.027')).to eq([paciente.id])
  end

  # El DNI va cifrado determinístico: admite igualdad exacta, NO `LIKE`. Un parcial no puede
  # resolverse en la base sin descifrar toda la tabla, así que el servidor devuelve vacío — y
  # eso es correcto acá.
  #
  # El problema que veía el usuario era otro: el buscador dispara con cada tecla, así que
  # tipeando un DNI veía "sin resultados" hasta el último dígito. Se resuelve en el frontend,
  # que ya tiene el padrón cargado y filtra por DNI en memoria (ver SociosView).
  it 'con un DNI parcial el servidor no puede resolver: es limitación del cifrado' do
    expect(buscar('900000')).to be_empty
  end

  it 'no trae pacientes que no coinciden' do
    expect(buscar('zzzz')).to be_empty
  end
end
