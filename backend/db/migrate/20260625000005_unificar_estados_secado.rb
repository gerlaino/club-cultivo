class UnificarEstadosSecado < ActiveRecord::Migration[7.2]
  # Refactor de la máquina de estados: 'secado' deja de ser un estado del lote
  # (pasa a ser una métrica). Los lotes que estaban en 'secado' van a 'en_manicura'
  # (el secado físico ocurre en post-cosecha, gestionado por manicura). Las plantas
  # en state 'secado' pasan a 'cosechado'.
  def up
    execute "UPDATE lotes  SET estado = 'en_manicura' WHERE estado = 'secado'"
    execute "UPDATE plants SET state  = 'cosechado'   WHERE state  = 'secado'"
  end

  def down
    # No reversible (no sabemos cuáles eran 'secado'). No-op.
  end
end
