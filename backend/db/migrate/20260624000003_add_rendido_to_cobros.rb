class AddRendidoToCobros < ActiveRecord::Migration[7.2]
  # El efectivo que cobra el delivery queda "en tránsito": no se asienta como ingreso
  # hasta que el admin recibe la caja. rendido = false ⇒ pendiente de rendición.
  # default true: los cobros existentes ya estaban asentados (no cambian).
  def change
    add_column :cobros, :rendido,    :boolean, null: false, default: true
    add_column :cobros, :rendido_at, :datetime
    add_index  :cobros, [:created_by_id, :rendido]
  end
end
