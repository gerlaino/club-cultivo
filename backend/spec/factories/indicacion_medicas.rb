FactoryBot.define do
  factory :indicacion_medica do
    association :paciente
    # El médico que emite. La columna es `user_id` y no `medico_id`, a diferencia de Turno.
    association :user, factory: [:user, :medico]
    patologia          { 'Dolor crónico' }
    dosificacion       { '2 gotas cada 12 horas' }
    via_administracion { 'sublingual' }
    fecha_emision      { Time.zone.today }
    activa             { true }
  end
end
