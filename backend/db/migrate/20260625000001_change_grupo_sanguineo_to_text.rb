class ChangeGrupoSanguineoToText < ActiveRecord::Migration[7.2]
  # grupo_sanguineo era string(limit: 5). Al cifrarlo at-rest (Active Record
  # Encryption) el ciphertext supera ampliamente los 5 caracteres, así que la
  # columna pasa a :text. Cambio de tipo reversible.
  def up
    change_column :pacientes, :grupo_sanguineo, :text, limit: nil
  end

  def down
    change_column :pacientes, :grupo_sanguineo, :string, limit: 5
  end
end
