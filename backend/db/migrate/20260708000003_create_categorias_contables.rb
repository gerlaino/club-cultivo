class CreateCategoriasContables < ActiveRecord::Migration[7.2]
  # Categoría contable editable por club. Reemplaza al enum hardcodeado
  # MovimientoContable::CATEGORIAS como fuente de verdad de cara al usuario.
  # `clave_sistema` mapea a la lógica legacy (aporte_socio, dispensacion, insumo…)
  # para que las categorías sembradas sigan disparando su comportamiento.
  def change
    create_table :categorias_contables do |t|
      t.references :club,           null: false, foreign_key: true
      t.references :unidad_negocio, null: true,  foreign_key: { to_table: :unidades_negocio }
      t.string  :nombre,        null: false
      t.string  :tipo,          null: false                 # ingreso / egreso
      t.string  :color
      t.string  :clave_sistema                              # nil para categorías propias del club
      t.integer :orden,         null: false, default: 0
      t.boolean :activa,        null: false, default: true
      t.boolean :es_sistema,    null: false, default: false # sembrada por el sistema; no borrable
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :categorias_contables, :deleted_at
    add_index :categorias_contables, [:club_id, :tipo]
    add_index :categorias_contables, [:club_id, :clave_sistema]
  end
end
