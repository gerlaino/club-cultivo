puts "Iniciando seed..."

club_names = [
  'Mitocondria Club',
  'Club Semilla Test',
  'Club Brote Test',
  'Club Cosecha Test',
  'Club Federacion Test'
]

puts "Limpiando datos anteriores..."
Club.where(name: club_names).each do |club|
  cid = club.id
  socio_ids = ActiveRecord::Base.connection.select_values("SELECT id FROM socios WHERE club_id = #{cid}")
  if socio_ids.any?
    sids = socio_ids.join(',')
    ActiveRecord::Base.connection.execute("DELETE FROM socio_notas WHERE socio_id IN (#{sids})")
    ActiveRecord::Base.connection.execute("DELETE FROM indicacion_medicas WHERE socio_id IN (#{sids})") rescue nil
    ActiveRecord::Base.connection.execute("DELETE FROM dispensaciones WHERE socio_id IN (#{sids})") rescue nil
    ActiveRecord::Base.connection.execute("DELETE FROM socios WHERE club_id = #{cid}")
  end
  lote_ids = ActiveRecord::Base.connection.select_values("SELECT id FROM lotes WHERE club_id = #{cid}")
  if lote_ids.any?
    lids = lote_ids.join(',')
    ActiveRecord::Base.connection.execute("DELETE FROM plant_activities WHERE plant_id IN (SELECT id FROM plants WHERE lote_id IN (#{lids}))") rescue nil
    ActiveRecord::Base.connection.execute("DELETE FROM plants WHERE lote_id IN (#{lids})")
    ActiveRecord::Base.connection.execute("DELETE FROM lotes WHERE club_id = #{cid}")
  end
  sede_ids = ActiveRecord::Base.connection.select_values("SELECT id FROM sedes WHERE club_id = #{cid}")
  if sede_ids.any?
    seids = sede_ids.join(',')
    ActiveRecord::Base.connection.execute("DELETE FROM inventario_movimientos WHERE sede_id IN (#{seids})") rescue nil
    ActiveRecord::Base.connection.execute("DELETE FROM sede_inventarios WHERE sede_id IN (#{seids})") rescue nil
    ActiveRecord::Base.connection.execute("UPDATE salas SET sede_id = NULL WHERE sede_id IN (#{seids})") rescue nil
    ActiveRecord::Base.connection.execute("DELETE FROM sedes WHERE club_id = #{cid}")
  end
  ActiveRecord::Base.connection.execute("DELETE FROM salas WHERE club_id = #{cid}")
  ActiveRecord::Base.connection.execute("DELETE FROM geneticas WHERE club_id = #{cid}") rescue nil
  ActiveRecord::Base.connection.execute("DELETE FROM document_templates WHERE club_id = #{cid}") rescue nil
  ActiveRecord::Base.connection.execute("DELETE FROM users WHERE club_id = #{cid}")
  ActiveRecord::Base.connection.execute("DELETE FROM clubs WHERE id = #{cid}")
  puts "  Eliminado: #{club.name}"
end

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
puts "admin@mitocondria.com"
puts "admin@semilla.test"
puts "admin@brote.test"
puts "admin@cosecha.test"
puts "admin@federacion.test"
