class CreateReprocannRenovaciones < ActiveRecord::Migration[7.2]
  def change
    create_table :reprocann_renovaciones do |t|
      t.references :paciente, null: false, foreign_key: true
      t.references :club,     null: false, foreign_key: true
      t.string  :estado,           null: false, default: 'en_tramite'
      t.string  :numero_tramite
      t.date    :fecha_inicio,     null: false
      t.date    :fecha_aprobacion
      t.date    :fecha_vencimiento_nueva
      t.text    :observaciones
      t.string  :reprocann_numero_nuevo
      t.references :iniciada_por,  foreign_key: { to_table: :users }, null: true
      t.timestamps
    end

    add_index :reprocann_renovaciones, [:paciente_id, :estado]
    add_index :reprocann_renovaciones, :estado
  end
end
