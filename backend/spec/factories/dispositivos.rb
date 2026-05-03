FactoryBot.define do
  factory :dispositivo do
    association :sala
    club_id            { sala.club_id }
    sequence(:nombre_amigable) { |n| "Sensor #{n}" }
    tipo               { 'generic' }
    estado             { 'activo' }
    sequence(:serial)  { |n| "SN-#{n}" }
  end
end
