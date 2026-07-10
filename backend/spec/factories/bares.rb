FactoryBot.define do
  factory :barra do
    association :club
    sede { association :sede, club: club, tipo: 'social' }
    sequence(:nombre) { |n| "Bar #{n}" }
    activo { true }
  end

  factory :bar_producto do
    association :club
    association :bar, factory: :barra
    sequence(:nombre) { |n| "Producto #{n}" }
    categoria     { 'bebida' }
    precio_ars    { 1000 }
    costo_ars     { 400 }
    stock         { 50 }
    stock_minimo  { 5 }
    activo        { true }
  end

  factory :bar_venta do
    association :club
    association :bar, factory: :barra
    association :user
    total_ars  { 1000 }
    medio_pago { 'efectivo' }
  end

  factory :bar_venta_item do
    association :club
    association :bar_venta
    association :bar_producto
    nombre               { 'Producto' }
    cantidad             { 1 }
    precio_unitario_ars  { 1000 }
    subtotal_ars         { 1000 }
  end
end
