# Cobro recurrente con Mercado Pago (Germán, 12-oct-2026). Una suscripción por organización: la
# de una organización la genera super admin con su monto; la del autocultivo, la persona, con el
# precio fijo que se carga en super admin (`ajustes_plataforma`). La verdad vive acá, alimentada
# por el webhook de MP; cada cobro aprobado extiende `clubs.plan_activo_hasta`.
class CrearSuscripcionesMercadoPago < ActiveRecord::Migration[7.2]
  def change
    create_table :suscripciones do |t|
      t.references :club, null: false, foreign_key: true
      t.string  :mp_preapproval_id
      t.string  :estado, null: false, default: 'pendiente' # pendiente | activa | pausada | cancelada
      t.string  :origen, null: false                        # organizacion | autocultivo
      t.decimal :monto_ars, precision: 12, scale: 2, null: false
      t.string  :payer_email, null: false
      t.string  :motivo, null: false
      t.string  :link
      t.references :creada_por, foreign_key: { to_table: :users }
      t.datetime :ultimo_cobro_at
      t.jsonb   :mp_datos, null: false, default: {}
      t.timestamps
    end
    add_index :suscripciones, :mp_preapproval_id, unique: true
    add_index :suscripciones, %i[club_id estado]

    create_table :suscripcion_cobros do |t|
      t.references :suscripcion, null: false, foreign_key: { to_table: :suscripciones }
      t.string   :mp_id, null: false
      t.string   :estado, null: false
      t.decimal  :monto_ars, precision: 12, scale: 2
      t.datetime :cobrado_at
      t.date     :extiende_hasta
      t.jsonb    :mp_datos, null: false, default: {}
      t.timestamps
    end
    add_index :suscripcion_cobros, :mp_id, unique: true

    create_table :ajustes_plataforma do |t|
      t.string :clave, null: false
      t.jsonb  :valor, null: false, default: {}
      t.references :actualizado_por, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :ajustes_plataforma, :clave, unique: true
  end
end
