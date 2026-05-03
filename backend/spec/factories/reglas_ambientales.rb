FactoryBot.define do
  factory :regla_ambiental do
    association :club
    sequence(:nombre)    { |n| "Regla #{n}" }
    tipo_lectura         { 'temperatura' }
    condicion            { 'gt' }
    umbral_a             { 30.0 }
    duracion_minutos     { 5 }
    prioridad            { 'media' }
    accion               { 'notificar' }
    activa               { true }
  end
end
