class AddDiasObjetivoToLotes < ActiveRecord::Migration[7.2]
  # Estimados de duración por fase, en DÍAS (reemplazan a semanas_floracion). El sufijo
  # _objetivo es consistente con rendimiento_objetivo_g / plants_count_objetivo. Backfillea
  # el dato viejo (semanas × 7). semanas_floracion queda deprecado (sin uso en código).
  def up
    add_column :lotes, :dias_vegetativo_objetivo, :integer
    add_column :lotes, :dias_floracion_objetivo,  :integer
    add_column :lotes, :dias_cosecha_objetivo,     :integer
    execute "UPDATE lotes SET dias_floracion_objetivo = semanas_floracion * 7 WHERE semanas_floracion IS NOT NULL"
  end

  def down
    remove_column :lotes, :dias_vegetativo_objetivo
    remove_column :lotes, :dias_floracion_objetivo
    remove_column :lotes, :dias_cosecha_objetivo
  end
end
