FactoryBot.define do
  factory :plant do
    association :lote
    sequence(:nombre) { |n| "Planta-#{n}" }
    state             { 'vegetativo' }
    origen            { 'semilla' }
  end
end
