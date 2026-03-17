class AddSedesAndPlan < ActiveRecord::Migration[7.2]
  def change

    # ── Tabla sedes ──────────────────────────────────────────
    create_table :sedes do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string  :nombre,               null: false
      t.string  :tipo,                 null: false, default: 'produccion'
      # tipos: produccion | social | mixta

      t.string  :direccion
      t.string  :ciudad
      t.string  :provincia
      t.string  :pais,                 default: 'Argentina'

      t.boolean :activa,               null: false, default: true
      t.boolean :declarada_reprocann,  null: false, default: false
      t.string  :reprocann_domicilio_id  # ID del domicilio declarado ante REPROCANN

      t.text    :notas

      t.timestamps
    end

    add_index :sedes, [:club_id, :activa]
    add_index :sedes, [:club_id, :tipo]

    # ── Agregar sede_id a salas ──────────────────────────────
    add_reference :salas, :sede, null: true, foreign_key: true

    # ── Agregar sede_id a dispensaciones ─────────────────────
    add_reference :dispensaciones, :sede, null: true, foreign_key: true

    # ── Plan en clubs ────────────────────────────────────────
    add_column :clubs, :plan,              :string,  default: 'semilla', null: false
    add_column :clubs, :plan_activo_hasta, :date
    add_column :clubs, :plan_trial,        :boolean, default: true, null: false
    add_column :clubs, :limites_custom,    :jsonb,   default: {}
    # limites_custom permite override manual por club (útil para demos y negociaciones)

    add_index :clubs, :plan

    # ── Inventario de sede social ────────────────────────────
    create_table :sede_inventarios do |t|
      t.references :sede,       null: false, foreign_key: true
      t.references :club,       null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string  :producto,     null: false  # flores | aceite | extracto | crema | otro
      t.string  :descripcion
      t.decimal :stock_gramos, precision: 10, scale: 2, default: 0, null: false
      t.decimal :stock_minimo, precision: 10, scale: 2, default: 0
      # alerta cuando stock < stock_minimo

      t.references :lote, null: true, foreign_key: true
      # de qué lote viene este stock

      t.timestamps
    end

    add_index :sede_inventarios, [:sede_id, :producto]

    # ── Movimientos de inventario (trazabilidad completa) ────
    create_table :inventario_movimientos do |t|
      t.references :sede,          null: false, foreign_key: true
      t.references :club,          null: false, foreign_key: true
      t.references :sede_inventario, null: false, foreign_key: true
      t.references :created_by,    null: false, foreign_key: { to_table: :users }
      t.references :dispensacion,  null: true,  foreign_key: { to_table: :dispensaciones }
      t.references :lote,          null: true,  foreign_key: true

      t.string  :tipo,          null: false
      # ingreso | egreso_dispensacion | egreso_merma | ajuste | transferencia

      t.decimal :cantidad,      precision: 10, scale: 2, null: false
      t.decimal :stock_anterior, precision: 10, scale: 2, null: false
      t.decimal :stock_nuevo,    precision: 10, scale: 2, null: false

      t.text    :motivo

      t.timestamps
    end

    add_index :inventario_movimientos, [:sede_id, :created_at]
    add_index :inventario_movimientos, [:sede_inventario_id, :created_at]
  end
end
