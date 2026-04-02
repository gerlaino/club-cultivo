class AddFieldsToRegistrosAmbientales < ActiveRecord::Migration[7.2]
  def change
    add_column :registros_ambientales, :temperatura_sustrato, :decimal, precision: 5, scale: 2
    add_column :registros_ambientales, :ph_runoff,            :decimal, precision: 4, scale: 2
    add_column :registros_ambientales, :ec_runoff,            :decimal, precision: 5, scale: 2
    add_column :registros_ambientales, :ppfd,                 :decimal, precision: 7, scale: 1
    add_column :registros_ambientales, :plagas_observadas,    :string
    add_column :registros_ambientales, :notas_nutricion,      :text
    add_column :registros_ambientales, :fuente,               :string, default: 'manual'
    add_column :registros_ambientales, :nombre_archivo_csv,   :string
  end
end