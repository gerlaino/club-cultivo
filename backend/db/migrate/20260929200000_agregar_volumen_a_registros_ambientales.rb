# El volumen de agua del riego, como número (29-sep-2026). Se pedía en el formulario y se guardaba
# como texto («Riego: 20L»): no se podía sumar ni comparar. Es lo que recibió ESE lote: en un
# riego de toda la sala se carga el total y a cada lote le toca su parte (`Insumo.partes_de`).
class AgregarVolumenARegistrosAmbientales < ActiveRecord::Migration[7.2]
  def change
    add_column :registros_ambientales, :volumen_l, :decimal, precision: 10, scale: 2
  end
end
