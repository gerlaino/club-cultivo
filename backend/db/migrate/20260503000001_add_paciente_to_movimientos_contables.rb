class AddPacienteToMovimientosContables < ActiveRecord::Migration[7.2]
  def change
    add_reference :movimientos_contables, :paciente, null: true, foreign_key: { to_table: :pacientes }
  end
end
