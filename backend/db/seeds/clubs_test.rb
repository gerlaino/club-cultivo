puts "Iniciando seed..."

conn = ActiveRecord::Base.connection

# Deshabilitar FK constraints temporalmente
conn.execute("SET session_replication_role = 'replica'")

club_names = [
  'Mitocondria Club',
  'Club Semilla Test',
  'Club Brote Test',
  'Club Cosecha Test',
  'Club Federacion Test'
]

club_ids = Club.where(name: club_names).pluck(:id)

if club_ids.any?
  ids = club_ids.join(',')
  conn.execute("DELETE FROM socio_notas WHERE socio_id IN (SELECT id FROM socios WHERE club_id IN (#{ids}))")
  conn.execute("DELETE FROM patient_documents WHERE socio_id IN (SELECT id FROM socios WHERE club_id IN (#{ids}))") rescue nil
  conn.execute("DELETE FROM indicacion_medicas WHERE socio_id IN (SELECT id FROM socios WHERE club_id IN (#{ids}))") rescue nil
  conn.execute("DELETE FROM dispensaciones WHERE socio_id IN (SELECT id FROM socios WHERE club_id IN (#{ids}))") rescue nil
  conn.execute("DELETE FROM socios WHERE club_id IN (#{ids})")
  conn.execute("DELETE FROM plant_activities WHERE plant_id IN (SELECT id FROM plants WHERE lote_id IN (SELECT id FROM lotes WHERE club_id IN (#{ids})))") rescue nil
  conn.execute("DELETE FROM plants WHERE lote_id IN (SELECT id FROM lotes WHERE club_id IN (#{ids}))")
  conn.execute("DELETE FROM lotes WHERE club_id IN (#{ids})")
  conn.execute("DELETE FROM salas WHERE club_id IN (#{ids})")
  conn.execute("DELETE FROM sedes WHERE club_id IN (#{ids})")
  conn.execute("DELETE FROM geneticas WHERE club_id IN (#{ids})")
  conn.execute("DELETE FROM document_templates WHERE club_id IN (#{ids})") rescue nil
  conn.execute("DELETE FROM jwt_denylists WHERE jti IN (SELECT jti FROM users WHERE club_id IN (#{ids}))") rescue nil
  conn.execute("DELETE FROM users WHERE club_id IN (#{ids})")
  conn.execute("DELETE FROM clubs WHERE id IN (#{ids})")
  puts "Eliminados #{club_ids.size} clubs anteriores"
end

# Rehabilitar FK constraints
conn.execute("SET session_replication_role = 'origin'")

def crear_club(name:, plan:, users_data:)
  club = Club.create!(
    name:       name,
    email:      "contacto@#{name.downcase.gsub(/[^a-z0-9]/, '')}.com",
    city:       'Buenos Aires',
    state:      'CABA',
    country:    'Argentina',
    plan:       plan,
    plan_trial: false,
    )
  users_data.each do |u|
    User.create!(
      club:                  club,
      email:                 u[:email],
      password:              '123456Aa',
      password_confirmation: '123456Aa',
      role:                  u[:role],
      first_name:            u[:first_name],
      last_name:             u[:last_name],
      )
    puts "  #{u[:role]}: #{u[:email]}"
  end
  club
end

puts "\nCreando Mitocondria Club (Federacion)..."
crear_club(
  name: 'Mitocondria Club',
  plan: 'federacion',
  users_data: [
    { email: 'admin@mitocondria.com',      role: 'admin',      first_name: 'Pablo',   last_name: 'Ezquer'    },
    { email: 'medico@mitocondria.com',     role: 'medico',     first_name: 'Ana',     last_name: 'Garcia'    },
    { email: 'agricultor@mitocondria.com', role: 'agricultor', first_name: 'Carlos',  last_name: 'Lopez'     },
    { email: 'cultivador@mitocondria.com', role: 'cultivador', first_name: 'Maria',   last_name: 'Martinez'  },
    { email: 'abogado@mitocondria.com',    role: 'abogado',    first_name: 'Diego',   last_name: 'Fernandez' },
    { email: 'auditor@mitocondria.com',    role: 'auditor',    first_name: 'Laura',   last_name: 'Rodriguez' },
  ]
)

