class CreateResenasProducto < ActiveRecord::Migration[7.2]
  # Reseña de un paciente sobre el producto (genética) que recibió en una dispensa.
  # Feedback INTERNO para el club (no se muestra a otros pacientes). Una por
  # (dispensacion, genetica), editable por el paciente desde el pasaporte /d/:token.
  def change
    create_table :resenas_producto do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :paciente,     null: false, foreign_key: true
      t.references :genetica,     null: false, foreign_key: true
      # inflexión: la tabla de Dispensacion es 'dispensaciones', no 'dispensacions'
      t.references :dispensacion, null: false, foreign_key: { to_table: :dispensaciones }

      t.integer :estrellas,     null: false # 1..5 — valoración general
      t.integer :puntaje_sabor              # 1..5 — opcional
      t.integer :puntaje_aroma              # 1..5 — opcional
      t.integer :puntaje_efecto             # 1..5 — opcional (pegue)
      t.text    :comentario

      t.timestamps
    end

    # Una reseña por producto por dispensa (editable → find_or_initialize).
    add_index :resenas_producto, [:dispensacion_id, :genetica_id], unique: true, name: 'idx_resenas_disp_genetica'
    # Para agregar por genética en el panel del admin.
    add_index :resenas_producto, [:club_id, :genetica_id]
  end
end
