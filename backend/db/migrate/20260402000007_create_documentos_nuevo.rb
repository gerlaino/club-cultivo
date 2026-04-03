class CreateDocumentos < ActiveRecord::Migration[7.2]
  def change
    create_table :documentos do |t|
      t.references :club,    null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string  :tipo,       null: false  # plan_trabajo | reprocann | informe_semestral | otro
      t.string  :titulo,     null: false
      t.text    :descripcion
      t.date    :fecha_vencimiento
      t.string  :estado,     default: 'vigente'  # vigente | vencido | pendiente
      t.timestamps
    end
    add_index :documentos, :tipo, if_not_exists: true
    add_index :documentos, :estado, if_not_exists: true
    add_index :documentos, :fecha_vencimiento, if_not_exists: true
  end
end