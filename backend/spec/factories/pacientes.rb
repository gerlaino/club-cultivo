FactoryBot.define do
  factory :paciente do
    association :club
    association :created_by, factory: :user
    sequence(:nombre)    { |n| "Paciente #{n}" }
    sequence(:apellido)  { |n| "Apellido #{n}" }
    sequence(:dni)       { |n| "#{10_000_000 + n}" }
    fecha_nacimiento     { 30.years.ago.to_date }
    email                { Faker::Internet.email }
    es_paciente          { true }
  end
end
