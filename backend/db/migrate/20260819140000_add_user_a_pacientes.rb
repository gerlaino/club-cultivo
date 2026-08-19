class AddUserAPacientes < ActiveRecord::Migration[7.2]
  def change
    # La cuenta con la que el paciente entra a su portal. Nace con el alta (o con la aprobación,
    # si vino del mostrador) y es OPCIONAL: los pacientes que ya existen no tienen ninguna, y una
    # organización sin el módulo no necesita crearlas.
    add_reference :pacientes, :user, foreign_key: true, index: { unique: true }
  end
end
