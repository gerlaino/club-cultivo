# Un retiro de caja es una deuda ABIERTA hasta que se salda.
#
# En el momento de retirar casi nunca se sabe qué va a ser: el admin agarra $100.000 y todavía no
# está decidido si los devuelve, trae la factura o se los descuenta del sueldo. Por eso el retiro
# nace NEUTRO (`ajuste`, fuera de ingresos y egresos) y es el CIERRE el que define qué fue:
#
#   devuelto     → la plata vuelve. No hay gasto: se compensa, neto cero.
#   comprobante  → se convierte en un egreso real, con su categoría.
#   sueldo       → egreso de sueldo. Es el "adelanto", decidido al cerrar y no al retirar.
#
# El SALDO de cada persona no se guarda: sale de sumar sus retiros que siguen abiertos. Un saldo
# almacenado y sus movimientos son dos datos que hay que mantener coincidiendo — la misma tensión
# que ya arrastra la cuenta corriente del paciente. Acá hay una sola fuente de verdad.
class SaldarRetirosDeCaja < ActiveRecord::Migration[7.2]
  def change
    change_table :movimientos_contables, bulk: true do |t|
      t.datetime :saldado_at
      t.string   :saldado_como
      t.references :saldado_por, foreign_key: { to_table: :users }, null: true, index: true
      # El movimiento que generó el cierre (el egreso, o la devolución). Ida y vuelta: desde el
      # retiro se llega a lo que lo cerró, y desde el egreso se llega al retiro que lo originó.
      t.references :salda_a, foreign_key: { to_table: :movimientos_contables }, null: true, index: true
    end

    # Los retiros abiertos se consultan seguido y siempre igual: por organización y sin saldar.
    add_index :movimientos_contables, [:club_id, :retirado_por_id],
              where: "categoria = 'retiro_caja' AND saldado_at IS NULL",
              name: 'index_retiros_abiertos_por_persona'
  end
end
