# La dosis de la ETIQUETA y la medida casera de cada nutriente (Germán, 13-oct-2026).
#
# El dictado («le puse vege, un pulso a cada planta») guardaba los nutrientes como texto y no
# descontaba nada del depósito. Para calcular sin pedir cantidades, el nutriente sabe:
# - su medida casera: cuánto es «un pulso», «una tapita» (`medida_casera_cantidad`, en ml si se
#   mide en volumen o en g si se mide en peso);
# - la dosis que dice SU etiqueta para cada fase, en una unidad (`dosis_unidad`). La carga la
#   persona, copiada de su producto: la app no recomienda marcas ni cantidades (`Nutricion::Guia`).
class AgregarDosisAInsumos < ActiveRecord::Migration[7.2]
  def change
    add_column :insumos, :medida_casera, :string
    add_column :insumos, :medida_casera_cantidad, :decimal, precision: 10, scale: 3
    add_column :insumos, :dosis_unidad, :string
    add_column :insumos, :dosis_enraizado, :decimal, precision: 10, scale: 3
    add_column :insumos, :dosis_vegetativo, :decimal, precision: 10, scale: 3
    add_column :insumos, :dosis_floracion, :decimal, precision: 10, scale: 3
  end
end
