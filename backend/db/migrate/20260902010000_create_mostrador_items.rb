# EL MOSTRADOR PASA A TENER CONTENIDO PROPIO, INDEPENDIENTE DEL TURNO.
#
# Hasta acá, el stock que había sobre la mesa vivía en los ítems del TURNO: abrir el turno era
# poner la mercadería. Eso ataba dos cosas que son distintas y de personas distintas:
#
#   · QUÉ HAY sobre la mesa   → lo decide el admin, cuando quiera, desde donde esté
#   · EL ARQUEO               → lo hace quien atiende, al empezar y al terminar su turno
#
# Atadas, el admin no podía gobernar la mesa a distancia —que es el punto entero del módulo: que
# pueda delegar tranquilo— y cualquier cosa que volviera al mostrador (un reparto fallido a las
# 23:00) dependía de que hubiera un turno abierto para tener dónde caer.
#
# Ahora el mostrador tiene su propio contenido, permanente. El turno se queda con lo suyo: contar
# al abrir y contar al cerrar.
class CreateMostradorItems < ActiveRecord::Migration[7.2]
  def up
    # Lo que hay AHORA sobre la mesa. Es la fuente de verdad del apartado: `Stock` lo lee para
    # descontarlo de su disponible, esté o no abierto el turno — el producto está físicamente ahí.
    create_table :mostrador_items do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :mostrador,  null: false, foreign_key: true
      t.references :stock,      null: false, foreign_key: true
      t.decimal :cantidad, precision: 10, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :mostrador_items, [:mostrador_id, :stock_id], unique: true,
              name: 'index_mostrador_items_unico_por_stock'

    # Cada subida y cada bajada, con quién y por qué. Sin esto, "hay 300 g" es un número que
    # apareció: el admin monitorea a distancia, y monitorear sin historial es mirar una foto.
    #
    # `turno_mostrador_id` es opcional a propósito: el admin carga la mesa a las 7 de la mañana,
    # cuando todavía no abrió nadie. Cuando SÍ hay turno, el movimiento queda atado a él para que
    # el arqueo de esa noche sepa qué pasó mientras estaba abierto.
    create_table :mostrador_movimientos do |t|
      t.references :club,            null: false, foreign_key: true
      t.references :mostrador_item,  null: false, foreign_key: true
      t.references :usuario,         null: false, foreign_key: { to_table: :users }
      t.references :turno_mostrador, null: true,  foreign_key: true
      t.string  :tipo, null: false
      # Firmada: positiva sube a la mesa, negativa la baja.
      t.decimal :cantidad, precision: 10, scale: 3, null: false
      t.string  :motivo
      t.timestamps
    end
    add_index :mostrador_movimientos, [:club_id, :created_at]

    # ── Backfill: lo que hoy está sobre la mesa de un turno ABIERTO pasa a ser el contenido del
    # mostrador. Sin esto, el día del deploy toda organización con el mostrador abierto se queda
    # con la mesa vacía y sin poder dispensar, con el producto igualmente apartado.
    execute <<~SQL
      INSERT INTO mostrador_items (club_id, mostrador_id, stock_id, cantidad, created_at, updated_at)
      SELECT i.club_id, t.mostrador_id, i.stock_id,
             GREATEST(i.cantidad_apertura + i.cantidad_repuesta - i.cantidad_devuelta
                      + i.cantidad_ajuste - i.cantidad_dispensada, 0),
             NOW(), NOW()
      FROM turno_mostrador_items i
      JOIN turno_mostradores t ON t.id = i.turno_mostrador_id
      WHERE t.estado = 'abierto'
      ON CONFLICT (mostrador_id, stock_id) DO NOTHING
    SQL

    # Lo que el turno decía que DEBERÍA haber al abrir, para poder mostrar la comparación del
    # cierre contra un número escrito y no calculado a mano. `cantidad_apertura` pasa a ser lo
    # CONTADO por quien abrió.
    add_column :turno_mostrador_items, :esperado_apertura, :decimal, precision: 10, scale: 3
    add_column :turno_mostrador_items, :esperado_cierre,   :decimal, precision: 10, scale: 3

    # El turno arranca contando: la "recepción" separada desaparece. Ya no hay una entrega que
    # firmar —el admin no abre nada— sino un conteo de apertura, que es la misma verificación en
    # un solo gesto.
    execute "UPDATE turno_mostrador_items SET esperado_apertura = cantidad_heredada WHERE cantidad_heredada IS NOT NULL"
  end

  def down
    remove_column :turno_mostrador_items, :esperado_apertura
    remove_column :turno_mostrador_items, :esperado_cierre
    drop_table :mostrador_movimientos
    drop_table :mostrador_items
  end
end
