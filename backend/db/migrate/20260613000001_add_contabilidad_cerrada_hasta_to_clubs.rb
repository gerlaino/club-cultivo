class AddContabilidadCerradaHastaToClubs < ActiveRecord::Migration[7.2]
  def up
    add_column :clubs, :contabilidad_cerrada_hasta, :date
  end

  def down
    remove_column :clubs, :contabilidad_cerrada_hasta
  end
end
