class AddInaseFieldsToGeneticas < ActiveRecord::Migration[7.2]
  def change
    add_column :geneticas, :registrada_inase, :boolean
    add_column :geneticas, :criador, :string
    add_column :geneticas, :terpenos, :string
  end
end
