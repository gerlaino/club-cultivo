class AddTraceabilityToStocks < ActiveRecord::Migration[7.2]
  def up
    add_column :stocks, :pesada_id,             :bigint
    add_column :stocks, :club_id,               :bigint
    add_column :stocks, :numero_lote_producto,  :string
    add_column :stocks, :fecha_elaboracion,     :date
    add_column :stocks, :fecha_vencimiento_est, :date
    add_column :stocks, :codigo_qr,             :string

    # Backfill club_id desde sede primero, luego desde lote
    execute <<~SQL
      UPDATE stocks SET club_id = sedes.club_id
      FROM sedes WHERE stocks.sede_id = sedes.id
    SQL
    execute <<~SQL
      UPDATE stocks SET club_id = lotes.club_id
      FROM lotes WHERE stocks.lote_id = lotes.id AND stocks.club_id IS NULL
    SQL

    add_index :stocks, :pesada_id
    add_index :stocks, :club_id
    add_index :stocks, :numero_lote_producto, unique: true, where: "numero_lote_producto IS NOT NULL"
    add_index :stocks, :codigo_qr,            unique: true, where: "codigo_qr IS NOT NULL"

    add_foreign_key :stocks, :pesadas
    add_foreign_key :stocks, :clubs
  end

  def down
    remove_foreign_key :stocks, :pesadas
    remove_foreign_key :stocks, :clubs
    remove_column :stocks, :pesada_id
    remove_column :stocks, :club_id
    remove_column :stocks, :numero_lote_producto
    remove_column :stocks, :fecha_elaboracion
    remove_column :stocks, :fecha_vencimiento_est
    remove_column :stocks, :codigo_qr
  end
end
