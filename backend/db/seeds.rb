=begin
club = Club.find_or_create_by!(name: "Club Demo")
users = [
  { email: "super@demo.com", role: "super_admin" },
  { email: "admin@demo.com", role: "admin" },
  { email: "medico@demo.com", role: "medico" },
  { email: "cultivador@demo.com", role: "cultivador" }
]
users.each do |u|
  User.find_or_create_by!(email: u[:email]) do |user|
    user.password = "123456"
    user.password_confirmation = "123456"
    user.role = u[:role]
    user.club = club
  end
end
puts "Seed OK"

sala = Sala.find_or_create_by!(name: "Sala Norte", club: Club.first) do |s|
  s.state = "activa"
  s.pots_count = 24
  s.notes = "MVP"
  s.created_by = User.first
end

Lote.find_or_create_by!(code: "L-001", sala: sala, club: sala.club) do |l|
  l.start_date = Date.today
  l.stage = "vegetativo"
  l.plants_count = 20
  l.strain = "OG Kush"
  l.notes = "Primer lote"
end

user = User.find_by(email: "super@demo.com")
club = user.club

s1 = Sala.find_or_create_by!(club: club, name: "Sala Norte") do |s|
  s.state = "activa"
  s.kind = "indoor"
  s.created_by = user
  s.camera_snapshot_url = "https://picsum.photos/seed/sala-norte/800/450"
end

s2 = Sala.find_or_create_by!(club: club, name: "Sala Secado") do |s|
  s.state = "activa"
  s.kind = "indoor"
  s.created_by = user
end

Lote.find_or_create_by!(club: club, sala: s1, code: "L-001") do |l|
  l.plants_count = 24
  l.strain = "OG Kush"
  l.start_date = Date.today - 30
  l.grow_type = "sustrato"
  l.light_type = "LED 480W"
end

Lote.find_or_create_by!(club: club, sala: s1, code: "L-002") do |l|
  l.plants_count = 10
  l.strain = "Blue Dream"
  l.start_date = Date.today - 10
  l.grow_type = "hidroponia"
  l.light_type = "HPS 600W"
end

# 🌐 Datos para web pública
puts "🌱 Creando datos para web pública..."

# Genéticas
puts "📦 Creando genéticas..."
geneticas_data = [
  { nombre: "OG Kush", tipo: "hibrida", thc: 24.5, cbd: 0.3, descripcion: "Clásica cepa californiana, potente y relajante.", disponible: true, activa: true },
  { nombre: "White Widow", tipo: "hibrida", thc: 20.0, cbd: 0.2, descripcion: "Famosa por su resina blanca y efectos balanceados.", disponible: true, activa: true },
  { nombre: "Sour Diesel", tipo: "sativa", thc: 22.0, cbd: 0.1, descripcion: "Energizante y cerebral, ideal para el día.", disponible: false, activa: true },
  { nombre: "Northern Lights", tipo: "indica", thc: 18.5, cbd: 0.5, descripcion: "Relajante profunda, perfecta para dormir.", disponible: true, activa: true },
  { nombre: "Harlequin", tipo: "sativa", thc: 7.0, cbd: 10.5, descripcion: "Alto CBD, ideal para uso medicinal.", disponible: true, activa: true }
]

geneticas_data.each do |data|
  club.geneticas.find_or_create_by!(nombre: data[:nombre]) do |g|
    g.assign_attributes(data)
  end
end
puts "✅ #{club.geneticas.count} genéticas creadas"

# Noticias
puts "📰 Creando noticias..."
noticias_data = [
  {
    titulo: "Nueva cosecha de OG Kush disponible",
    contenido: "Nos complace anunciar que nuestra cosecha de OG Kush está lista. Esta tanda tiene niveles excepcionales de THC y un aroma increíble. Disponible a partir del próximo lunes en el club.",
    publicada: true,
    publicada_at: 2.days.ago
  },
  {
    titulo: "Taller de cultivo orgánico - Próximamente",
    contenido: "El próximo mes realizaremos un taller gratuito sobre técnicas de cultivo orgánico. Aprenderás sobre compostaje, control de plagas natural y más. Cupos limitados, inscribite en el club.",
    publicada: true,
    publicada_at: 5.days.ago
  },
  {
    titulo: "Actualización de protocolos sanitarios",
    contenido: "Informamos que hemos actualizado nuestros protocolos de higiene y seguridad. Todos los espacios son desinfectados regularmente y mantenemos ventilación constante.",
    publicada: false
  }
]

noticias_data.each do |data|
  club.noticias.find_or_create_by!(titulo: data[:titulo]) do |n|
    n.assign_attributes(data)
  end
end
puts "✅ #{club.noticias.count} noticias creadas"

# Eventos
puts "📅 Creando eventos..."
eventos_data = [
  {
    titulo: "Taller de Extracción de Aceites",
    descripcion: "Aprende a extraer aceite de cannabis de forma segura y efectiva. Incluye demostración práctica y material de estudio.",
    fecha_inicio: 2.weeks.from_now.change(hour: 18, min: 0),
    fecha_fin: 2.weeks.from_now.change(hour: 21, min: 0),
    lugar: "Sala de eventos - Club",
    activo: true
  },
  {
    titulo: "Charla: Cannabis Medicinal y Legislación",
    descripcion: "Conversatorio con especialistas sobre el marco legal del cannabis medicinal en Argentina y REPROCANN.",
    fecha_inicio: 3.weeks.from_now.change(hour: 19, min: 0),
    fecha_fin: 3.weeks.from_now.change(hour: 21, min: 0),
    lugar: "Auditorio Principal",
    activo: true
  },
  {
    titulo: "Aniversario del Club - Celebración",
    descripcion: "Festejamos un año más con música en vivo, food trucks y sorpresas. Entrada libre para socios.",
    fecha_inicio: 1.month.from_now.change(hour: 17, min: 0),
    fecha_fin: 1.month.from_now.change(hour: 23, min: 0),
    lugar: "Jardín del club",
    activo: true
  }
]

eventos_data.each do |data|
  club.eventos.find_or_create_by!(titulo: data[:titulo]) do |e|
    e.assign_attributes(data)
  end
end
puts "✅ #{club.eventos.count} eventos creados"

puts "🎉 ¡Datos de prueba creados exitosamente!"
=end

puts "Seeds temporalmente comentados"