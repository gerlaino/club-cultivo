class AddPesajeManicuraToPesadasPlantas < ActiveRecord::Migration[7.0]
  def change
    add_reference :pesadas_plantas, :pesaje_manicura, null: true, foreign_key: { to_table: :pesajes_manicura }
    add_index :pesadas_plantas, :pesaje_manicura_id, if_not_exists: true
  end

  def down
    remove_reference :pesadas_plantas, :pesaje_manicura
  end
end
