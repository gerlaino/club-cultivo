class DropSocioNota < ActiveRecord::Migration[7.1]
  def up
    drop_table :socio_nota
  end

  def down
    create_table :socio_nota do |t|
      t.bigint  :paciente_id, null: false
      t.bigint  :user_id,     null: false
      t.text    :contenido
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :socio_nota, :paciente_id
    add_index :socio_nota, :user_id
    add_index :socio_nota, :deleted_at
    add_foreign_key :socio_nota, :pacientes
    add_foreign_key :socio_nota, :users
  end
end
