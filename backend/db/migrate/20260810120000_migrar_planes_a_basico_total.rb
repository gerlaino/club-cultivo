class MigrarPlanesABasicoTotal < ActiveRecord::Migration[7.2]
  # Los cuatro planes (semilla/brote/cosecha/federación) pasan a dos: básico y total.
  #
  # El cambio de fondo no es la cantidad: es que el plan ahora dice CUÁNTO y nunca QUÉ. Antes
  # convivían dos sistemas contradictorios —el plan fijaba los límites duros y las suites
  # decidían las capacidades—, así que un club "federación" sin suites quedaba sin límites y
  # sin poder hacer nada. Ahora los límites son del plan y los módulos son de las suites.
  #
  # Reversible: `down` devuelve todos los básicos a "semilla" y los totales a "federación".
  # No recupera el plan exacto que cada club tenía (cuatro valores no entran en dos), pero
  # deja el sistema consistente, que es lo que importa para poder volver atrás.

  MAPEO = {
    'semilla'    => 'basico',
    'brote'      => 'basico',
    'cosecha'    => 'total',
    'federacion' => 'total',
  }.freeze

  def up
    MAPEO.each do |viejo, nuevo|
      execute "UPDATE clubs SET plan = '#{nuevo}' WHERE plan = '#{viejo}'"
    end
    # Cualquier valor huérfano (seeds viejos, copias) cae al plan chico: es el conservador.
    execute "UPDATE clubs SET plan = 'basico' WHERE plan NOT IN ('basico', 'total')"

    change_column_default :clubs, :plan, from: 'semilla', to: 'basico'
  end

  def down
    change_column_default :clubs, :plan, from: 'basico', to: 'semilla'

    execute "UPDATE clubs SET plan = 'semilla'    WHERE plan = 'basico'"
    execute "UPDATE clubs SET plan = 'federacion' WHERE plan = 'total'"
  end
end
