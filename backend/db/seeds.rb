# ============================================================
# SEEDS — Club Cultivo
# ============================================================
puts "🌱 Iniciando seeds..."

# ── Super Admin ──────────────────────────────────────────────
puts "\n👤 Creando super admin..."
super_admin = User.find_or_initialize_by(email: 'superadmin@clubcultivo.app')
super_admin.assign_attributes(
  password:   '123456Aa',
  role:       'super_admin',
  first_name: 'Super',
  last_name:  'Admin',
  )
super_admin.club_id = nil
super_admin.save!(validate: false)
puts "  ✅ #{super_admin.email}"

# ── Club demo ────────────────────────────────────────────────
puts "\n🏢 Creando club demo..."
club = Club.find_or_create_by!(name: 'Mitocondria Club') do |c|
  c.legal_name  = 'Asociación Civil Mitocondria'
  c.email       = 'contacto@mitocondriaclub.org'
  c.phone       = '+54 11 4567-8901'
  c.website     = 'https://mitocondriaclub.org'
  c.address     = 'Av. Corrientes 1234, Piso 2'
  c.city        = 'Buenos Aires'
  c.state       = 'CABA'
  c.country     = 'Argentina'
  c.timezone    = 'America/Argentina/Buenos_Aires'
  c.plan        = 'cosecha'
  c.plan_trial  = false
  c.plan_activo_hasta = 1.year.from_now.to_date
end
puts "  ✅ #{club.name} (plan: #{club.plan})"

# ── Usuarios del club ────────────────────────────────────────
puts "\n👥 Creando usuarios..."
USUARIOS_DATA = [
  { email: 'admin@mitocondriaclub.org',      role: 'admin',      first_name: 'Pablo',    last_name: 'Ezquer'    },
  { email: 'medico@mitocondriaclub.org',      role: 'medico',     first_name: 'Ana',      last_name: 'García'    },
  { email: 'agricultor@mitocondriaclub.org',  role: 'agricultor', first_name: 'Martín',   last_name: 'López'     },
  { email: 'cultivador@mitocondriaclub.org',  role: 'cultivador', first_name: 'Diego',    last_name: 'Fernández' },
  { email: 'abogado@mitocondriaclub.org',     role: 'abogado',    first_name: 'Lucía',    last_name: 'Torres'    },
  { email: 'auditor@mitocondriaclub.org',     role: 'auditor',    first_name: 'Roberto',  last_name: 'Sánchez'   },
].freeze

usuarios = {}
USUARIOS_DATA.each do |u|
  user = User.find_or_initialize_by(email: u[:email])
  user.assign_attributes(u.merge(club: club, password: '123456Aa'))
  user.save!
  usuarios[u[:role]] = user
  puts "  ✅ #{user.email} (#{user.role})"
end

admin      = usuarios['admin']
medico     = usuarios['medico']
cultiv     = usuarios['cultivador']

# ── Genéticas default INASE + comunes ───────────────────────
puts "\n🧬 Creando genéticas..."
club.crear_geneticas_default!

