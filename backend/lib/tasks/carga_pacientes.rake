# Carga inicial de pacientes del club Mitocondria, tomada del listado de trámites REPROCANN.
#
# Origen del dato: capturas de pantalla del sistema REPROCANN (el sistema no permite exportar).
# Se parsearon 45 trámites y, deduplicando por persona, quedaron 38 pacientes.
#
# ⚠️ DNI y FECHA DE NACIMIENTO SON INVENTADOS. El listado REPROCANN no trae ninguno de los dos
# y ambos son obligatorios en Paciente. Los DNI van en el rango 90.000.001–90.000.038:
# los DNI argentinos reales de adultos están entre 20 y 70 millones, así que nada en 90M puede
# chocar con una persona real —importa porque `dni_normalizado` es único GLOBAL, no por club—
# y cuando lleguen los reales se ubican con `WHERE dni_normalizado LIKE '9%'`.
#
# ⚠️ FALTAN 10 TRÁMITES. Los pies de página de las capturas dicen 1–10, 11–20, 31–40, 41–50 y
# 51–55 sobre 55 totales: falta el bloque 21–30 (trámites entre 374070 y 358875). Diez de los
# pacientes de acá figuran sólo con trámite ANULADO y su aprobado puede estar en ese bloque.
#
# Uso:
#   bundle exec rake pacientes:mitocondria SIMULAR=1   # reporta, no escribe
#   bundle exec rake pacientes:mitocondria             # carga (en una transacción)
#
#   CLUB_ID=12 bundle exec rake pacientes:mitocondria  # si el nombre no alcanza
#
# Es idempotente: saltea por `dni_normalizado` los que ya existan, así que volver a correrlo
# después de agregar filas carga sólo las nuevas.
namespace :pacientes do
  # nombre, apellido, dni, nacimiento, nro de trámite, estado, vencimiento
  MITOCONDRIA = [
    ['Federico Hernan',   'REY',                   90_000_001, '1988-03-14', 428_517, 'activo', '2029-08-07'],
    ['Alan Mauricio',     'RODRIGUEZ',             90_000_002, '1991-07-02', 426_918, 'activo', '2029-08-06'],
    ['Augusto',           'GRIZZUTI',              90_000_003, '1985-11-23', 419_564, 'activo', '2029-07-03'],
    ['Leandro Ariel',     'Barreto',               90_000_004, '1979-05-08', 419_544, 'activo', '2029-07-03'],
    ['Santino',           'NANNI',                 90_000_005, '1997-01-30', 419_520, 'activo', '2029-07-03'],
    ['Diego Ariel',       'PASCAR',                90_000_006, '1983-09-17', 396_049, 'activo', '2029-06-03'],
    ['Sebastian',         'Perez Porta',           90_000_007, '1990-12-05', 395_596, 'activo', '2029-06-02'],
    ['Martina',           'DE MAIO',               90_000_008, '1994-04-21', 393_554, 'activo', '2029-06-19'],
    ['Federico Jose',     'LLAURADO',              90_000_009, '1987-08-11', 385_389, 'activo', '2029-05-19'],
    ['Martin Ariel',      'PINASCO',               90_000_010, '1976-02-26', 382_124, 'activo', '2029-05-26'],
    ['Alejandro Daniel',  'FERNANDEZ',             90_000_011, '1982-06-13', 382_123, 'activo', '2029-05-20'],
    ['Nicolas Domingo',   'SCORDAMAGLIA',          90_000_012, '1993-10-09', 382_104, 'activo', '2029-05-15'],
    ['Thomas',            'PALAVECINO MARTIGNONI', 90_000_013, '1999-03-28', 382_098, 'activo', '2029-05-26'],
    ['Benicio',           'Raineri',               90_000_014, '2001-07-16', 375_852, 'activo', '2029-04-09'],
    ['Joaquin Ignacio',   'Jauregui Marcos',       90_000_015, '1996-11-04', 375_851, 'activo', '2029-04-09'],
    ['Alan Alexis',       'PAEZ GUNSETT',          90_000_016, '1989-01-19', 375_835, 'activo', '2029-05-18'],
    ['Micaela Milagros',  'TESTINO',               90_000_017, '1992-05-27', 374_070, 'activo', '2029-05-13'],
    ['Mauro Daniel',      'AGÜERO',                90_000_018, '1980-09-03', 358_875, 'activo', '2029-03-20'],
    ['German Jose',       'LAINO',                 90_000_019, '1986-12-22', 272_626, 'activo', '2028-02-11'],
    ['Marcos Nicolas',    'CASUSO',                90_000_020, '1978-04-07', 195_577, 'activo', '2026-11-02'],
    ['Martin Andres',     'CORIZZO',               90_000_021, '1984-08-15', 191_802, 'activo', '2026-11-02'],
    ['Geronimo',          'Ortigoza',              90_000_022, '1995-02-11', 162_178, 'activo', '2026-08-28'],
    ['Natanael',          'Casuso',                90_000_023, '1998-06-29', 162_151, 'activo', '2026-08-28'],
    ['Martin Ezequiel',   'BLANCO',                90_000_024, '1981-10-18', 162_114, 'activo', '2026-08-28'],
    ['Federico Cesar',    'GARCIA BULZ',           90_000_025, '1975-01-06',  18_363, 'activo', '2026-12-15'],

    ['Juan Bautista',     'Rossi',                 90_000_026, '2000-03-24', 428_546, 'pendiente', nil],
    ['Franco Augusto',    'CARLINO CURRENTI',      90_000_027, '1990-07-31', 426_922, 'pendiente', nil],
    ['Fabrizio',          'PUJANTE MARTIGNONI',    90_000_028, '1993-11-12', 419_591, 'pendiente', nil],

    # Sólo figuran con trámite ANULADO. Van sin `reprocann_numero` a propósito: con número
    # cargado, el informe de Cumplimiento los cuenta como "con REPROCANN" mientras el estado
    # dice sin_registro, y los totales dejan de cerrar.
    ['Ulises Adrian',     'MARTINEZ',              90_000_029, '1988-05-02', nil, 'sin_registro', nil],
    ['Marcelo',           'MARTY',                 90_000_030, '1972-09-20', nil, 'sin_registro', nil],
    ['Nicolas',           'CALANDRONI',            90_000_031, '1991-12-08', nil, 'sin_registro', nil],
    ['Marcos',            'SIBBALD',               90_000_032, '1985-04-16', nil, 'sin_registro', nil],
    ['Roberto Jose',      'FINKELBERG',            90_000_033, '1968-08-25', nil, 'sin_registro', nil],
    ['Alejo Nicolas',     'FERNANDEZ FORTUNY',     90_000_034, '1997-02-03', nil, 'sin_registro', nil],
    ['Nestor Nehuen',     'Bertora',               90_000_035, '1994-10-14', nil, 'sin_registro', nil],
    ['Enrique Emmanuel',  'OVELAR',                90_000_036, '1983-06-07', nil, 'sin_registro', nil],
    ['Sheila Chantal',    'SCHURMANN',             90_000_037, '1996-01-28', nil, 'sin_registro', nil],
    ['Juan Ignacio',      'BRAVO',                 90_000_038, '1979-11-09', nil, 'sin_registro', nil],
  ].freeze

  desc 'Carga los pacientes iniciales del club Mitocondria (SIMULAR=1 para reportar sin escribir)'
  task mitocondria: :environment do
    simular = ENV['SIMULAR'].present?

    club = ActsAsTenant.without_tenant do
      if ENV['CLUB_ID'].present?
        Club.find(ENV['CLUB_ID'])
      else
        Club.where('name ILIKE ?', '%Mitocondria%').first
      end
    end
    abort('No encontré el club. Creálo primero, o pasá CLUB_ID=<id>.') if club.nil?

    admin = club.users.find_by(role: 'admin')
    abort("El club ##{club.id} no tiene ningún usuario admin: sin eso no hay `created_by`.") if admin.nil?

    puts "Club : ##{club.id} #{club.name}"
    puts "Alta : #{admin.email}"
    puts "Modo : #{simular ? 'SIMULACRO (no escribe)' : 'REAL'}"
    puts '-' * 64

    crear, existen, errores = [], [], []

    ActsAsTenant.with_tenant(club) do
      MITOCONDRIA.each_with_index do |(nom, ape, dni, nacimiento, tramite, estado, vence), i|
        fila = "#{(i + 1).to_s.rjust(2)}. #{nom} #{ape}"

        # Sin tenant: la unicidad del DNI es global, y con el scope del club puesto una
        # colisión con OTRO club no se vería acá — reventaría recién contra el índice único.
        ya_existe = ActsAsTenant.without_tenant do
          Paciente.unscoped.where(dni_normalizado: dni.to_s).exists?
        end
        if ya_existe
          existen << "#{fila} (DNI #{dni})"
          next
        end

        paciente = Paciente.new(
          club: club, created_by: admin, updated_by: admin,
          nombre: nom, apellido: ape,
          dni: dni.to_s,
          fecha_nacimiento: Date.parse(nacimiento),
          reprocann_numero: tramite&.to_s,
          reprocann_estado: estado,
          reprocann_vencimiento: vence && Date.parse(vence),
          con_seguimiento_medico: true
        )

        if paciente.valid?
          crear << [fila, paciente]
        else
          errores << "#{fila}: #{paciente.errors.full_messages.join(' · ')}"
        end
      end

      unless simular || crear.empty?
        ActiveRecord::Base.transaction do
          crear.each do |_fila, paciente|
            paciente.save!
            paciente.create_cuenta_corriente!(club: club, saldo_disponible: 0, limite_credito: 0)
          end
        end
      end
    end

    puts "#{simular ? 'A crear' : 'Creados'} : #{crear.size}"
    crear.each { |fila, _p| puts "   #{fila}" } if simular

    if existen.any?
      puts "\nYa existían (salteados): #{existen.size}"
      existen.each { |e| puts "   #{e}" }
    end

    if errores.any?
      puts "\nCon error (NO se cargan): #{errores.size}"
      errores.each { |e| puts "   #{e}" }
    end

    puts '-' * 64
    if simular
      puts 'Simulacro: no se escribió nada. Sacá SIMULAR=1 para cargar.'
    else
      puts "Listo. #{crear.size} pacientes en #{club.name}, cada uno con su cuenta corriente en 0."
      puts 'Recordá: los DNI son placeholder (90.000.xxx) y hay que reemplazarlos.'
    end
  end
end
