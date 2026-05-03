FactoryBot.define do
  factory :sede do
    association :club
    association :created_by, factory: :user
    sequence(:nombre) { |n| "Sede #{n}" }
    tipo              { 'produccion' }
  end
end
