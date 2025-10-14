class AddDeletedAtToSocioNota < ActiveRecord::Migration[7.2]
  def change
    add_column :socio_nota, :deleted_at, :datetime
    add_index :socio_nota, :deleted_at
  end
end
