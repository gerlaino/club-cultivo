require 'rails_helper'

# SUSPENDIDO POR POCO MOVIMIENTO (Germán, 23-sep-2026): «los que no dispensan más como
# suspendidos… con un tooltip que diga suspendido por poco movimiento, bien distintivo; y después
# una cosa es el estado REPROCANN, y además el paciente puede estar activo o inactivo».
#
# AC:
#   · Suspendido = activo que hace más de 90 días que no retira. Lo calcula el sistema; no bloquea.
#   · El que nunca retiró no está suspendido (alta reciente, no abandono).
#   · Un inactivo (baja) es inactivo, no suspendido.
#   · Vuelve a activo solo al retirar.
RSpec.describe 'Pacientes — suspendido por poco movimiento', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:stock) { create(:stock, club: club, sede: sede, cantidad: 500) }
  let(:hoy)   { Time.zone.today }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  def paciente!(apellido, retiro: nil, activo: true)
    p = create(:paciente, club: club, created_by: admin, apellido: apellido)
    if retiro
      Dispensacion.create!(paciente: p, user: admin, stock: stock, cantidad: 1, fecha_dispensacion: retiro)
    end
    p.update!(es_paciente: false) unless activo
    p
  end

  def fila(p)
    get '/api/pacientes', params: { limite: 50 }
    json['data'].find { |x| x['id'] == p.id }
  end

  it 'el que no retira hace más de 90 días está suspendido' do
    expect(fila(paciente!('Ana', retiro: hoy - 100))['suspendido']).to be(true)
  end

  it 'el que retiró hace poco, no' do
    expect(fila(paciente!('Beto', retiro: hoy - 10))['suspendido']).to be(false)
  end

  it 'el que nunca retiró, no: es un alta reciente' do
    expect(fila(paciente!('Caro'))['suspendido']).to be(false)
  end

  it 'un inactivo es inactivo, no suspendido' do
    expect(fila(paciente!('Dora', retiro: hoy - 200, activo: false))['suspendido']).to be(false)
  end

  it 'no bloquea: se le puede dispensar, y al retirar deja de estar suspendido' do
    p = paciente!('Eva', retiro: hoy - 100)
    Dispensacion.create!(paciente: p, user: admin, stock: stock, cantidad: 1, fecha_dispensacion: hoy)

    expect(fila(p)['suspendido']).to be(false)
  end

  it 'la ficha lo dice igual que la lista' do
    p = paciente!('Fede', retiro: hoy - 100)
    get "/api/pacientes/#{p.id}"
    expect(json.dig('data', 'suspendido')).to be(true)
  end

  it 'el contador cuenta a los suspendidos con la misma regla' do
    paciente!('Gabi', retiro: hoy - 100)
    paciente!('Hugo', retiro: hoy - 10)
    paciente!('Ines', retiro: hoy - 200, activo: false)

    get '/api/pacientes'
    expect(json.dig('meta', 'kpis', 'inactivos')).to eq(1)
  end
end
