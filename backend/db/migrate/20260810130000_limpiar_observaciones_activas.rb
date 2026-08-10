class LimpiarObservacionesActivas < ActiveRecord::Migration[7.2]
  # El modo observador queda SUSPENDIDO (ver User::OBSERVADOR_HABILITADO): está construido a
  # medias y entrar a medias a un club que está trabajando se nota.
  #
  # Con la bandera apagada una observación guardada ya no hace nada, pero se limpia igual: si
  # no, el día que se reactive el modo, cualquier super admin que hubiera quedado con
  # `observer_club_id` cargado volvería a la sesión enmascarada de un club, sin haberlo pedido
  # y sin enterarse.
  #
  # Sin `down`: restaurar observaciones viejas no tendría ningún sentido.
  def up
    limpiados = execute(<<~SQL).cmd_tuples
      UPDATE users
      SET observer_club_id = NULL, observer_token = NULL, observer_expires_at = NULL
      WHERE observer_club_id IS NOT NULL
         OR observer_token IS NOT NULL
         OR observer_expires_at IS NOT NULL
    SQL

    say "observaciones limpiadas: #{limpiados}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
