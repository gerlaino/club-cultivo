# Todo paciente nace con cuenta corriente desde sep-2026 (`Paciente#crear_cuenta_corriente!`):
# es donde cae el vuelto que no se pudo dar y se descuenta solo en la próxima. Los anteriores
# al cambio la reciben acá, con límite 0 —tener saldo es de todos; poder deber lo decide el
# admin—. Sólo datos: no toca el esquema.
class CrearCuentaCorrienteATodoPaciente < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      INSERT INTO cuenta_corrientes (paciente_id, club_id, limite_credito, saldo_disponible, created_at, updated_at)
      SELECT p.id, p.club_id, 0, 0, NOW(), NOW()
      FROM pacientes p
      LEFT JOIN cuenta_corrientes cc ON cc.paciente_id = p.id AND cc.deleted_at IS NULL
      WHERE cc.id IS NULL AND p.deleted_at IS NULL
    SQL
  end

  def down
    # Las cuentas creadas acá están en cero y sin movimientos; las que ya se usaron se quedan.
    execute <<~SQL
      DELETE FROM cuenta_corrientes cc
      WHERE cc.limite_credito = 0 AND cc.saldo_disponible = 0
        AND NOT EXISTS (SELECT 1 FROM cuenta_corriente_movimientos m WHERE m.cuenta_corriente_id = cc.id)
    SQL
  end
end
