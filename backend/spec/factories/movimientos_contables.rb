FactoryBot.define do
  factory :movimiento_contable do
    association :club
    created_by  { association :user, club: club }
    tipo        { 'egreso' }
    categoria   { 'insumo' }
    descripcion { 'Gasto de prueba' }
    monto_ars   { 1000 }
    fecha       { Date.current }
  end
end
