class CreateCuentaCorrientes < ActiveRecord::Migration[7.2]
  def change
    create_table :cuenta_corrientes, if_not_exists: true do |t|
      t.references :socio, null: false, foreign_key: true
      t.references :club,  null: false, foreign_key: true
      t.decimal :limite_credito,   precision: 12, scale: 2, default: 0, null: false
      t.decimal :saldo_disponible, precision: 12, scale: 2, default: 0, null: false
      t.text :notas
      t.timestamps
    end
    add_index :cuenta_corrientes, :socio_id, unique: true, if_not_exists: true
  end
end