GENETICAS_COMUNES = [
  { nombre: 'OG Kush',          tipo: 'hibrida', thc: 22.0, cbd: 0.3,  origen: 'California, EEUU', criador: 'Chemdawg x Hindu Kush',    terpenos: 'Mirceno, Limoneno, Cariofileno', tiempo_floracion: 63, rendimiento: 400, altura: 90,  dificultad: 'intermedia', descripcion: 'Clásica californiana. Aroma a tierra, pino y limón. Efectos relajantes y analgésicos.', registrada_inase: false, disponible: true, activa: true },
  { nombre: 'White Widow',      tipo: 'hibrida', thc: 19.0, cbd: 0.2,  origen: 'Países Bajos',     criador: 'Green House Seeds',          terpenos: 'Mirceno, Cariofileno, Pineno',   tiempo_floracion: 60, rendimiento: 450, altura: 100, dificultad: 'facil',      descripcion: 'Icónica holandesa. Cubierta de resina blanca. Efectos eufóricos y creativos.',          registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Northern Lights',  tipo: 'indica',  thc: 18.0, cbd: 0.5,  origen: 'Afganistán',       criador: 'Sensi Seeds',                terpenos: 'Mirceno, Cariofileno, Linalool', tiempo_floracion: 56, rendimiento: 500, altura: 100, dificultad: 'facil',      descripcion: 'Indica clásica. Relajante profunda, ideal para el sueño y dolor neuropático.',          registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Harlequin',        tipo: 'sativa',  thc: 7.0,  cbd: 10.5, origen: 'Colombia/Nepal',   criador: 'Cruza multiregional',        terpenos: 'Mirceno, Cariofileno, Pineno',   tiempo_floracion: 65, rendimiento: 350, altura: 150, dificultad: 'intermedia', descripcion: 'Alta en CBD. Relación 1:1.5 THC/CBD. Ideal para uso medicinal diurno.',                   registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Critical Mass CBD',tipo: 'indica',  thc: 5.0,  cbd: 8.0,  origen: 'Afghanistan x Skunk', criador: 'CBD Crew',               terpenos: 'Mirceno, Linalool, Cariofileno', tiempo_floracion: 56, rendimiento: 600, altura: 100, dificultad: 'facil',      descripcion: 'Medicinal de alto CBD. Sin efectos psicoactivos marcados. Popular en clubes REPROCANN.', registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Cheese',           tipo: 'indica',  thc: 17.0, cbd: 0.4,  origen: 'Reino Unido',      criador: 'Skunk #1 UK phenotype',      terpenos: 'Cariofileno, Mirceno, Linalool', tiempo_floracion: 60, rendimiento: 450, altura: 100, dificultad: 'facil',      descripcion: 'Aroma característico a queso. Efectos relajantes y eufóricos equilibrados.',            registrada_inase: false, disponible: true, activa: true },
].freeze

GENETICAS_COMUNES.each do |g|
  next if club.geneticas.exists?(nombre: g[:nombre])
  club.geneticas.create!(g)
  puts "  🌿 #{g[:nombre]}"
end
puts "  ✅ #{club.geneticas.count} genéticas en total (#{club.geneticas.where(registrada_inase: true).count} INASE)"

# ── Sedes ────────────────────────────────────────────────────
puts "\n🏢 Creando sedes..."
sede_prod = club.sedes.find_or_create_by!(nombre: 'Avellaneda') do |s|
  s.tipo                = 'produccion'
  s.direccion           = 'Av. Mitre 2340'
  s.ciudad              = 'Avellaneda'
  s.provincia           = 'Buenos Aires'
  s.declarada_reprocann = true
  s.created_by          = admin
  s.notas               = 'Sede principal de producción. Dos salas activas de vegetativo y floración.'
end

sede_disp = club.sedes.find_or_create_by!(nombre: 'Devoto') do |s|
  s.tipo                = 'social'
  s.direccion           = 'Francisco Beiró 4580'
  s.ciudad              = 'Buenos Aires'
  s.provincia           = 'CABA'
  s.declarada_reprocann = true
  s.created_by          = admin
  s.notas               = 'Dispensario y atención a socios.'
end

sede_mixta = club.sedes.find_or_create_by!(nombre: 'Pompeya') do |s|
  s.tipo                = 'mixta'
  s.direccion           = 'Pagola 4135'
  s.ciudad              = 'Buenos Aires'
  s.provincia           = 'CABA'
  s.declarada_reprocann = false
  s.created_by          = admin
  s.notas               = 'Sede mixta en expansión.'
end
puts "  ✅ #{sede_prod.nombre}, #{sede_disp.nombre}, #{sede_mixta.nombre}"

# ── Salas ────────────────────────────────────────────────────
puts "\n🏗️  Creando salas..."
sala_veg = club.salas.find_or_create_by!(nombre: 'Sala Vegetativo') do |s|
  s.state       = 'activa'
  s.kind        = 'vegetativo'
  s.pots_count  = 80
  s.plants_max  = 80
  s.sede        = sede_prod
  s.created_by  = admin
  s.notes       = 'Sala de vegetativo con luz LED 18/6. Temperatura controlada 22-26°C.'
end

sala_flor = club.salas.find_or_create_by!(nombre: 'Sala Floración') do |s|
  s.state       = 'activa'
  s.kind        = 'floracion'
  s.pots_count  = 40
  s.plants_max  = 40
  s.sede        = sede_prod
  s.created_by  = admin
  s.notes       = 'Sala de floración 12/12 con HPS 600W. Humedad controlada 45-55%.'
