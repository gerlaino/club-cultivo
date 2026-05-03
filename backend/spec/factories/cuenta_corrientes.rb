FactoryBot.define do
  factory :cuenta_corriente do
    association :paciente
    association :club
    saldo_disponible { 1000 }
    limite_credito   { 1000 }
  end
end
