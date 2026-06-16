class AllowNullPesadaIdOnPesadasPlantas < ActiveRecord::Migration[7.2]
  # El flujo nuevo de manicura registra el peso de cada planta contra un PesajeManicura
  # (pesaje_manicura_id), no contra una Pesada. El modelo ya declara `belongs_to :pesada,
  # optional: true`, pero la columna seguía siendo NOT NULL, así que guardar una
  # pesada_planta del flujo nuevo (pesada = nil) fallaba. Relajamos la restricción.
  def up
    change_column_null :pesadas_plantas, :pesada_id, true
  end

  def down
    # No revertir automáticamente: habría filas con pesada_id nil del flujo nuevo.
    raise ActiveRecord::IrreversibleMigration
  end
end