puts "\nCreando Club Semilla Test..."
crear_club(
  name: 'Club Semilla Test',
  plan: 'semilla',
  users_data: [
    { email: 'admin@semilla.test',      role: 'admin',      first_name: 'Admin',      last_name: 'Semilla' },
    { email: 'agricultor@semilla.test', role: 'agricultor', first_name: 'Agricultor', last_name: 'Semilla' },
    { email: 'medico@semilla.test',     role: 'medico',     first_name: 'Medico',     last_name: 'Semilla' },
  ]
)

puts "\nCreando Club Brote Test..."
crear_club(
  name: 'Club Brote Test',
  plan: 'brote',
  users_data: [
    { email: 'admin@brote.test',      role: 'admin',      first_name: 'Admin',      last_name: 'Brote' },
    { email: 'agricultor@brote.test', role: 'agricultor', first_name: 'Agricultor', last_name: 'Brote' },
    { email: 'medico@brote.test',     role: 'medico',     first_name: 'Medico',     last_name: 'Brote' },
    { email: 'cultivador@brote.test', role: 'cultivador', first_name: 'Cultivador', last_name: 'Brote' },
  ]
)

puts "\nCreando Club Cosecha Test..."
crear_club(
  name: 'Club Cosecha Test',
  plan: 'cosecha',
  users_data: [
    { email: 'admin@cosecha.test',      role: 'admin',      first_name: 'Admin',      last_name: 'Cosecha' },
    { email: 'agricultor@cosecha.test', role: 'agricultor', first_name: 'Agricultor', last_name: 'Cosecha' },
    { email: 'medico@cosecha.test',     role: 'medico',     first_name: 'Medico',     last_name: 'Cosecha' },
    { email: 'cultivador@cosecha.test', role: 'cultivador', first_name: 'Cultivador', last_name: 'Cosecha' },
    { email: 'abogado@cosecha.test',    role: 'abogado',    first_name: 'Abogado',    last_name: 'Cosecha' },
  ]
)

puts "\nCreando Club Federacion Test..."
crear_club(
  name: 'Club Federacion Test',
  plan: 'federacion',
  users_data: [
    { email: 'admin@federacion.test',      role: 'admin',      first_name: 'Admin',      last_name: 'Federacion' },
    { email: 'agricultor@federacion.test', role: 'agricultor', first_name: 'Agricultor', last_name: 'Federacion' },
    { email: 'medico@federacion.test',     role: 'medico',     first_name: 'Medico',     last_name: 'Federacion' },
    { email: 'cultivador@federacion.test', role: 'cultivador', first_name: 'Cultivador', last_name: 'Federacion' },
    { email: 'abogado@federacion.test',    role: 'abogado',    first_name: 'Abogado',    last_name: 'Federacion' },
    { email: 'auditor@federacion.test',    role: 'auditor',    first_name: 'Auditor',    last_name: 'Federacion' },
  ]
)

puts "\n=============================="
puts "SEED COMPLETADO"
puts "=============================="
puts "Contrasena: 123456Aa"
puts ""
puts "MITOCONDRIA (Federacion - acceso total):"
puts "  admin@mitocondria.com"
puts "  medico@mitocondria.com"
puts "  agricultor@mitocondria.com"
puts "  cultivador@mitocondria.com"
puts "  abogado@mitocondria.com"
puts "  auditor@mitocondria.com"
puts ""
puts "SEMILLA: admin@semilla.test"
puts "BROTE:   admin@brote.test"
puts "COSECHA: admin@cosecha.test"
puts "FEDERACION: admin@federacion.test"