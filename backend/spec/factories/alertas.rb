FactoryBot.define do
  factory :alerta do
    association :sala
    association :regla, factory: :regla_ambiental
    club_id  { sala.club_id }
    estado   { 'activa' }
    mensaje  { 'Temperatura fuera de rango' }

    after(:build) do |alerta|
      alerta.regla.club = alerta.sala.club if alerta.regla && alerta.sala
    end
  end
end
