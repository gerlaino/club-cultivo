# Cuándo declaró ser mayor de 18 años quien se registró solo (9-oct-2026). Era parte del tilde de
# los términos; ahora es una declaración propia, que el alta exige y que queda con su fecha (la IP
# y el navegador ya se guardan en el registro). Los registros viejos quedan en nil: aceptaron el
# tilde combinado, que también lo decía.
class AgregarMayorEdadARegistrosPersonales < ActiveRecord::Migration[7.2]
  def change
    add_column :registros_personales, :mayor_edad_declarada_at, :datetime
  end
end
