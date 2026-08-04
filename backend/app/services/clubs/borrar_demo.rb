module Clubs
  # Borra un club DEMO de verdad, para poder regenerarlo.
  #
  # `destroy` no alcanza: varios modelos usan paranoia (soft-delete), así que sus filas quedan y la
  # FK bloquea el borrado del padre —el caso concreto es `costo_lotes`, que ni siquiera se crea a
  # mano: lo genera el callback de cada movimiento contable—. Por eso va todo con `delete_all`.
  #
  # EL ORDEN SE DERIVA DE LA BASE, no de una lista escrita a mano. Con una lista, cada tabla que
  # alguien agregue al esquema rompe el purgado, y se descubre de a una: primero `costo_lotes`,
  # después `turnos`, después `jornadas_laborales`… Acá se recorren TODAS las tablas con `club_id` y
  # se reintenta en vueltas: cada pasada borra lo que ya quedó sin hijos, hasta que no queda nada.
  # Mismo resultado que un orden topológico, sin tener que mantenerlo.
  #
  # Solo funciona sobre clubes marcados `demo`: un club real no se borra así ni por accidente.
  class BorrarDemo
    def self.call(club:) = new(club: club).call

    def initialize(club:)
      @club = club
    end

    def call
      raise ArgumentError, "El club ##{@club.id} no está marcado como demo" unless @club.demo?

      ActsAsTenant.without_tenant do
        ActiveRecord::Base.transaction do
          vaciar(objetivos)
          User.unscoped.where(club_id: @club.id).delete_all
          Club.unscoped.where(id: @club.id).delete_all
        end
      end
    end

    private

    def conn = ActiveRecord::Base.connection

    # TODO lo que hay que vaciar, como pares (tabla, condición). Las que tienen `club_id` salen del
    # esquema; las que no, se alcanzan por su padre y son las únicas escritas a mano —no hay forma de
    # deducir por qué columna llegar—.
    #
    # Van todas juntas a la misma pasada A PROPÓSITO: entre ellas hay ciclos que no se pueden ordenar
    # de antemano (movimientos_contables → dispensaciones → pacientes, y pacientes tiene club_id
    # mientras que dispensaciones no). Fijar el orden a mano lleva a mover una y romper otra.
    def objetivos
      lote_ids     = ids_de('lotes',            'club_id')
      sala_ids     = ids_de('salas',            'club_id')
      stock_ids    = ids_de('stocks',           'club_id')
      paciente_ids = ids_de('pacientes',        'club_id')
      cc_ids       = ids_de('cuenta_corrientes','club_id')
      venta_ids    = ids_de('bar_ventas',       'club_id')
      plant_ids    = ids_por('plants',          'lote_id',     lote_ids)
      pesada_ids   = ids_por('pesadas',         'lote_id',     lote_ids)
      disp_ids     = ids_por('dispensaciones',  'paciente_id', paciente_ids)


      # Las notas son polimórficas: se limpian por su dueño.
      notas = { 'Lote' => lote_ids, 'Plant' => plant_ids, 'Sala' => sala_ids }
                 .reject { |_, ids| ids.empty? }
                 .map { |tipo, ids| ['notas', "noteable_type = '#{tipo}' AND noteable_id IN (#{ids.join(',')})"] }

      hijos = [
        ['dispensacion_items',           'dispensacion_id',     disp_ids],
        ['cobros',                       'dispensacion_id',     disp_ids],
        ['pesadas_plantas',              'pesada_id',           pesada_ids],
        ['stock_movimientos',            'stock_id',            stock_ids],
        ['plant_activities',             'plant_id',            plant_ids],
        ['cuenta_corriente_movimientos', 'cuenta_corriente_id', cc_ids],
        ['bar_venta_items',              'bar_venta_id',        venta_ids],
        ['sala_cultivadores',            'sala_id',             sala_ids],
        ['plan_tareas',                  'sala_id',             sala_ids],
        ['dispensaciones',               'paciente_id',         paciente_ids],
      ].filter_map do |tabla, columna, ids|
        next if ids.empty? || !conn.table_exists?(tabla) || !conn.column_exists?(tabla, columna)
        [tabla, "#{columna} IN (#{ids.join(',')})"]
      end

      con_club = conn.select_values(<<~SQL).map { |t| [t, "club_id = #{@club.id.to_i}"] }
        SELECT table_name FROM information_schema.columns
        WHERE column_name = 'club_id' AND table_schema = 'public' AND table_name <> 'users'
      SQL

      hijos + notas + con_club
    end

    # En vueltas: cada pasada borra lo que ya quedó sin hijos. Cuando una vuelta entera no logra
    # borrar nada, se corta y avisa, en vez de girar para siempre.
    def vaciar(pendientes)
      until pendientes.empty?
        antes = pendientes.size
        pendientes = pendientes.reject { |tabla, cond| intentar_borrar(tabla, cond) }
        break if pendientes.size == antes
      end

      return if pendientes.empty?
      raise "No se pudieron vaciar por dependencias: #{pendientes.map(&:first).uniq.join(', ')}"
    end

    # Cada tabla en su propio savepoint: sin eso, una violación de FK aborta la transacción entera y
    # no se podría seguir intentando con las demás.
    def intentar_borrar(tabla, condicion)
      ActiveRecord::Base.transaction(requires_new: true) do
        conn.execute("DELETE FROM #{conn.quote_table_name(tabla)} WHERE #{condicion}")
      end
      true
    rescue ActiveRecord::InvalidForeignKey
      false
    end

    def ids_de(tabla, columna)
      return [] unless conn.table_exists?(tabla)
      conn.select_values("SELECT id FROM #{tabla} WHERE #{columna} = #{@club.id.to_i}")
    end

    def ids_por(tabla, columna, valores)
      return [] if valores.empty? || !conn.table_exists?(tabla)
      conn.select_values("SELECT id FROM #{tabla} WHERE #{columna} IN (#{valores.join(',')})")
    end

  end
end
