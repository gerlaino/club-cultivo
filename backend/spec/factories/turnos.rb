FactoryBot.define do
  factory :turno do
    association :paciente
    association :medico, factory: [:user, :medico]
    association :club
    fecha_hora       { 3.days.from_now }
    duracion_minutos { 30 }
    tipo             { 'seguimiento' }
    estado           { 'programado' }
  end
end
