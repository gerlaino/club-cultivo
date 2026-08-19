require 'rails_helper'

# AC: cada paciente admitido tiene una cuenta con la que entrar a su portal. El usuario se deriva
# de su nombre y la contraseña NO: es distinta para cada uno.
#
# Que la clave fuera fija sería peor acá que en el equipo. El usuario se deduce del nombre
# (`juan.perez@...`), así que cualquiera que conozca a un paciente de la organización lo arma
# solo; con una clave común entraría a su historia clínica y a sus dispensaciones.
RSpec.describe Pacientes::Acceso do
  let(:club) { create(:club, name: 'Mi Organización', features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def paciente!(nombre, apellido, dni: nil)
    create(:paciente, club: club, nombre: nombre, apellido: apellido,
                      dni: dni || rand(10_000_000..49_999_999).to_s)
  end

  describe 'el usuario que crea' do
    it 'se arma con el nombre y la organización, sin tildes ni espacios' do
      resultado = described_class.crear!(paciente!('José María', 'Pérez Gómez'))

      expect(resultado.user.email).to eq('jose.maria.perez.gomez@mi-organizacion.paciente')
    end

    it 'entra con rol paciente y en su organización' do
      user = described_class.crear!(paciente!('Ana', 'Díaz')).user

      expect(user.role).to eq('paciente')
      expect(user.club_id).to eq(club.id)
    end

    it 'queda enganchado al paciente' do
      paciente = paciente!('Ana', 'Díaz')
      user = described_class.crear!(paciente).user

      expect(paciente.reload.user).to eq(user)
    end
  end

  describe 'la contraseña' do
    it 'es distinta para cada paciente' do
      claves = 3.times.map { |i| described_class.crear!(paciente!("Ana#{i}", 'Díaz')).password_inicial }

      expect(claves.uniq.size).to eq(3)
    end

    it 'sirve para entrar' do
      resultado = described_class.crear!(paciente!('Ana', 'Díaz'))

      expect(resultado.user.valid_password?(resultado.password_inicial)).to be true
    end

    it 'se puede dictar por teléfono: sin cero ni ele ni i mayúscula' do
      clave = described_class.crear!(paciente!('Ana', 'Díaz')).password_inicial

      expect(clave).not_to match(/[0lOI]/)
    end
  end

  describe 'dos personas que se llaman igual' do
    it 'la segunda entra con un usuario distinto: si no, no se podía dar de alta' do
      primero  = described_class.crear!(paciente!('Juan', 'Pérez')).user
      segundo  = described_class.crear!(paciente!('Juan', 'Pérez')).user

      expect(segundo.email).not_to eq(primero.email)
      expect(segundo.email).to start_with('juan.perez2@')
    end

    it 'en otra organización no hace falta numerar: el dominio ya las separa' do
      described_class.crear!(paciente!('Juan', 'Pérez'))
      otro = create(:club, name: 'Otra Organización')
      ajeno = ActsAsTenant.with_tenant(otro) do
        described_class.crear!(create(:paciente, club: otro, nombre: 'Juan', apellido: 'Pérez')).user
      end

      expect(ajeno.email).to eq('juan.perez@otra-organizacion.paciente')
    end
  end

  # Un alta reintentada no puede rotarle la clave a alguien que ya la tenía anotada.
  it 'no le toca nada al que ya tiene cuenta' do
    paciente = paciente!('Ana', 'Díaz')
    primero  = described_class.crear!(paciente)

    segundo = described_class.crear!(paciente.reload)

    expect(segundo.user).to eq(primero.user)
    expect(segundo.password_inicial).to be_nil
    expect(primero.user.reload.valid_password?(primero.password_inicial)).to be true
  end
end
