class CreateConversacionesAsistente < ActiveRecord::Migration[7.1]
  def change
    create_table :conversaciones_asistente do |t|
      t.references :club, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date  :fecha,    null: false
      t.jsonb :mensajes, null: false, default: []
      t.timestamps
    end
    add_index :conversaciones_asistente, [:user_id, :fecha], unique: true
  end
end
