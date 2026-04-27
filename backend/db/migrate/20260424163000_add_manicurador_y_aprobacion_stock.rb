class AddManicuradorYAprobacionStock < ActiveRecord::Migration[7.1]
  def change
    # Estado de aprobación en movimientos de inventario
    add_column :inventario_movimientos, :estado, :string, default: 'aprobado', null: false
    add_column :inventario_movimientos, :aprobado_por_id, :bigint
    add_column :inventario_movimientos, :aprobado_at, :datetime
    add_column :inventario_movimientos, :nota_rechazo, :string

    add_foreign_key :inventario_movimientos, :users, column: :aprobado_por_id
    add_index       :inventario_movimientos, :estado
    add_index       :inventario_movimientos, :aprobado_por_id
  end
end
