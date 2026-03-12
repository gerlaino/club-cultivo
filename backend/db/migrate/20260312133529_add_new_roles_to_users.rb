class AddNewRolesToUsers < ActiveRecord::Migration[7.2]
  def up
    # No necesitamos modificar la columna role ya que es un string
    # Solo documentamos los nuevos roles disponibles:
    # admin, medico, agricultor, cultivador, abogado, auditor, socio

    # Actualizar usuarios existentes si es necesario
    # User.where(role: nil).update_all(role: 'socio')
  end

  def down
    # Reversible
  end
end