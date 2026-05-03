class AddManicuraPendienteAndApprovalToLotesPesadas < ActiveRecord::Migration[7.2]
  def up
    # Pesada: columnas para flujo de aprobación
    add_column :pesadas, :aprobada_at,       :datetime
    add_column :pesadas, :aprobada_por_id,   :bigint
    add_column :pesadas, :rechazada_at,      :datetime
    add_column :pesadas, :rechazada_por_id,  :bigint
    add_column :pesadas, :motivo_rechazo,    :string

    add_foreign_key :pesadas, :users, column: :aprobada_por_id
    add_foreign_key :pesadas, :users, column: :rechazada_por_id
    add_index :pesadas, :aprobada_por_id
  end

  def down
    remove_foreign_key :pesadas, column: :aprobada_por_id
    remove_foreign_key :pesadas, column: :rechazada_por_id
    remove_index :pesadas, :aprobada_por_id, if_exists: true
    remove_column :pesadas, :aprobada_at
    remove_column :pesadas, :aprobada_por_id
    remove_column :pesadas, :rechazada_at
    remove_column :pesadas, :rechazada_por_id
    remove_column :pesadas, :motivo_rechazo
  end
end
