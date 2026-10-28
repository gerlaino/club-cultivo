# El paciente pide desde su portal lo que hay sobre la mesa (28-oct-2026): la reserva nace
# «solicitada», sin nadie de la organización detrás (`user_id` vacío) y no aparta stock hasta que
# administración la confirma (o la rechaza, con motivo).
class PedidosDelPortalEnReservas < ActiveRecord::Migration[7.2]
  def change
    change_column_null :reservas, :user_id, true
    add_column :reservas, :origen, :string, null: false, default: 'organizacion'
    add_column :reservas, :solicitada_at, :datetime
    add_column :reservas, :confirmada_at, :datetime
    add_reference :reservas, :confirmada_por, foreign_key: { to_table: :users }
    add_column :reservas, :rechazada_at, :datetime
    add_column :reservas, :motivo_rechazo, :text
  end
end
