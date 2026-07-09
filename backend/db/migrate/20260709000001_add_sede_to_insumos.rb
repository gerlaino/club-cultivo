class AddSedeToInsumos < ActiveRecord::Migration[7.2]
  # Insumos por sede: cada depósito es de su sede (el fertilizante de Pagola ≠ el de Palermo).
  # sede_id nullable: sede_id nil = "pool del club" (mismo criterio que Stock). Las filas viejas
  # quedan en el pool; las nuevas nacen en una sede. Un insumo se puede transferir entre sedes.
  def change
    add_reference :insumos, :sede, null: true, foreign_key: true
    add_index :insumos, [:club_id, :sede_id, :nombre]
  end
end
