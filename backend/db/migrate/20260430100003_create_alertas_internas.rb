class CreateAlertasInternas < ActiveRecord::Migration[7.2]
  def change
    create_table :alertas_internas do |t|
      t.bigint  :club_id,          null: false
      t.string  :tipo,             null: false
      t.text    :mensaje,          null: false
      t.string  :severidad,        null: false, default: 'info'
      t.datetime :leida_at
      t.bigint  :creada_por_id
      t.string  :destinada_a_role
      t.jsonb   :contexto,         default: {}
      t.timestamps
    end

    add_index :alertas_internas, :club_id
    add_index :alertas_internas, [:club_id, :leida_at]
    add_foreign_key :alertas_internas, :clubs
    add_foreign_key :alertas_internas, :users, column: :creada_por_id
  end
end
