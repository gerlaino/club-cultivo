FactoryBot.define do
  factory :setpoint_fase do
    association :club
    fase         { 'vegetativo' }
    tipo_lectura { 'temperatura' }
    valor_min    { 20.0 }
    valor_max    { 28.0 }
    valor_optimo { 24.0 }
  end
end
