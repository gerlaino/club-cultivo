# El interruptor "Portal abierto / Portal cerrado" pasa a hacer algo.
#
# `clubs.vista_paciente_activa` existía, se editaba desde Configuración → Portal del paciente y
# viajaba en `/preferences`, pero NO LO LEÍA NADIE: el paciente entraba igual con el portal
# marcado como cerrado. Ahora lo leen el login y el área de pacientes.
#
# El backfill no es opcional. La columna nació con `default: false`, así que toda organización que
# tiene el add-on contratado y nunca tocó el interruptor quedaría con el portal cerrado el día del
# deploy — y sus pacientes, que hoy entran, dejarían de poder entrar sin que nadie tocara nada. Es
# la misma regla que ya costó un susto con los módulos derivados: cuando un flag pasa a leerse,
# hay que escribir el valor que la realidad ya tenía.
class AbrirPortalAQuienYaLoTenia < ActiveRecord::Migration[7.2]
  def up
    # `features` es jsonb: se mira la clave contratada, no `feature?` (que es Ruby y no corre acá).
    execute <<~SQL
      UPDATE clubs
         SET vista_paciente_activa = true
       WHERE vista_paciente_activa = false
         AND deleted_at IS NULL
         AND (features ->> 'vista_paciente') = 'true'
    SQL
  end

  # Irreversible a propósito: no se puede saber cuáles estaban en false por decisión de la
  # organización y cuáles por el default. Volver a ponerlos todos en false cerraría portales que
  # alguien abrió a mano.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
