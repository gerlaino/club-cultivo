class FixSalaKindDefault < ActiveRecord::Migration[7.2]
  # `kind` es el campo operativo de clasificación de sala en todo el backend
  # (roles, filtros, transiciones). El default heredado "indoor" no es un tipo
  # válido y dejaba las salas creadas en onboarding sin clasificación real.
  # Consolidamos: default sano (vegetativo) y backfill de las "indoor".
  def up
    change_column_default :salas, :kind, from: 'indoor', to: 'vegetativo'
    say_with_time 'Backfill kind desde tipo (onboarding viejo dejó kind=indoor, tipo real)' do
      # Las salas del onboarding viejo tienen el tipo real en `tipo`; lo recuperamos.
      execute <<~SQL.squish
        UPDATE salas SET kind = tipo
        WHERE kind = 'indoor' AND tipo IS NOT NULL AND tipo NOT IN ('cultivo', '')
      SQL
      # Las que no tienen un tipo útil quedan en el default sano.
      execute "UPDATE salas SET kind = 'vegetativo' WHERE kind = 'indoor'"
    end
  end

  def down
    change_column_default :salas, :kind, from: 'vegetativo', to: 'indoor'
  end
end
