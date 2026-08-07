FactoryBot.define do
  factory :sala do
    association :club
    association :created_by, factory: :user
    sequence(:nombre) { |n| "Sala #{n}" }
    state             { 'activa' }
    # `mixta` acepta lotes de cualquier fase: una sala genérica de test no debería obligar a
    # cada spec a elegir el kind. Los specs que prueban la compatibilidad sala↔estado lo pasan
    # explícito (ver lote_sala_estado_spec).
    kind              { 'mixta' }
  end
end
