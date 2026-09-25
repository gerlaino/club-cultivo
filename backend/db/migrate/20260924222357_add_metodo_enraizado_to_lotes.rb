# Dónde enraizó el lote: incubadora (hidroponía), jiffy o taco. Al pasar a maceta cambia el medio
# —la incubadora es agua, el vasito de 0,335 L es sustrato— y sin este dato no se sabía de dónde
# venía ni se podía comparar qué método prende mejor. Nullable: los lotes viejos no lo tienen.
class AddMetodoEnraizadoToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :metodo_enraizado, :string
  end
end
