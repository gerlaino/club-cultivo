class AddEmailPersonalToUsers < ActiveRecord::Migration[7.2]
  # `email` es el USUARIO DE INGRESO (identificador de login Devise, puede ser inventado tipo
  # rol@club.com). `email_personal` es el email REAL del usuario, para mandarle correos.
  def change
    add_column :users, :email_personal, :string
  end
end
