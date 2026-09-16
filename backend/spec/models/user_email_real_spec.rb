require 'rails_helper'

# `email_real` es a dónde se le puede escribir DE VERDAD. El login puede ser un identificador
# inventado por la app (`rol@slug.com`, `nombre.apellido@slug.paciente`): mandarle un mail ahí
# es mandarlo a un dominio ajeno.
RSpec.describe User, '#email_real' do
  let(:club) { create(:club, slug: 'verde_norte') }

  it 'prefiere el mail personal' do
    u = build(:user, club: club, email: 'yo@gmail.com', email_personal: 'personal@gmail.com')
    expect(u.email_real).to eq('personal@gmail.com')
  end

  it 'usa el login cuando es una casilla de verdad' do
    u = build(:user, club: club, email: 'yo@gmail.com', email_personal: nil)
    expect(u.email_real).to eq('yo@gmail.com')
  end

  it 'es nil cuando el login lo inventó el alta de la organización' do
    u = build(:user, club: club, email: 'admin@verde_norte.com', email_personal: nil)
    expect(u.email_generado?).to be(true)
    expect(u.email_real).to be_nil
  end

  it 'es nil cuando el login es la cuenta del portal del paciente' do
    u = build(:user, club: club, email: 'ana.perez@verde_norte.paciente', email_personal: nil)
    expect(u.email_real).to be_nil
  end
end
