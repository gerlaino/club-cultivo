FactoryBot.define do
  factory :lectura_ambiental do
    association :sala
    club_id   { sala.club_id }
    tipo      { 'temperatura' }
    valor     { 24.5 }
    unidad    { '°C' }
    fuente    { 'manual' }
    medido_at { 1.hour.ago }
  end
end
