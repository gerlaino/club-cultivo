# CADA ROL SÓLO SE ASIGNA A LAS SEDES DONDE TIENE ALGO QUE HACER (`Sede::TIPOS_POR_ROL`, 13-sep).
# Desde hoy `UserSede` lo rechaza; lo que ya estaba asignado antes —un dispensador con una finca,
# que fue justamente lo que le rompió el inicio a Dispensa en el Club Modelo— se saca acá. Soft
# delete: la fila queda con `deleted_at` por si hay que ver qué había.
class QuitarSedesQueNoCorrespondenAlRol < ActiveRecord::Migration[7.2]
  def up
    tipos = { 'cultivador' => %w[produccion mixta], 'manicura' => %w[produccion mixta],
              'dispensador' => %w[social mixta], 'medico' => %w[social mixta], 'delivery' => %w[social mixta] }
    total = 0
    tipos.each do |rol, permitidos|
      lista = permitidos.map { |t| "'#{t}'" }.join(', ')
      total += execute(<<~SQL).cmd_tuples
        UPDATE user_sedes us
           SET deleted_at = NOW()
          FROM users u, sedes s
         WHERE us.user_id = u.id AND us.sede_id = s.id
           AND us.deleted_at IS NULL
           AND u.role = '#{rol}'
           AND s.tipo NOT IN (#{lista})
      SQL
    end
    say "user_sedes quitadas por no corresponder al rol: #{total}"
  end

  def down
    # No se restauran solas: eran asignaciones que no debían existir.
  end
end
