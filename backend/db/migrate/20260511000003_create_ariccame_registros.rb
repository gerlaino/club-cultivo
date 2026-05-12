class CreateAriccameRegistros < ActiveRecord::Migration[7.2]
  def change
    create_table :ariccame_registros do |t|
      t.references :club,     null: false, foreign_key: true
      t.string  :tipo,        null: false  # entrada_producto | dispensacion | ajuste
      t.string  :estado,      null: false, default: 'pendiente'  # pendiente | enviado | confirmado | error | omitido
      t.jsonb   :payload,     null: false, default: {}
      t.jsonb   :respuesta,              default: {}
      t.string  :codigo_ariccame        # código asignado por ANMAT al confirmar
      t.string  :error_mensaje
      t.integer :intentos,              default: 0
      t.datetime :enviado_at
      t.datetime :confirmado_at
      t.references :stock,         foreign_key: true, null: true
      t.references :dispensacion,  foreign_key: { to_table: :dispensaciones }, null: true
      t.timestamps
    end

    add_index :ariccame_registros, [:club_id, :estado]
    add_index :ariccame_registros, [:club_id, :tipo]
    add_index :ariccame_registros, :estado
    add_index :ariccame_registros, :codigo_ariccame, where: "codigo_ariccame IS NOT NULL"
  end
end
