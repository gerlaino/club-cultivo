class AddGeneticaIdToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :genetica_id, :integer
  end
end
