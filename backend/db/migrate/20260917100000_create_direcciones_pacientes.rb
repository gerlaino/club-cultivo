# Un paciente puede tener VARIAS direcciones de entrega, cada una con nombre («Trabajo», «Casa
# de la madre») y una por defecto (pedido de Germán, 17-sep-2026: una solapa Direcciones en la
# ficha). Hasta hoy había un solo juego de columnas `envio_*` en `pacientes`: la segunda
# dirección no tenía dónde vivir, y el socio de Germán la escribió en el campo Depto.
#
# El domicilio REPROCANN queda donde está (`domicilio_*`): es del trámite, no una dirección
# más. Las columnas `envio_*` se BACKFILLEAN a una fila y dejan de escribirse; se borran en
# una migración posterior, cuando nada las lea.
class CreateDireccionesPacientes < ActiveRecord::Migration[7.2]
  def up
    create_table :direcciones_pacientes do |t|
      t.references :paciente, null: false, foreign_key: true
      t.references :club,     null: false, foreign_key: true
      t.string  :etiqueta
      t.string  :calle, null: false
      t.string  :altura
      t.string  :piso
      t.string  :depto
      t.string  :barrio
      t.string  :ciudad
      t.boolean :por_defecto, null: false, default: false
      t.timestamps
    end
    add_index :direcciones_pacientes, [:paciente_id, :por_defecto]

    execute <<~SQL
      INSERT INTO direcciones_pacientes (paciente_id, club_id, etiqueta, calle, altura, piso, depto, barrio, ciudad, por_defecto, created_at, updated_at)
      SELECT id, club_id, COALESCE(NULLIF(envio_etiqueta, ''), 'Envío'), envio_calle, envio_altura, envio_piso, envio_depto, envio_barrio, envio_ciudad, TRUE, NOW(), NOW()
      FROM pacientes
      WHERE envio_calle IS NOT NULL AND envio_calle <> ''
    SQL
  end

  def down
    drop_table :direcciones_pacientes
  end
end