end

sala_mad = club.salas.find_or_create_by!(nombre: 'Sala Madres') do |s|
  s.state       = 'activa'
  s.kind        = 'madre'
  s.pots_count  = 20
  s.plants_max  = 20
  s.sede        = sede_prod
  s.created_by  = admin
  s.notes       = 'Plantas madre para producción de esquejes. Luz 18/6 permanente.'
end
puts "  ✅ #{sala_veg.nombre}, #{sala_flor.nombre}, #{sala_mad.nombre}"

# ── Asignar cultivadores ─────────────────────────────────────
SalaCultivador.find_or_create_by!(sala: sala_veg,  user: cultiv)
SalaCultivador.find_or_create_by!(sala: sala_flor, user: cultiv)
puts "  ✅ Cultivadores asignados"

# ── Genéticas para lotes ─────────────────────────────────────
og_kush   = club.geneticas.find_by(nombre: 'OG Kush')
polaris   = club.geneticas.find_by(nombre: 'POLARIS')
tropicana = club.geneticas.find_by(nombre: 'TROPICANA WFC')
harlequin = club.geneticas.find_by(nombre: 'Harlequin')
ananda    = club.geneticas.find_by(nombre: 'ANANDA001')

# ── Lotes con plantas reales ─────────────────────────────────
puts "\n📦 Creando lotes y plantas..."

def crear_lote_con_plantas(sala, attrs, genetica, n_plantas)
  lote = sala.lotes.find_or_initialize_by(sala: sala, estado: attrs[:estado], start_date: attrs[:start_date])
  return lote unless lote.new_record?

  lote.assign_attributes(attrs.merge(club: sala.club, genetica: genetica))
  lote.save!

  state_map = {
    'semilla'    => 'germinacion',
    'vegetativo' => 'vegetativo',
    'floracion'  => 'floracion',
    'cosecha'    => 'cosechado',
    'curado'     => 'cosechado',
    'finalizado' => 'cosechado',
  }
  state = state_map[attrs[:estado]] || 'vegetativo'

  n_plantas.times do |i|
    numero = (i + 1).to_s.rjust(3, '0')
    lote.plants.create!(
      nombre:   "#{lote.codigo}-P#{numero}",
      state:    state,
      genetica: genetica,
      )
  end

  lote.update_columns(plants_count: n_plantas)
  lote
end

lote1 = crear_lote_con_plantas(sala_veg, {
  estado: 'vegetativo', plants_count: 24,
  start_date: 35.days.ago.to_date,
  grow_type: 'sustrato', light_type: 'led',
  notes: 'Primer lote de la temporada. Plantas vigorosas.'
}, og_kush, 24)

lote2 = crear_lote_con_plantas(sala_veg, {
  estado: 'vegetativo', plants_count: 18,
  start_date: 20.days.ago.to_date,
  grow_type: 'sustrato', light_type: 'led',
  notes: 'Variedad ANANDA001 INASE. Monitoreo especial.'
}, ananda, 18)

lote3 = crear_lote_con_plantas(sala_flor, {
  estado: 'floracion', plants_count: 30,
  start_date: 50.days.ago.to_date,
  grow_type: 'sustrato', light_type: 'hps',
  notes: 'Alto CBD. Destinado a pacientes con epilepsia y dolor.'
}, polaris, 30)

lote4 = crear_lote_con_plantas(sala_flor, {
  estado: 'floracion', plants_count: 8,
  start_date: 45.days.ago.to_date,
  grow_type: 'hidroponia', light_type: 'led',
  notes: 'Lote medicinal CBD. Sistema hidropónico recirculante.'
}, harlequin, 8)

lote5 = crear_lote_con_plantas(sala_mad, {
  estado: 'vegetativo', plants_count: 8,
  start_date: 90.days.ago.to_date,
  grow_type: 'sustrato', light_type: 'led',
  notes: 'Plantas madre para producción de esquejes de Tropicana WFC.'
}, tropicana, 8)

puts "  ✅ #{Lote.count} lotes, #{Plant.count} plantas creadas"

# ── Pacientes ────────────────────────────────────────────────
puts "\n👥 Creando pacientes..."
hoy = Date.today

