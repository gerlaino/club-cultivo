class DropReprocannAdjuntoFromPacientes < ActiveRecord::Migration[7.2]
  def up
    remove_column :pacientes, :reprocann_adjunto, :string
  end

  def down
    add_column :pacientes, :reprocann_adjunto, :string
  end
end
