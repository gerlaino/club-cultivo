class AddInaseFieldsToGeneticas < ActiveRecord::Migration[7.2]
  def change
    add_column :geneticas, :numero_registro_inase, :string
    add_column :geneticas, :fecha_registro_inase,  :date
    add_column :geneticas, :categoria_inase,        :string

    add_index :geneticas, :numero_registro_inase,
              unique: true,
              where:  "numero_registro_inase IS NOT NULL",
              name:   "idx_geneticas_numero_inase"
  end
end