PACIENTES_DATA = [
  { nombre: 'María',     apellido: 'González',   dni: '28456789', fecha_nacimiento: Date.new(1975, 3, 15),  email: 'mgonzalez@email.com',  telefono: '+54 9 11 2345-6789', reprocann_numero: 'REP-2024-00123', reprocann_vencimiento: hoy + 18.months },
  { nombre: 'Juan',      apellido: 'Martínez',   dni: '35123456', fecha_nacimiento: Date.new(1988, 7, 22),  email: 'jmartinez@email.com',  telefono: '+54 9 11 3456-7890', reprocann_numero: 'REP-2024-00456', reprocann_vencimiento: hoy + 6.months  },
  { nombre: 'Laura',     apellido: 'Rodríguez',  dni: '31987654', fecha_nacimiento: Date.new(1982, 11, 8),  email: 'lrodriguez@email.com', telefono: '+54 9 11 4567-8901', reprocann_numero: 'REP-2023-00789', reprocann_vencimiento: hoy - 15.days   },
  { nombre: 'Carlos',    apellido: 'Fernández',  dni: '25678901', fecha_nacimiento: Date.new(1968, 5, 30),  email: 'cfernandez@email.com', telefono: '+54 9 11 5678-9012', reprocann_numero: 'REP-2024-00234', reprocann_vencimiento: hoy + 24.months },
  { nombre: 'Sofía',     apellido: 'López',      dni: '40234567', fecha_nacimiento: Date.new(1995, 9, 14),  email: 'slopez@email.com',     telefono: '+54 9 11 6789-0123', reprocann_numero: nil,              reprocann_vencimiento: nil             },
  { nombre: 'Roberto',   apellido: 'Díaz',       dni: '22345678', fecha_nacimiento: Date.new(1960, 2, 28),  email: 'rdiaz@email.com',      telefono: '+54 9 11 7890-1234', reprocann_numero: 'REP-2024-00567', reprocann_vencimiento: hoy + 20.days   },
  { nombre: 'Patricia',  apellido: 'Suárez',     dni: '33456789', fecha_nacimiento: Date.new(1985, 12, 3),  email: 'psuarez@email.com',    telefono: '+54 9 11 8901-2345', reprocann_numero: 'REP-2023-00890', reprocann_vencimiento: hoy - 45.days   },
  { nombre: 'Alejandro', apellido: 'Ruiz',       dni: '38567890', fecha_nacimiento: Date.new(1991, 6, 19),  email: 'aruiz@email.com',      telefono: '+54 9 11 9012-3456', reprocann_numero: 'REP-2024-00678', reprocann_vencimiento: hoy + 30.months },
].freeze

PACIENTES_DATA.each do |p|
  dni_norm = p[:dni].gsub(/\D/, '')
  socio = club.socios.find_or_initialize_by(dni_normalizado: dni_norm)
  socio.assign_attributes(
    nombre:                p[:nombre],
    apellido:              p[:apellido],
    dni:                   p[:dni],
    fecha_nacimiento:      p[:fecha_nacimiento],
    email:                 p[:email],
    telefono:              p[:telefono],
    reprocann_numero:      p[:reprocann_numero],
    reprocann_vencimiento: p[:reprocann_vencimiento],
    es_paciente:           true,
    created_by:            medico,
    )
  socio.save!
  puts "  👤 #{p[:nombre]} #{p[:apellido]}"
end

