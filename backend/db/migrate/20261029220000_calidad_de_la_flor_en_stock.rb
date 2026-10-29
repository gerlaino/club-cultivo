# Calidad de la flor seca (29-oct-2026; pedido de Javi, Germán: «sí», «obligatorio a partir de ahora»).
# Una organización separa la flor por calidad (altos, medios, bajos) y no tenía dónde decirlo: iba en
# la descripción como texto libre («copones», «bajos»). `calidad` sólo vale en flor seca; los frascos
# viejos quedan sin calidad y se les completa desde la edición. Ver `Stock::CALIDADES`.
class CalidadDeLaFlorEnStock < ActiveRecord::Migration[7.2]
  def change
    add_column :stocks, :calidad, :string
  end
end
