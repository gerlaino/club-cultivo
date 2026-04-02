class UpdateLoteEstados < ActiveRecord::Migration[7.2]
  def up
    # Renombrar estados en lotes
    execute "UPDATE lotes SET estado = 'semilla'    WHERE estado = 'planificacion'"
    execute "UPDATE lotes SET estado = 'cosecha'    WHERE estado = 'secado'"
    execute "UPDATE lotes SET estado = 'curado'     WHERE estado = 'cosechado'"

    # Renombrar estados en plants
    execute "UPDATE plants SET state = 'semilla'    WHERE state  = 'planificacion'"
    execute "UPDATE plants SET state = 'cosechada'  WHERE state  = 'cosechado'"
  end

  def down
    execute "UPDATE lotes SET estado = 'planificacion' WHERE estado = 'semilla'"
    execute "UPDATE lotes SET estado = 'secado'        WHERE estado = 'cosecha'"
    execute "UPDATE lotes SET estado = 'cosechado'     WHERE estado = 'curado'"
    execute "UPDATE plants SET state  = 'planificacion' WHERE state  = 'semilla'"
    execute "UPDATE plants SET state  = 'cosechado'     WHERE state  = 'cosechada'"
  end
end