class CreateNotas < ActiveRecord::Migration[7.2]
  def change
    create_table :notas do |t|
      t.string     :noteable_type, null: false
      t.bigint     :noteable_id,   null: false
      t.references :club,          null: false, foreign_key: true
      t.references :user,          null: false, foreign_key: true
      t.text       :contenido,     null: false
      t.string     :fuente,        default: 'manual'  # 'manual' | 'asistente_voz'
      t.datetime   :deleted_at

      t.timestamps
    end

    add_index :notas, [:noteable_type, :noteable_id]
    add_index :notas, :deleted_at
  end
end