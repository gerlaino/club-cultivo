class AddPlantaMadreIdsToLotes < ActiveRecord::Migration[7.2]
  # Un lote de esquejes puede provenir de varias plantas madre (p. ej. 8 madres → 1 lote).
  # planta_madre_id (single) queda como legacy = la primera madre; la fuente de verdad
  # de "de qué madres salió" pasa a ser este array.
  def change
    add_column :lotes, :planta_madre_ids, :integer, array: true, default: [], null: false
  end
end
