FactoryBot.define do
  factory :club do
    sequence(:name)  { |n| "Club #{n}" }
    sequence(:slug)  { |n| "club_#{n}" }
    email            { Faker::Internet.email }
    # Un club de test es un club que opera: con gating real, features vacío significa que no
    # puede hacer nada y todos los specs de módulos con add-on fallarían.
    features         { Club::FEATURES_POR_DEFECTO.dup }

    after(:build) do |club|
      club.define_singleton_method(:crear_geneticas_default!) {}
    end
  end
end
