class CreateAuditorias < ActiveRecord::Migration[7.2]
  def up
    create_table :auditorias do |t|
      t.references :auditable, polymorphic: true, null: false, index: true
      t.references :club, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string     :accion, null: false   # crear | actualizar | eliminar
      t.jsonb      :cambios, default: {}  # update: { campo: [antes, después] } — create/destroy: snapshot
      t.datetime   :created_at, null: false
    end
    add_index :auditorias, [:club_id, :created_at]
  end

  def down
    drop_table :auditorias
  end
end
