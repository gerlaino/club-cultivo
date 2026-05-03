FactoryBot.define do
  factory :registro_ambiental do
    association :lote
    association :user
    club_id      { lote.club_id }
    registrado_en { 1.hour.ago }
    temperatura  { 25.0 }
    humedad      { 60.0 }
    fuente       { 'manual' }
  end
end
