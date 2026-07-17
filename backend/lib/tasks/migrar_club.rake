# Migra TODOS los datos de un club a otro (reasigna club_id).
#
# Pensado para el caso "graduar" un club de prueba a uno real: se cargó data real en un club
# TEST y se quiere pasar a un club nuevo (destino VACÍO). Como todo el dominio está scopeado
# por club_id, la migración es reasignar ese club_id de origen → destino.
#
# Uso:
#   # 1) SIEMPRE primero en seco (no escribe nada, solo reporta qué movería):
#   DRY_RUN=1 bundle exec rake "migrar_club[ORIGEN_ID,DESTINO_ID]"
#
#   # 2) Real (mueve también los usuarios; sacá MOVE_USERS si no querés moverlos):
#   MOVE_USERS=1 bundle exec rake "migrar_club[ORIGEN_ID,DESTINO_ID]"
#
# Seguridad:
#   - Exige que el DESTINO esté vacío de datos de dominio (abortá si no; FORCE=1 lo saltea).
#   - Corre en UNA transacción: si algo falla, no queda nada a medias.
#   - update_all: no dispara callbacks ni validaciones (deseado — es una reasignación masiva).
#   - Hacé un backup de la DB ANTES igual. Es reversible con el backup, no in-place.
#   - Probalo antes en una copia de la base de prod.
desc 'Migra todos los datos (y opcionalmente usuarios) de un club a otro'
task :migrar_club, [:origen_id, :destino_id] => :environment do |_t, args|
  origen_id  = Integer(args[:origen_id]  || abort('Falta ORIGEN_ID'))
  destino_id = Integer(args[:destino_id] || abort('Falta DESTINO_ID'))
  abort('Origen y destino no pueden ser el mismo club') if origen_id == destino_id

  dry_run    = ENV['DRY_RUN'].present?
  move_users = ENV['MOVE_USERS'].present?
  force      = ENV['FORCE'].present?

  ActsAsTenant.without_tenant do
    origen  = Club.find(origen_id)
    destino = Club.find(destino_id)
    puts "Origen : ##{origen.id} #{origen.name}"
    puts "Destino: ##{destino.id} #{destino.name}"
    puts "Modo   : #{dry_run ? 'DRY RUN (no escribe)' : 'REAL'}#{move_users ? ' + mueve usuarios' : ''}"
    puts '-' * 60

    # Modelos de dominio: todo lo que tiene club_id, menos User (auth, se maneja aparte).
    Rails.application.eager_load!
    modelos = ApplicationRecord.descendants.select do |m|
      m.table_exists? && m.column_names.include?('club_id') && m != User && !m.abstract_class?
    end.uniq.sort_by(&:name)

    # Chequeo de destino vacío (evita mergear sin querer sobre datos existentes).
    ocupados = modelos.reject { |m| m.unscoped.where(club_id: destino_id).limit(1).count.zero? }
    if ocupados.any? && !force
      puts "\n⚠️  El destino NO está vacío. Tiene datos en: #{ocupados.map(&:name).join(', ')}"
      abort('Abortado. Este task es para un destino vacío. Si querés mergear igual, corré con FORCE=1 (revisá colisiones de unicidad primero).')
    end

    total = 0
    ActiveRecord::Base.transaction do
      if move_users
        n = User.where(club_id: origen_id).count
        User.where(club_id: origen_id).update_all(club_id: destino_id) unless dry_run
        puts format('%-32s %6d usuarios', 'User', n)
        total += n
      end

      modelos.each do |m|
        n = m.unscoped.where(club_id: origen_id).count
        next if n.zero?
        m.unscoped.where(club_id: origen_id).update_all(club_id: destino_id) unless dry_run
        puts format('%-32s %6d', m.name, n)
        total += n
      end

      puts '-' * 60
      puts "Total de filas #{dry_run ? 'a mover' : 'movidas'}: #{total}"
      raise ActiveRecord::Rollback if dry_run # en seco, deshacer todo
    end

    # Verificación: el origen quedó sin datos de dominio (salvo lo global con club_id nil).
    unless dry_run
      restante = modelos.sum { |m| m.unscoped.where(club_id: origen_id).count }
      restante += User.where(club_id: origen_id).count if move_users
      puts restante.zero? ? '✅ Origen quedó sin datos de dominio.' : "⚠️  Quedaron #{restante} filas en el origen (revisar)."
    end
  end
end
