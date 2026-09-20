FactoryBot.define do
  factory :tarea do
    association :club
    creada_por  { association :user, :admin, club: club }
    sequence(:titulo) { |n| "Tarea #{n}" }
    tipo        { 'riego' }
    estado      { 'pendiente' }
    prioridad   { 'normal' }
  end
end
