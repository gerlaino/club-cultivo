FactoryBot.define do
  factory :stock do
    association :sede
    association :lote
    origen        { 'lote' }
    forma_producto{ 'flor_seca' }
    unidad        { 'g' }
    cantidad      { 100 }

    trait :externo do
      origen       { 'compra_externa' }
      lote         { nil }
      proveedor    { 'Proveedor Test' }
      descripcion  { 'Stock externo test' }
    end
  end
end
