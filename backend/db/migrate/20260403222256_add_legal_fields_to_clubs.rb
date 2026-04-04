class AddLegalFieldsToClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :cuit,                        :string
    add_column :clubs, :numero_igj,                  :string
    add_column :clubs, :numero_resolucion_reprocann,  :string
    add_column :clubs, :fecha_resolucion_reprocann,   :date
    add_column :clubs, :tipo_organizacion,            :string
  end
end