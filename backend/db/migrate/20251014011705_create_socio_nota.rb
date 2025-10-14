class CreateSocioNota < ActiveRecord::Migration[7.2]
  def change
    create_table :socio_nota do |t|
      t.references :socio, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :contenido

      t.timestamps
    end
  end
end
