class AddConfirmacionAJornadasLaborales < ActiveRecord::Migration[7.2]
  # Flujo de confirmación de horas: la jornada nace 'enviada' (se carga y ya queda pendiente
  # de confirmar) y el admin/supervisor la confirma. Una confirmada queda bloqueada hasta que
  # un admin la reabra.
  def change
    add_column :jornadas_laborales, :estado, :string, null: false, default: 'enviada'
    add_column :jornadas_laborales, :confirmada_at, :datetime
    add_reference :jornadas_laborales, :confirmada_por,
                  foreign_key: { to_table: :users }, null: true, index: true
    add_index :jornadas_laborales, [:club_id, :estado]
  end
end
