# Horario del evento (B6 del rediseño del Salón): texto libre para admitir rangos como
# "22:00 a 05:00" o "desde las 21h". Opcional; complementa la fecha en el alta mínima.
class AddHorarioAEventosBar < ActiveRecord::Migration[7.2]
  def change
    add_column :eventos_bar, :horario, :string
  end
end
