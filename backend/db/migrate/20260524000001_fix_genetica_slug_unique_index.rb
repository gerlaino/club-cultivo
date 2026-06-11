class FixGeneticaSlugUniqueIndex < ActiveRecord::Migration[7.0]
  def up
    remove_index :geneticas, name: 'index_geneticas_on_slug'
    add_index :geneticas, [:club_id, :slug], unique: true, name: 'index_geneticas_on_club_id_and_slug'
  end

  def down
    remove_index :geneticas, name: 'index_geneticas_on_club_id_and_slug'
    add_index :geneticas, :slug, unique: true, name: 'index_geneticas_on_slug'
  end
end
