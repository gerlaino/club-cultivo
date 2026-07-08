class CreateUnidadesNegocio < ActiveRecord::Migration[7.2]
  # Unidad de negocio = eje analítico ortogonal a la sede. Permite un P&L por
  # "área" (cultivo, dispensario, bar, administración) aunque convivan en la
  # misma sede física. Editable por cada club.
  def change
    create_table :unidades_negocio do |t|
      t.references :club, null: false, foreign_key: true
      t.string  :nombre,     null: false
      t.string  :tipo,       null: false, default: 'general' # cultivo/dispensario/bar/social/administracion/general
      t.string  :color
      t.integer :orden,      null: false, default: 0
      t.boolean :activa,     null: false, default: true
      t.boolean :es_sistema, null: false, default: false     # sembrada por el sistema; no borrable
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :unidades_negocio, :deleted_at
    add_index :unidades_negocio, [:club_id, :nombre]
  end
end
