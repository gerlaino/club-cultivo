class CreateLoteEventos < ActiveRecord::Migration[7.2]
  def change
    create_table :lote_eventos do |t|
      t.references :lote,  null: false, foreign_key: true
      t.references :user,  null: false, foreign_key: true
      t.references :club,  null: false, foreign_key: true

      t.string  :tipo,            null: false  # cambio_estado | nota | alerta
      t.string  :estado_anterior
      t.string  :estado_nuevo
      t.text    :descripcion
      t.datetime :registrado_en,  null: false

      t.timestamps
    end

    add_index :lote_eventos, :lote_id, if_not_exists: true
    add_index :lote_eventos, :registrado_en, if_not_exists: true
    add_index :lote_eventos, :tipo, if_not_exists: true
  end
end