class AddUnidadNegocioADepositos < ActiveRecord::Migration[7.2]
  # El depósito pertenece a un área (unidad de negocio): así el movimiento contable que genera
  # una compra hereda el área del depósito (adiós al "comportamiento" de las categorías).
  # Nullable: un depósito puede no tener área todavía; un área puede tener 0..N depósitos.
  def change
    add_reference :depositos, :unidad_negocio, foreign_key: { to_table: :unidades_negocio }
  end
end
