# CUÁNTO TARDA LA APP EN CONTESTAR, por hora (7-oct-2026, panel de Estado). Una fila por hora,
# por lo que se pidió («DispensacionesController#index») y por organización: cuántas veces, cuánto
# sumaron y en qué franja cayó cada una (`b0`…`b7`, ver `Metricas::Respuesta::FRANJAS_MS`). Con
# las franjas se saca «cuánto tarda la mayoría de las veces» sin guardar cada pedido.
# Germán eligió tabla y no Redis: que quede historia para comparar días.
class CrearMetricasRespuesta < ActiveRecord::Migration[7.2]
  def change
    create_table :metricas_respuesta do |t|
      t.datetime :hora,      null: false
      t.string   :endpoint,  null: false
      t.bigint   :club_id,   null: false, default: 0   # 0 = sin organización (super admin, login)
      t.integer  :cantidad,  null: false, default: 0
      t.bigint   :total_ms,  null: false, default: 0
      t.integer  :max_ms,    null: false, default: 0
      (0..7).each { |i| t.integer :"b#{i}", null: false, default: 0 }
    end
    add_index :metricas_respuesta, %i[hora endpoint club_id], unique: true, name: 'idx_metricas_respuesta_unica'
    add_index :metricas_respuesta, :hora
  end
end
