FactoryBot.define do
  factory :alerta_interna do
    association :club
    association :creada_por, factory: :user

    tipo             { 'paciente_creado_por_dispensador' }
    mensaje          { 'Alerta de prueba' }
    severidad        { 'info' }
    destinada_a_role { 'admin' }
    leida_at         { nil }
  end
end
