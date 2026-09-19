# Un gasto anotado «para un lote» cuya categoría no es insumo, energía ni mano de obra —una
# lámpara, una carpa, un tipo de gasto que el usuario creó— caía en `otro` y
# `CostoDesdeLibroService` no lo sumaba a ningún lado: el costo por gramo salía sin él y nadie
# se enteraba. `costo_prorrateado` no servía de cajón porque es manual (lo carga el usuario).
class AddCostoOtrosACostoLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :costo_lotes, :costo_otros, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
