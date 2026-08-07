class AddLeafTempOffsetASalas < ActiveRecord::Migration[7.2]
  # Cuánto más FRÍA está la hoja que el aire, en °C. Es lo que separa el VPD del aire (que
  # calculábamos) del VPD de hoja (el que gobierna la transpiración y con el que se decide
  # un riego). La hoja transpira y se enfría: bajo LED entre 2 y 3 °C, bajo HPS menos porque
  # el infrarrojo la calienta.
  #
  # -2.0 es el valor que usa la industria por defecto (y el que trae Pulse de fábrica), así
  # que las salas existentes quedan con el mismo criterio que el sensor del club sin tener
  # que tocar nada.
  def change
    add_column :salas, :leaf_temp_offset, :decimal, precision: 4, scale: 2, default: -2.0, null: false
  end
end
