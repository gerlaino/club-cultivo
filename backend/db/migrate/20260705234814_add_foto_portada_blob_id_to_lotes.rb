class AddFotoPortadaBlobIdToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :foto_portada_blob_id, :bigint
  end
end
