class AddDisponibilidadAStocks < ActiveRecord::Migration[7.2]
  # Para qué está habilitado cada stock: dispensa (entrega a pacientes), produccion
  # (materia prima para manufacturar derivados), ambas o ninguna. Default 'ambas' para no
  # cambiar el comportamiento del stock existente hasta que se re-etiquete a mano.
  def change
    add_column :stocks, :disponibilidad, :string, null: false, default: 'ambas'
    add_index  :stocks, [:club_id, :disponibilidad]
  end
end
