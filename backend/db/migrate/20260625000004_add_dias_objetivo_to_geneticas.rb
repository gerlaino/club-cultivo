class AddDiasObjetivoToGeneticas < ActiveRecord::Migration[7.2]
  # Días objetivo de vegetativo y cosecha por genética (el de floración ya existe como
  # tiempo_floracion, en días). El lote los hereda al crearse; editables solo en genéticas
  # propias (no INASE).
  def change
    add_column :geneticas, :dias_vegetativo_objetivo, :integer
    add_column :geneticas, :dias_cosecha_objetivo,     :integer
  end
end
