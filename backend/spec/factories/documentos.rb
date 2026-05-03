FactoryBot.define do
  factory :documento do
    association :club
    association :user
    association :subido_por, factory: :user

    sequence(:titulo) { |n| "Documento #{n}" }
    tipo              { 'contrato_socio' }
    estado            { 'vigente' }
  end
end
