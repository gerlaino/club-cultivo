class AddCultivoDetailToLotes < ActiveRecord::Migration[7.0]
  def change
    add_column :lotes, :fotoperiodo_vegetativo,     :string
    add_column :lotes, :tamanio_maceta_inicial,      :integer
    add_column :lotes, :fecha_trasplante,            :date
    add_column :lotes, :ph_riego,                    :decimal, precision: 4, scale: 1
    add_column :lotes, :fertilizacion_descripcion,   :text
    add_column :lotes, :sistema_hidro,               :string
  end
end
