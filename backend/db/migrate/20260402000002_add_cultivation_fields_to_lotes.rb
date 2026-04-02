class AddCultivationFieldsToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :tamanio_maceta,      :integer
    add_column :lotes, :sustrato_especifico, :string
    add_column :lotes, :fotoperiodo,         :string
    add_column :lotes, :semanas_floracion,   :integer
  end
end
