require 'rails_helper'

# AC (sep-2026): la organización recién creada nace vacía y hay que DECIR qué falta, derivado
# de los datos y según lo contratado. La misma lista la leen la ficha del super admin y el
# inicio del admin.
RSpec.describe Clubs::PuestaEnMarcha do
  let(:club) { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true, 'mailer' => true }) }

  def pasos = ActsAsTenant.with_tenant(club) { described_class.de(club) }

  it 'una organización recién creada tiene todo por hacer' do
    r = pasos

    expect(r[:completa]).to be(false)
    expect(r[:hechos]).to   eq(0)
    expect(r[:pasos].map { |p| p[:clave] }).to eq(%w[sedes salas geneticas lotes pacientes correo equipo])
    expect(r[:pasos]).to all(include(:label, :detalle, :ruta))
  end

  it 'los pasos dependen de lo contratado: sin Cultivo no se piden salas ni lotes' do
    club.update!(features: { 'produccion_dispensa' => true })

    expect(pasos[:pasos].map { |p| p[:clave] }).to eq(%w[sedes pacientes equipo])
  end

  it 'marca lo hecho mirando los datos' do
    ActsAsTenant.with_tenant(club) do
      sede = create(:sede, club: club, tipo: 'mixta')
      create(:sala, club: club, sede: sede)
    end

    hechos = pasos[:pasos].select { |p| p[:hecho] }.map { |p| p[:clave] }
    expect(hechos).to contain_exactly('sedes', 'salas')
  end

  # Sin una variedad propia y disponible el alta del lote ofrece «Sin genéticas disponibles»:
  # el paso va ANTES del lote. Las del catálogo INASE no cuentan (son de consulta, de todos).
  it '«cargar una variedad» pide una propia, activa y disponible' do
    ActsAsTenant.with_tenant(club) do
      expect(pasos[:pasos].find { |p| p[:clave] == 'geneticas' }[:hecho]).to be false
      g = Genetica.create!(club: club, nombre: 'Casera', tipo: 'hibrida', disponible: false)
      expect(pasos[:pasos].find { |p| p[:clave] == 'geneticas' }[:hecho]).to be false
      g.update!(disponible: true)
      expect(pasos[:pasos].find { |p| p[:clave] == 'geneticas' }[:hecho]).to be true
    end
  end

  it '«que entre alguien más» se cumple cuando alguien del equipo que no es admin entró' do
    create(:user, :cultivador, club: club, visto_at: nil)
    expect(pasos[:pasos].find { |p| p[:clave] == 'equipo' }[:hecho]).to be(false)

    create(:user, :dispensador, club: club, visto_at: Time.current)
    expect(pasos[:pasos].find { |p| p[:clave] == 'equipo' }[:hecho]).to be(true)
  end
end
