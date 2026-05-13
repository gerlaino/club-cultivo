class AddBorradorToPesadas < ActiveRecord::Migration[7.1]
  def change
    add_column :pesadas, :borrador, :boolean, default: false, null: false
    add_index  :pesadas, [:lote_id, :borrador]
  end
end
