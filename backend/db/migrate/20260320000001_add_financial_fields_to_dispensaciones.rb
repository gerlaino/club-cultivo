# backend/db/migrate/20260320000001_add_financial_fields_to_dispensaciones.rb
class AddFinancialFieldsToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column :dispensaciones, :aporte_socio_ars,    :decimal, precision: 10, scale: 2
    add_column :dispensaciones, :costo_por_gramo,     :decimal, precision: 10, scale: 2
    add_column :dispensaciones, :costo_total_calculado, :decimal, precision: 10, scale: 2
  end
end