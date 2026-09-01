# El MOSTRADOR: el punto de venta del dispensario, hermano de `Barra` (el del buffet).
#
# Hasta hoy la caja del dispensario apuntaba a la `Sede` —no porque estuviera bien, sino porque
# no existía la entidad: `CajaTurno#de_dispensario?` literalmente preguntaba `punto_type == 'Sede'`.
# Eso dejaba dos ideas distintas de "punto de venta" conviviendo, y ninguna forma de decir "este
# stock está sobre la mesa de ESTE mostrador".
#
# El mostrador es de la SEDE y puede haber más de uno (como los bares), pero se siembra UNO por
# sede que dispense. Quién atiende cada mostrador no necesita tabla nueva: `UserSede` ya asigna
# dispensadores a sedes, y el mostrador es de la sede.
#
# `exigir_mostrador_abierto` NO es un módulo que se venda: el mostrador viene con la suite de
# Producción y dispensa y lo tiene todo el mundo. Es un interruptor OPERATIVO, y arranca apagado
# porque el día que se exige abrir el mostrador para dispensar, un club que no se enteró se queda
# sin poder atender — y se entera con un paciente adelante.
class CreateMostradores < ActiveRecord::Migration[7.2]
  def up
    create_table :mostradores do |t|
      t.references :club, null: false, foreign_key: true
      t.references :sede, null: false, foreign_key: true
      t.string   :nombre, null: false, default: 'Mostrador'
      t.boolean  :activo, null: false, default: true
      t.datetime :deleted_at
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :mostradores, [:club_id, :sede_id]
    add_index :mostradores, :deleted_at
    add_index :mostradores, [:club_id, :sede_id, :nombre],
              unique: true, where: 'deleted_at IS NULL',
              name: 'index_mostradores_unico_por_nombre'

    add_column :clubs, :exigir_mostrador_abierto, :boolean, null: false, default: false

    # Siembra: un mostrador por sede que dispense (social o mixta) MÁS cualquier sede que ya
    # tenga una caja apuntándole. Ese OR no es paranoia: si una caja quedó colgada de una sede
    # de producción, sin mostrador el repuntado de abajo la dejaría sin dueño y el modelo la
    # daría por inválida — incluida una que esté ABIERTA ahora mismo.
    #
    # El `deleted_at IS NULL` aplica SÓLO a la primera rama. Una sede dada de baja que tenga
    # cajas viejas igual necesita su mostrador: si no, esas cajas no se repuntan, el guard de
    # abajo salta y el deploy entero falla por un registro que nadie va a volver a mirar. Se le
    # crea el mostrador y queda dado de baja igual que la sede.
    execute <<~SQL
      INSERT INTO mostradores (club_id, sede_id, nombre, activo, deleted_at, created_at, updated_at)
      SELECT s.club_id, s.id, 'Mostrador', s.deleted_at IS NULL, s.deleted_at, NOW(), NOW()
      FROM sedes s
      WHERE (s.deleted_at IS NULL AND s.tipo IN ('social', 'mixta'))
         OR EXISTS (SELECT 1 FROM caja_turnos c
                    WHERE c.punto_type = 'Sede' AND c.punto_id = s.id)
    SQL

    # Repuntar las cajas del dispensario que ya existen: de la Sede al Mostrador de esa sede.
    execute <<~SQL
      UPDATE caja_turnos c
      SET punto_type = 'Mostrador', punto_id = m.id
      FROM mostradores m
      WHERE c.punto_type = 'Sede' AND m.sede_id = c.punto_id
    SQL

    # Si quedó una sola caja sin repuntar, el arqueo de ese club miente en silencio: los cobros
    # no se enganchan y el esperado sale mal. Preferimos que falle el deploy (bin/render-build.sh
    # corre con errexit) antes que dejar una caja rota en producción.
    #
    # Después del arreglo de arriba, sólo puede quedar una si apunta a una sede que ya NO EXISTE
    # en la tabla. El detalle va en el mensaje para no salir a buscarlo con el deploy caído.
    huerfanas = select_all(
      "SELECT id, club_id, punto_id AS sede_id, estado FROM caja_turnos " \
      "WHERE punto_type = 'Sede' ORDER BY id"
    ).to_a
    return if huerfanas.empty?

    detalle = huerfanas.map { |c| "caja ##{c['id']} → sede ##{c['sede_id']} (#{c['estado']})" }
    raise "Quedaron #{huerfanas.size} cajas apuntando a una Sede inexistente: #{detalle.join(', ')}"
  end

  def down
    execute <<~SQL
      UPDATE caja_turnos c
      SET punto_type = 'Sede', punto_id = m.sede_id
      FROM mostradores m
      WHERE c.punto_type = 'Mostrador' AND m.id = c.punto_id
    SQL

    remove_column :clubs, :exigir_mostrador_abierto
    drop_table :mostradores
  end
end
