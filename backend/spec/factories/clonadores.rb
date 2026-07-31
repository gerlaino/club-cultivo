FactoryBot.define do
  factory :clonador do
    association :club
    association :sala
    sequence(:nombre) { |n| "Clonador #{n}" }
    activo { true }
  end
end
