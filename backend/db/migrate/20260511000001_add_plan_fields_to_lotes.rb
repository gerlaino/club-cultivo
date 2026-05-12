class AddPlanFieldsToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :plants_count_objetivo,     :integer
    add_column :lotes, :rendimiento_objetivo_g,    :decimal, precision: 10, scale: 2
    add_column :lotes, :fecha_cosecha_estimada,    :date
    add_column :lotes, :rendimiento_real_g,        :decimal, precision: 10, scale: 2
    add_column :lotes, :plants_count_cosechadas,   :integer
  end
end
