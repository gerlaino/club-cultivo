FactoryBot.define do
  factory :club do
    sequence(:name)  { |n| "Club #{n}" }
    sequence(:slug)  { |n| "club_#{n}" }
    email            { Faker::Internet.email }

    after(:build) do |club|
      club.define_singleton_method(:crear_geneticas_default!) {}
    end
  end
end
