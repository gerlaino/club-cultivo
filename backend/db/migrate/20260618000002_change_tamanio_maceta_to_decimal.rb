class ChangeTamanioMacetaToDecimal < ActiveRecord::Migration[7.2]
  # tamanio_maceta era integer => no podía guardar 0.5L (vaso); se truncaba a 0.
  # Pasamos a decimal(4,1) para soportar 0.5, 1, 3, 5, 7, 10, 12, 15...
  def up
    change_column :lotes, :tamanio_maceta,         :decimal, precision: 4, scale: 1
    change_column :lotes, :tamanio_maceta_inicial, :decimal, precision: 4, scale: 1
  end

  def down
    change_column :lotes, :tamanio_maceta,         :integer
    change_column :lotes, :tamanio_maceta_inicial, :integer
  end
end
