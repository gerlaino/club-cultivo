# Un retiro de caja siempre tiene un dueño.
#
# `created_by` dice quién REGISTRÓ el movimiento, que no es lo mismo que quién se llevó la plata:
# el admin puede anotar el retiro que hizo el supervisor. Sin distinguirlos, "$100.000 anotados a
# mí" queda anotado a quien tipeó, y a fin de mes no hay forma de saber quién tiene esa plata.
#
# Nulo porque sólo aplica a los retiros: un gasto pagado con la caja no se le atribuye a nadie,
# lo gastó la organización.
class AgregarRetiradoPorAMovimientosContables < ActiveRecord::Migration[7.2]
  def change
    add_reference :movimientos_contables, :retirado_por,
                  foreign_key: { to_table: :users }, null: true, index: true
  end
end
