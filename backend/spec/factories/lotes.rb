FactoryBot.define do
  factory :lote do
    association :club
    association :sala
    sequence(:codigo) { |n| "LOTE-#{n}" }
    start_date        { 30.days.ago }
    plants_count      { 10 }
    estado            { 'vegetativo' }
  end
end
