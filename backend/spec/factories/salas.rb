FactoryBot.define do
  factory :sala do
    association :club
    association :created_by, factory: :user
    sequence(:nombre) { |n| "Sala #{n}" }
    state             { 'activa' }
  end
end
