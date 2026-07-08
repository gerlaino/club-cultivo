class AddHierarchyToCategoriasContables < ActiveRecord::Migration[7.2]
  # Categorías jerárquicas: madre → subcategoría (parent_id autorreferente) + `comportamiento`
  # que define qué datos pide el movimiento y a dónde rutea (general/insumo/mercaderia).
  # Aditivo y nullable: no rompe las categorías planas existentes (la siembra las reorganiza).
  def change
    add_reference :categorias_contables, :parent, null: true,
                  foreign_key: { to_table: :categorias_contables }
    add_column :categorias_contables, :comportamiento, :string, null: false, default: 'general'
  end
end