# ── Movimientos contables ─────────────────────────────────────
puts "\n💰 Creando movimientos contables..."
[
  { tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Marzo 2026',   monto_ars: 850000, fecha: 45.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Sustrato premium 40 bolsas',   monto_ars: 180000, fecha: 40.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'electricidad',   descripcion: 'Factura eléctrica Febrero',    monto_ars: 95000,  fecha: 35.days.ago.to_date, pagado: true, medio_pago: 'debito'        },
  { tipo: 'ingreso', categoria: 'aporte_socio',   descripcion: 'Cuotas socios - Abril 2026',   monto_ars: 920000, fecha: 10.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'honorario',      descripcion: 'Honorarios médico - Marzo',    monto_ars: 250000, fecha: 30.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Nutrientes Canna Coco A+B',    monto_ars: 75000,  fecha: 25.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'alquiler',       descripcion: 'Alquiler sede Avellaneda',     monto_ars: 400000, fecha: 30.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'alquiler',       descripcion: 'Alquiler sede Devoto',         monto_ars: 320000, fecha: 30.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'mantenimiento',  descripcion: 'Reemplazo lámparas HPS',       monto_ars: 145000, fecha: 15.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'sueldo',         descripcion: 'Sueldo cultivador - Marzo',    monto_ars: 380000, fecha: 28.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'subvencion',     descripcion: 'Donación socio benefactor',    monto_ars: 200000, fecha: 5.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Macetas 11L x 50 unidades',    monto_ars: 42000,  fecha: 20.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
].each do |m|
  club.movimientos_contables.create!(m.merge(created_by: admin))
end
puts "  ✅ #{club.movimientos_contables.count} movimientos"

# ── Noticias ─────────────────────────────────────────────────
puts "\n📰 Creando noticias..."
[
  { titulo: 'Nueva cosecha de POLARIS disponible',
    contenido: 'Nos complace informar que nuestra cosecha de POLARIS (registrada INASE) está disponible para dispensación. Presenta niveles excepcionales de CBD (12%) ideal para tratamientos neurológicos.',
    publicada: true, publicada_at: 3.days.ago },
  { titulo: 'Taller: Introducción al cultivo medicinal',
    contenido: 'El próximo mes realizaremos un taller gratuito para socios sobre técnicas básicas de cultivo. Cupos limitados. Inscribite en la recepción.',
    publicada: true, publicada_at: 7.days.ago },
  { titulo: 'Renovación de autorizaciones REPROCANN',
    contenido: 'Recordamos que las autorizaciones REPROCANN tienen vigencia de 3 años. Consulten con el equipo médico con anticipación para gestionar la renovación.',
    publicada: true, publicada_at: 10.days.ago },
].each do |n|
  club.noticias.find_or_create_by!(titulo: n[:titulo]) { |x| x.assign_attributes(n) }
end
puts "  ✅ 3 noticias"

# ── Eventos ──────────────────────────────────────────────────
puts "\n📅 Creando eventos..."
[
  { titulo: 'Charla: Cannabis medicinal y REPROCANN 2025',
    descripcion: 'Conversatorio sobre los cambios de la Resolución 1780/2025 y cómo afecta a los usuarios del programa.',
    fecha_inicio: 2.weeks.from_now.change(hour: 19), fecha_fin: 2.weeks.from_now.change(hour: 21),
    lugar: 'Sede Devoto', activo: true },
  { titulo: 'Taller de extracción de aceites',
    descripcion: 'Aprende técnicas seguras de extracción de aceites medicinales. Incluye demostración práctica.',
    fecha_inicio: 3.weeks.from_now.change(hour: 18), fecha_fin: 3.weeks.from_now.change(hour: 21),
    lugar: 'Sede Avellaneda', activo: true },
].each do |e|
  club.eventos.find_or_create_by!(titulo: e[:titulo]) { |x| x.assign_attributes(e) }
end
puts "  ✅ 2 eventos"

# ── Resumen ──────────────────────────────────────────────────
puts "\n" + "="*55
puts "🎉 Seeds completados exitosamente!"
puts "="*55
puts ""
puts "📧 Credenciales (password: 123456Aa)"
puts "  super_admin : superadmin@clubcultivo.app"
puts "  admin       : admin@mitocondriaclub.org"
puts "  médico      : medico@mitocondriaclub.org"
puts "  agricultor  : agricultor@mitocondriaclub.org"
puts "  cultivador  : cultivador@mitocondriaclub.org"
puts "  abogado     : abogado@mitocondriaclub.org"
puts ""
puts "📊 Data:"
puts "  🧬 Genéticas : #{club.geneticas.count} (#{club.geneticas.where(registrada_inase: true).count} INASE)"
puts "  👥 Pacientes : #{club.socios.count}"
puts "  🏢 Sedes     : #{club.sedes.count}"
puts "  🏗️  Salas     : #{club.salas.count}"
puts "  📦 Lotes     : #{club.lotes.count}"
puts "  🪴 Plantas   : #{Plant.joins(:lote).where(lotes: { club_id: club.id }).count}"
puts "  💰 Movimientos: #{club.movimientos_contables.count}"