class RenombrarEstadoSemillaAGerminacion < ActiveRecord::Migration[7.2]
  # Unificación de vocabulario: la primera sub-fase se llama 'germinacion' en lote y en planta
  # (antes el lote la llamaba 'semilla'). Solo toca lotes.estado — NO el origen (semilla/esqueje),
  # NI el plan del club, NI las plantas (que ya usan 'germinacion'). Reversible.
  def up
    execute "UPDATE lotes SET estado = 'germinacion' WHERE estado = 'semilla'"
  end

  def down
    execute "UPDATE lotes SET estado = 'semilla' WHERE estado = 'germinacion'"
  end
end
