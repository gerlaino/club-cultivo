class AddDeliveryToDispensaciones < ActiveRecord::Migration[7.1]
  def change
    add_column :dispensaciones, :con_envio,          :boolean, default: false, null: false
    add_column :dispensaciones, :estado_envio,       :string
    add_column :dispensaciones, :delivery_id,        :bigint
    add_column :dispensaciones, :direccion_envio,    :string
    add_column :dispensaciones, :contacto_nombre,    :string
    add_column :dispensaciones, :contacto_telefono,  :string
    add_column :dispensaciones, :notas_envio,        :text
    add_column :dispensaciones, :codigo_paquete,     :string
    add_column :dispensaciones, :notas_entrega,      :text
    add_column :dispensaciones, :motivo_fallo,       :text
    add_column :dispensaciones, :entregado_at,       :datetime

    add_index :dispensaciones, :delivery_id
    add_index :dispensaciones, :estado_envio
    add_index :dispensaciones, :codigo_paquete, unique: true

    add_foreign_key :dispensaciones, :users, column: :delivery_id
  end
end
