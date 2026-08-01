# La maceta se guardaba con UN decimal, así que los tacos y macetitas de propagación no entraban:
# 0,335 L —una medida real y muy usada al salir del enraizado— se guardaba como 0,3.
#
# No es cosmético: `DIAS_MAX_EN_MACETA` decide cuándo avisar de raíz enrollada según el volumen, y
# en esos tamaños la diferencia entre 0,3 y 0,335 es de días.
#
# Ampliar precisión no pierde nada: los valores de un decimal que ya existen entran tal cual.
class MacetaConTresDecimales < ActiveRecord::Migration[7.2]
  def up
    change_column :lotes, :tamanio_maceta,         :decimal, precision: 6, scale: 3
    change_column :lotes, :tamanio_maceta_inicial, :decimal, precision: 6, scale: 3
  end

  def down
    change_column :lotes, :tamanio_maceta,         :decimal, precision: 4, scale: 1
    change_column :lotes, :tamanio_maceta_inicial, :decimal, precision: 4, scale: 1
  end
end
