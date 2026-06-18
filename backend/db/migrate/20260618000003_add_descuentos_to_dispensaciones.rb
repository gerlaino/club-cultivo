class AddDescuentosToDispensaciones < ActiveRecord::Migration[7.2]
  # Dos descuentos distintos por dispensación, para trazabilidad en el detalle:
  # - descuento_paciente_pct: el de la ficha del socio (lo fija el admin, privado).
  # - descuento_dispensa_pct: el puntual que otorga quien dispensa en el momento.
  # El "quién otorgó" es el user_id de la dispensación (ya existente).
  def change
    change_table :dispensaciones, bulk: true do |t|
      t.decimal :descuento_paciente_pct, precision: 5, scale: 2, default: 0, null: false
      t.decimal :descuento_dispensa_pct, precision: 5, scale: 2, default: 0, null: false
    end
  end
end
