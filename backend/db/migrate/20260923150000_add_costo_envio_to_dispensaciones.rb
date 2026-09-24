# EL VALOR DEL ENVÍO, APARTE DEL PRODUCTO (Germán, 23-sep-2026).
#
# Una dispensa con delivery puede cobrar el envío. Queda en su propia columna y se SUMA al total
# (`aporte_socio_ars`, que sigue siendo lo que paga el paciente): así los cobros, la contra
# entrega, el arqueo y la rendición siguen andando sin enterarse, y la pantalla puede decir
# «Productos · Envío · Total». En el libro va a su propia categoría («Envíos»).
#
# NULL = la dispensa no tiene envío, o es anterior a esto. 0 = envío BONIFICADO. Negativo, nunca.
class AddCostoEnvioToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column :dispensaciones, :costo_envio_ars, :decimal, precision: 10, scale: 2
    add_check_constraint :dispensaciones, 'costo_envio_ars IS NULL OR costo_envio_ars >= 0',
                         name: 'dispensaciones_costo_envio_no_negativo'
  end
end
