# Padrón inicial de Mitocondria, tomado del listado de trámites REPROCANN.
#
# Origen: 6 capturas de pantalla del sistema REPROCANN (no permite exportar) + una planilla
# parcial de DNI. Son 58 trámites que, deduplicados por persona, dan 49 pacientes.
#
# Cómo se dedujo el estado de cada uno: gana el trámite APROBADO (nadie tiene dos). Si sólo
# tiene pendiente va `pendiente`; si sólo tiene anulados va `sin_registro` y SIN número —
# con número cargado, el informe de Cumplimiento los contaría como "con REPROCANN" mientras
# el estado dice sin_registro, y los totales dejan de cerrar.
#
# ⚠️ 29 DE LOS 49 LLEVAN DNI PROVISORIO (90.000.001–90.000.029). Los DNI argentinos reales de
# adultos están entre 20 y 70 millones, así que nada en 90M pisa a una persona real. Se ubican
# después con `WHERE dni_normalizado LIKE '9%'`. Los otros 20 son reales, de la planilla.
#
# ⚠️ LA FECHA DE NACIMIENTO ES INVENTADA EN LOS 49. No viene ni en el listado ni en la planilla,
# y es obligatoria en `Paciente`. Hay que completarla.
#
# Uso:
#   bundle exec rake pacientes:mitocondria SIMULAR=1   # reporta, no escribe
#   bundle exec rake pacientes:mitocondria             # carga (en una transacción)
#   CLUB_ID=42 bundle exec rake pacientes:mitocondria  # si el nombre no alcanza
#
# Sin CLUB_ID apunta al Mitocondria MÁS NUEVO: hay varios (el de prueba y el real), y el real
# es el último creado. Siempre imprime cuál eligió antes de tocar nada.
#
# Es un UPSERT y se puede correr las veces que haga falta. Busca a cada persona por DNI dentro
# de la organización y, si no la encuentra, por número de trámite —así un paciente cargado con
# DNI provisorio recibe el real cuando aparece, en vez de duplicarse—. De los que ya existen
# actualiza nombre, DNI y los tres campos de REPROCANN; NO les toca la fecha de nacimiento, que
# puede ser real y acá es inventada.
namespace :pacientes do
  # nombre, apellido, dni, nacimiento, nro de trámite, estado, vencimiento
  MITOCONDRIA = [
    ['Pablo Hernan',          'Arevalos',                90_000_001,  '1990-02-19',   441_345, 'pendiente',    nil],  # DNI provisorio
    ['Agustina Sofia',        'Duarte',                  90_000_002,  '1995-08-06',   439_804, 'pendiente',    nil],  # DNI provisorio
    ['Juan Bautista',         'Rossi',                   90_000_003,  '2000-03-24',   428_546, 'activo',       '2029-08-10'],  # DNI provisorio
    ['Federico Hernan',       'Rey',                     90_000_004,  '1988-03-14',   428_517, 'activo',       '2029-08-07'],  # DNI provisorio
    ['Franco Augusto',        'Carlino Currenti',        36_276_151,  '1990-07-31',   426_922, 'pendiente',    nil],
    ['Alan Mauricio',         'Rodriguez',               90_000_005,  '1991-07-02',   426_918, 'activo',       '2029-08-06'],  # DNI provisorio
    ['Paz Nazarena',          'Krasko Camillo',          90_000_006,  '1993-04-30',   426_917, 'pendiente',    nil],  # DNI provisorio
    ['Fabrizio',              'Pujante Martignoni',      90_000_007,  '1993-11-12',   419_591, 'pendiente',    nil],  # DNI provisorio
    ['Augusto',               'Grizzuti',                40_398_015,  '1985-11-23',   419_564, 'activo',       '2029-07-03'],
    ['Leandro Ariel',         'Barreto',                 36_594_520,  '1979-05-08',   419_544, 'activo',       '2029-07-03'],
    ['Santino',               'Nanni',                   90_000_008,  '1997-01-30',   419_520, 'activo',       '2029-07-03'],  # DNI provisorio
    ['Diego Ariel',           'Pascar',                  30_700_066,  '1983-09-17',   396_049, 'activo',       '2029-06-03'],
    ['Sebastian',             'Perez Porta',             90_000_009,  '1990-12-05',   395_596, 'activo',       '2029-06-02'],  # DNI provisorio
    ['Martina',               'De Maio',                 90_000_010,  '1994-04-21',   393_554, 'activo',       '2029-06-19'],  # DNI provisorio
    ['Federico Jose',         'Llaurado',                42_724_200,  '1987-08-11',   385_389, 'activo',       '2029-05-19'],
    ['Martin Ariel',          'Pinasco',                 90_000_011,  '1976-02-26',   382_124, 'activo',       '2029-05-26'],  # DNI provisorio
    ['Alejandro Daniel',      'Fernandez',               90_000_012,  '1982-06-13',   382_123, 'activo',       '2029-05-20'],  # DNI provisorio
    ['Nicolas Domingo',       'Scordamaglia',            90_000_013,  '1993-10-09',   382_104, 'activo',       '2029-05-15'],  # DNI provisorio
    ['Thomas',                'Palavecino Martignoni',   90_000_014,  '1999-03-28',   382_098, 'activo',       '2029-05-26'],  # DNI provisorio
    ['Benicio',               'Raineri',                 46_025_359,  '2001-07-16',   375_852, 'activo',       '2029-04-09'],
    ['Joaquin Ignacio',       'Jauregui Marcos',         46_290_034,  '1996-11-04',   375_851, 'activo',       '2029-04-09'],
    ['Alan Alexis',           'Paez Gunsett',            36_702_084,  '1989-01-19',   375_835, 'activo',       '2029-05-18'],
    ['Micaela Milagros',      'Testino',                 90_000_015,  '1992-05-27',   374_070, 'activo',       '2029-05-13'],  # DNI provisorio
    ['Cristian',              'Rolando',                 36_608_665,  '1991-06-12',   371_051, 'activo',       '2029-05-13'],
    ['Cristian Nahuel',       'Carruega',                36_388_606,  '1991-09-25',   371_046, 'activo',       '2029-03-31'],
    ['Agustín Ignacio',       'Cánepa',                  36_872_481,  '1992-01-17',   370_962, 'activo',       '2029-04-01'],
    ['Mauro Rafael',          'Ablin',                   90_000_016,  '1987-10-08',   364_786, 'activo',       '2029-03-17'],  # DNI provisorio
    ['Maria Belen',           'Korta',                   38_326_057,  '1994-03-21',   362_354, 'activo',       '2029-03-31'],
    ['Gabriel Alejandro',     'Varsalona',               35_960_726,  '1990-11-02',   361_685, 'activo',       '2029-03-17'],
    ['Maria Laura Nazaret',   'Belfiglio Ottati',        42_644_106,  '1999-07-14',   358_994, 'activo',       '2029-03-13'],
    ['Aldana',                'Montelvetti',             38_787_490,  '1995-05-29',   358_993, 'activo',       '2029-03-07'],
    ['Ulises Adrian',         'Martinez',                90_000_017,  '1988-05-02',   358_877, 'activo',       '2029-03-20'],  # DNI provisorio
    ['Mauro Daniel',          'Agüero',                  90_000_018,  '1980-09-03',   358_875, 'activo',       '2029-03-20'],  # DNI provisorio
    ['Marcelo',               'Marty',                   90_000_019,  '1972-09-20',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Nicolas',               'Calandroni',              90_000_020,  '1991-12-08',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Marcos',                'Sibbald',                 90_000_021,  '1985-04-16',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Roberto Jose',          'Finkelberg',              90_000_022,  '1968-08-25',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Alejo Nicolas',         'Fernandez Fortuny',       90_000_023,  '1997-02-03',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Néstor Nehuen',         'Bertora',                 90_000_024,  '1994-10-14',       nil, 'sin_registro', nil],  # DNI provisorio
    ['German Jose',           'Laino',                   36_720_518,  '1986-12-22',   272_626, 'activo',       '2028-02-11'],
    ['Enrique Emmanuel',      'Ovelar',                  90_000_025,  '1983-06-07',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Sheila Chantal',        'Schurmann',               90_000_026,  '1996-01-28',       nil, 'sin_registro', nil],  # DNI provisorio
    ['Juan Ignacio',          'Bravo',                   41_586_441,  '1979-11-09',       nil, 'sin_registro', nil],
    ['Marcos Nicolas',        'Casuso',                  38_425_086,  '1978-04-07',   195_577, 'activo',       '2026-11-02'],
    ['Martin Andres',         'Corizzo',                 36_066_222,  '1984-08-15',   191_802, 'activo',       '2026-11-02'],
    ['Geronimo',              'Ortigoza',                90_000_027,  '1995-02-11',   162_178, 'activo',       '2026-08-28'],  # DNI provisorio
    ['Natanael',              'Casuso',                  90_000_028,  '1998-06-29',   162_151, 'activo',       '2026-08-28'],  # DNI provisorio
    ['Martin Ezequiel',       'Blanco',                  90_000_029,  '1981-10-18',   162_114, 'activo',       '2026-08-28'],  # DNI provisorio
    ['Federico Cesar',        'Garcia Bulz',             34_705_281,  '1975-01-06',    18_363, 'activo',       '2026-12-15'],
  ].freeze

  desc 'Carga/actualiza el padrón de Mitocondria (SIMULAR=1 reporta sin escribir; CLUB_ID acota)'
  task mitocondria: :environment do
    simular = ENV['SIMULAR'].present?

    club = ActsAsTenant.without_tenant do
      if ENV['CLUB_ID'].present?
        Club.find(ENV['CLUB_ID'])
      else
        # El más nuevo: el Mitocondria real se creó después del de prueba.
        Club.where('name ILIKE ?', '%Mitocondria%').order(created_at: :desc).first
      end
    end
    abort('No encontré el club. Creálo primero, o pasá CLUB_ID=<id>.') if club.nil?

    admin = club.users.find_by(role: 'admin')
    abort("El club ##{club.id} no tiene ningún usuario admin: sin eso no hay `created_by`.") if admin.nil?

    otros = ActsAsTenant.without_tenant do
      Club.where('name ILIKE ?', '%Mitocondria%').where.not(id: club.id).pluck(:id, :name)
    end

    puts "Organización : ##{club.id} #{club.name}  (creada #{club.created_at.to_date})"
    puts "Alta como    : #{admin.email}"
    puts "Modo         : #{simular ? 'SIMULACRO (no escribe)' : 'REAL'}"
    if otros.any? && ENV['CLUB_ID'].blank?
      puts "Ojo          : hay otros Mitocondria y NO se tocan → #{otros.map { |i, n| "##{i} #{n}" }.join(', ')}"
    end
    puts '-' * 74

    crear, actualizar, intactos, errores = [], [], [], []

    ActsAsTenant.with_tenant(club) do
      MITOCONDRIA.each_with_index do |(nom, ape, dni, nacimiento, tramite, estado, vence), i|
        fila = "#{(i + 1).to_s.rjust(2)}. #{nom} #{ape}"

        # Por DNI primero; si no, por número de trámite, que es lo que permite reconocer a
        # alguien cargado con DNI provisorio y darle el real sin duplicarlo.
        paciente = Paciente.find_by(dni_normalizado: dni.to_s)
        paciente ||= tramite && Paciente.find_by(reprocann_numero: tramite.to_s)

        attrs = {
          nombre: nom, apellido: ape, dni: dni.to_s,
          reprocann_numero: tramite&.to_s,
          reprocann_estado: estado,
          reprocann_vencimiento: vence && Date.parse(vence),
        }

        if paciente
          # La fecha de nacimiento NO entra acá: la de esta tabla es inventada y la que ya
          # tiene el registro puede ser la de verdad.
          paciente.assign_attributes(attrs.merge(updated_by: admin))
          if paciente.changed?
            cambios = paciente.changes.except('updated_by_id').keys.join(', ')
            paciente.valid? ? actualizar << [fila, paciente, cambios] : errores << "#{fila}: #{paciente.errors.full_messages.join(' · ')}"
          else
            intactos << fila
          end
          next
        end

        nuevo = Paciente.new(attrs.merge(
          club: club, created_by: admin, updated_by: admin,
          fecha_nacimiento: Date.parse(nacimiento),
          con_seguimiento_medico: true
        ))

        nuevo.valid? ? crear << [fila, nuevo] : errores << "#{fila}: #{nuevo.errors.full_messages.join(' · ')}"
      end

      unless simular
        ActiveRecord::Base.transaction do
          crear.each do |_fila, paciente|
            paciente.save!
            paciente.create_cuenta_corriente!(club: club, saldo_disponible: 0, limite_credito: 0)
          end
          actualizar.each { |_fila, paciente, _c| paciente.save! }
        end
      end
    end

    puts "#{simular ? 'A crear' : 'Creados'} : #{crear.size}"
    crear.each { |fila, p| puts format('   %-42s DNI %s', fila, p.dni) }

    if actualizar.any?
      puts "\n#{simular ? 'A actualizar' : 'Actualizados'} : #{actualizar.size}"
      actualizar.each { |fila, _p, cambios| puts format('   %-42s → %s', fila, cambios) }
    end

    puts "\nSin cambios : #{intactos.size}" if intactos.any?

    if errores.any?
      puts "\nCon error (NO se tocan): #{errores.size}"
      errores.each { |e| puts "   #{e}" }
    end

    puts '-' * 74
    if simular
      puts 'Simulacro: no se escribió nada. Sacá SIMULAR=1 para aplicar.'
    else
      puts "Listo. #{crear.size} altas y #{actualizar.size} actualizaciones en #{club.name}."
      puts 'Pendiente a mano: las 29 personas con DNI provisorio (90.000.xxx) y TODAS las fechas de nacimiento.'
    end
  end
end
