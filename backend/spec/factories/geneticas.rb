FactoryBot.define do
  factory :genetica do
    association :club
    sequence(:nombre) { |n| "Genetica #{n}" }
    sequence(:slug)   { |n| "genetica-#{n}" }
  end
end
