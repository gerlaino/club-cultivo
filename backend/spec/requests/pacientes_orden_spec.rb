require 'rails_helper'

# AC: el padrón se lista ALFABÉTICAMENTE. Se entra a /pacientes a buscar a alguien, no a ver
# quién se cargó último: con `created_at desc` la lista arrancaba por el alta más reciente y
# encontrar a una persona era recorrerla entera.
RSpec.describe 'GET /api/pacientes — orden del padrón', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def paciente(nombre, apellido)
    create(:paciente, club: club, created_by: admin, nombre: nombre, apellido: apellido)
  end

  def apellidos(params = {})
    get '/api/pacientes', params: params
    JSON.parse(response.body)['data'].map { |p| p['apellido'] }
  end

  before { sign_in_as(admin) }

  it 'ordena por apellido de la A a la Z, sin importar el orden de alta' do
    paciente('Ana',   'Zapata')
    paciente('Bruno', 'Acosta')
    paciente('Caro',  'Medina')

    expect(apellidos).to eq(%w[Acosta Medina Zapata])
  end

  it 'desempata los homónimos por nombre' do
    # En un padrón con varios "Casuso" el apellido solo deja el orden librado al azar.
    paciente('Natanael', 'Casuso')
    paciente('Ariel',    'Casuso')
    paciente('Marcos',   'Casuso')

    get '/api/pacientes'
    expect(JSON.parse(response.body)['data'].map { |p| p['nombre'] }).to eq(%w[Ariel Marcos Natanael])
  end

  it 'el alfabético también manda entre páginas, no sólo dentro de una' do
    paciente('Ana',   'Zapata')
    paciente('Bruno', 'Acosta')
    paciente('Caro',  'Medina')

    expect(apellidos(limite: 2, pagina: 1)).to eq(%w[Acosta Medina])
    expect(apellidos(limite: 2, pagina: 2)).to eq(%w[Zapata])
  end

  describe 'sigue siendo configurable' do
    it 'acepta ordenar por fecha de alta, con lo más nuevo primero' do
      paciente('Ana',   'Zapata')
      paciente('Bruno', 'Acosta')

      expect(apellidos(orden: 'created_at')).to eq(%w[Acosta Zapata])
    end

    it 'acepta invertir el alfabético' do
      paciente('Ana',   'Zapata')
      paciente('Bruno', 'Acosta')

      expect(apellidos(dir: 'desc')).to eq(%w[Zapata Acosta])
    end

    it 'ignora un campo de orden que no está en la allowlist' do
      paciente('Ana',   'Zapata')
      paciente('Bruno', 'Acosta')

      # Cae al alfabético por defecto en vez de interpolar lo que venga por parámetro.
      expect(apellidos(orden: 'dni; DROP TABLE pacientes')).to eq(%w[Acosta Zapata])
    end
  end
end
