class AddTokenAndSnapshotToDispensaciones < ActiveRecord::Migration[7.2]
  # token: identificador público (no adivinable) para la URL /d/:token que abre el
  #   "pasaporte" de la dispensa (gateado por DNI del paciente).
  # producto_snapshot: foto inmutable de los datos del producto al momento de dispensar
  #   (genética + cannabinoides + terpenos, forma, cantidad). Para que la etiqueta
  #   impresa siga mostrando lo correcto aunque luego se edite la genética o se borre
  #   el stock.
  def change
    add_column :dispensaciones, :token, :string
    add_column :dispensaciones, :producto_snapshot, :jsonb, default: {}, null: false
    add_index  :dispensaciones, :token, unique: true
  end
end
