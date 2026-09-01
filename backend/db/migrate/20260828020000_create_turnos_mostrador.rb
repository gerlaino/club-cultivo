# El turno del MOSTRADOR: la caja de turno, pero con mercadería.
#
# Se abre y se cierra desde la misma vista, y se puede abrir y cerrar varias veces por día: dos
# dispensadores no atienden a la vez, se turnan. Por eso NO hay relevo con firma cruzada — el
# que tuvo la mercadería es el que la contó, y cerrar-y-reabrir ES el arqueo. Pedirle a quien
# entra que vuelva a contar lo que se contó hace diez horas termina en una firma que nadie miró.
#
# La mecánica del stock es la del apartado de un evento (`EventoBarProvision`): cargar el
# mostrador BLOQUEA la cantidad, no la descuenta. La fila `Stock` sigue siendo una sola, con su
# ST-xx y su QR: lo trazable sale del inventario por dispensación, nunca por cambiar de mesa.
class CreateTurnosMostrador < ActiveRecord::Migration[7.2]
  def change
    create_table :turno_mostradores do |t|
      t.references :club,      null: false, foreign_key: true
      t.references :mostrador, null: false, foreign_key: { to_table: :mostradores }
      # La caja de plata del mismo turno. Se abren y se cierran juntas —un gesto, dos arqueos—
      # pero son registros separados porque son dos cuentas distintas con dos destinos contables
      # distintos: el efectivo va al libro, los gramos al inventario.
      t.references :caja_turno,     foreign_key: true
      t.references :turno_anterior, foreign_key: { to_table: :turno_mostradores }

      t.string   :estado, null: false, default: 'abierto' # abierto | cerrado | anulado
      t.references :abierto_por, null: false, foreign_key: { to_table: :users }
      t.datetime :abierto_at,    null: false
      t.references :cerrado_por, foreign_key: { to_table: :users }
      t.datetime :cerrado_at

      # El aval del admin es ASINCRÓNICO: el turno cierra sin esperarlo. Si el cierre dependiera
      # de que el admin esté, a las 11 de la noche el mostrador queda bloqueado y el que abre
      # mañana no puede arrancar.
      t.references :revisado_por, foreign_key: { to_table: :users }
      t.datetime :revisado_at

      t.string   :notas_apertura
      t.string   :notas_cierre
      t.timestamps
    end

    # Un turno abierto por mostrador, igual que la caja. La validación da el mensaje lindo; la
    # garantía real la da el índice.
    add_index :turno_mostradores, :mostrador_id,
              unique: true, where: "estado = 'abierto'",
              name: 'index_turno_mostradores_abierto_por_mostrador'
    add_index :turno_mostradores, [:club_id, :estado]

    create_table :turno_mostrador_items do |t|
      t.references :club,             null: false, foreign_key: true
      t.references :turno_mostrador,  null: false, foreign_key: { to_table: :turno_mostradores }
      t.references :stock,            null: false, foreign_key: true

      # Las siete cantidades. La verdad del ítem sale de ellas y no se guarda calculada:
      #   esperado = apertura + repuesta - devuelta + ajuste - dispensada
      # Ese mismo número es lo que el ítem BLOQUEA y lo que el dispensador puede dispensar.
      #
      # `heredada` es lo que dejó el turno anterior; `apertura` es con lo que se arranca de
      # verdad. Vienen iguales, y el que abre puede corregir `apertura` si el frasco no da: eso
      # es un campo editable, no una ceremonia de conteo.
      t.decimal :cantidad_heredada,   precision: 10, scale: 3
      t.decimal :cantidad_apertura,   precision: 10, scale: 3, null: false, default: 0
      t.decimal :cantidad_repuesta,   precision: 10, scale: 3, null: false, default: 0
      t.decimal :cantidad_devuelta,   precision: 10, scale: 3, null: false, default: 0
      t.decimal :cantidad_ajuste,     precision: 10, scale: 3, null: false, default: 0
      t.decimal :cantidad_dispensada, precision: 10, scale: 3, null: false, default: 0
      t.decimal :cantidad_cierre,     precision: 10, scale: 3

      t.string  :motivo_diferencia
      t.timestamps
    end
    add_index :turno_mostrador_items, [:turno_mostrador_id, :stock_id],
              unique: true, name: 'index_turno_mostrador_items_unico_por_stock'

    # El rastro de cada carga y cada devolución, con hora y autor. Es lo que hace que delegar
    # sirva: sin esto, "se repuso" es un número que apareció y nadie sabe quién lo puso.
    create_table :turno_mostrador_movimientos do |t|
      t.references :club, null: false, foreign_key: true
      t.references :turno_mostrador_item, null: false, foreign_key: true,
                   index: { name: 'index_tmm_on_item' }
      t.references :usuario, null: false, foreign_key: { to_table: :users }

      t.string  :tipo, null: false # carga | devolucion
      t.decimal :cantidad, precision: 10, scale: 3, null: false
      # Sacar mercadería del depósito es de admin/supervisor, pero si a las 8 de la noche no hay
      # ninguno, bloquear al dispensador es mandar pacientes a casa: la llave del depósito la
      # tiene igual. Se permite, se marca, y cae en la bandeja del admin.
      t.boolean :sin_supervision, null: false, default: false
      t.string  :notas
      t.timestamps
    end
  end
end
