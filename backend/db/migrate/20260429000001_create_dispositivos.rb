class CreateDispositivos < ActiveRecord::Migration[7.2]
  def change
    create_table :dispositivos do |t|
      t.references :club,  null: false, foreign_key: true
      t.references :sala,  null: false, foreign_key: true

      t.string  :tipo,            null: false
      t.string  :marca
      t.string  :modelo
      t.string  :serial
      t.string  :nombre_amigable, null: false
      t.string  :estado,          null: false, default: 'activo'
      t.datetime :ultima_lectura_at
      t.string  :webhook_token_digest
      t.datetime :last_token_rotated_at
      t.jsonb   :metadata, null: false, default: {}

      t.timestamps
    end

    # Índices de club_id y sala_id ya creados por t.references
    add_index :dispositivos, [:club_id, :serial],
              unique: true,
              where: 'serial IS NOT NULL',
              name: 'idx_dispositivos_serial'
  end
end
