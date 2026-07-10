class AddTipoToInsumos < ActiveRecord::Migration[7.2]
  # Familia del insumo (hardcodeada): define a qué depósito de la sede pertenece.
  #   cultivo → deposito_cultivo (se consume imputando el costo al lote)
  #   general → deposito_general (insumos del club: limpieza, admin; se consume como gasto)
  # El bar tiene su propio modelo (BarProducto = deposito_bar, vendible). Lo existente queda 'cultivo'.
  def change
    add_column :insumos, :tipo, :string, null: false, default: 'cultivo'
    add_index  :insumos, [:club_id, :tipo, :sede_id]
  end
end
