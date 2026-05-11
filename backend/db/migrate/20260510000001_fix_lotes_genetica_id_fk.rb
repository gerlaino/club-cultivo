class FixLotesGeneticaIdFk < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE lotes SET genetica_id = NULL
      WHERE genetica_id IS NOT NULL
        AND genetica_id NOT IN (SELECT id FROM geneticas)
    SQL

    change_column :lotes, :genetica_id, :bigint
    add_index     :lotes, :genetica_id, name: 'index_lotes_on_genetica_id', if_not_exists: true
    add_foreign_key :lotes, :geneticas, on_delete: :nullify
  end

  def down
    remove_foreign_key :lotes, :geneticas
    remove_index  :lotes, name: 'index_lotes_on_genetica_id', if_exists: true
    change_column :lotes, :genetica_id, :integer
  end
end
