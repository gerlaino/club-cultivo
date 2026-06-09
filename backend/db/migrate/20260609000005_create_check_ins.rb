class CreateCheckIns < ActiveRecord::Migration[7.0]
  def change
    create_table :check_ins do |t|
      t.references :paciente,    null: false, foreign_key: true
      t.references :dispensacion, null: true, index: { unique: true }, foreign_key: { to_table: :dispensaciones }
      t.references :club,        null: false, foreign_key: true
      t.integer    :escala_bienestar
      t.jsonb      :sintomas,    null: false, default: {}
      t.text       :notas
      t.string     :via_registro, null: false, default: 'dispensacion'
      t.timestamps
    end

    add_index :check_ins, [:paciente_id, :created_at]
  end
end
