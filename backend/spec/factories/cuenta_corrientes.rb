FactoryBot.define do
  # Todo paciente nace con su cuenta corriente (`Paciente#crear_cuenta_corriente!`): la factory
  # REUSA la que ya tiene y le pisa los atributos, en vez de crear una segunda fila que `has_one`
  # encontraría al azar.
  factory :cuenta_corriente do
    association :paciente
    association :club
    saldo_disponible { 1000 }
    limite_credito   { 1000 }

    initialize_with { paciente&.cuenta_corriente || new }
  end
end
