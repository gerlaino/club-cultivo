puts "🌱 Iniciando seed de staging..."
puts "="*55

# ── Super Admins ─────────────────────────────────────────────
puts "\n👤 Creando super admins..."

[
  { email: 'superadmin@clubcultivo.app',         first_name: 'Super',  last_name: 'Admin'   },
  { email: 'javier_rebello@cultivoespacial.com', first_name: 'Javier', last_name: 'Rebello' },
  { email: 'gerlaino@cultivoespacial.com',       first_name: 'German', last_name: 'Laino'   },
].each do |u|
  user = User.find_or_initialize_by(email: u[:email])
  user.assign_attributes(
    password:   '123456Aa',
    role:       'super_admin',
    first_name: u[:first_name],
    last_name:  u[:last_name],
    )
  user.club_id = nil
  user.save!(validate: false)
  puts "  ✅ #{user.email} (super_admin)"
end

# ── Club de test ─────────────────────────────────────────────
puts "\n🏢 Creando club de test..."

club = Club.find_or_create_by!(name: 'Cannabis Verde Club') do |c|
  c.legal_name  = 'Asociación Civil Cannabis Verde'
  c.email       = 'contacto@cannabisverde.org.ar'
  c.phone       = '+54 11 4123-9876'
  c.website     = 'https://cannabisverde.org.ar'
  c.address     = 'Av. San Martín 4520, Piso 1'
  c.city        = 'Buenos Aires'
  c.state       = 'CABA'
  c.country     = 'Argentina'
  c.timezone    = 'America/Argentina/Buenos_Aires'
  c.plan        = 'cosecha'
  c.plan_trial  = false
  c.plan_activo_hasta         = 1.year.from_now.to_date
  c.cuit                      = '30-71234567-8'
  c.numero_igj                = 'IGJ-2023-0045821'
  c.numero_resolucion_reprocann = 'REPROCANN-2024-00312'
  c.fecha_resolucion_reprocann  = Date.new(2024, 3, 15)
  c.tipo_organizacion           = 'asociacion_civil'
end
puts "  ✅ #{club.name} (plan: #{club.plan})"

# ── Usuarios del club ─────────────────────────────────────────
puts "\n👥 Creando usuarios del club..."

usuarios_data = [
  { email: 'admin@cannabisverde.org.ar',      role: 'admin',      first_name: 'Valentina', last_name: 'Moreno'     },
  { email: 'medico@cannabisverde.org.ar',     role: 'medico',     first_name: 'Federico',  last_name: 'Altamirano' },
  { email: 'agricultor@cannabisverde.org.ar', role: 'agricultor', first_name: 'Ramiro',    last_name: 'Castillo'   },
  { email: 'cultivador@cannabisverde.org.ar', role: 'cultivador', first_name: 'Nahuel',    last_name: 'Pereyra'    },
  { email: 'abogado@cannabisverde.org.ar',    role: 'abogado',    first_name: 'Florencia', last_name: 'Ibáñez'     },
  { email: 'auditor@cannabisverde.org.ar',    role: 'auditor',    first_name: 'Marcelo',   last_name: 'Vega'       },
]

usuarios = {}
usuarios_data.each do |u|
  user = User.find_or_initialize_by(email: u[:email])
  user.assign_attributes(u.merge(club: club, password: '123456Aa'))
  user.save!
  usuarios[u[:role]] = user
  puts "  ✅ #{user.email} (#{user.role})"
end

admin    = usuarios['admin']
medico   = usuarios['medico']
cultiv   = usuarios['cultivador']
agricult = usuarios['agricultor']

# ── Genéticas ─────────────────────────────────────────────────
puts "\n🧬 Creando genéticas..."
club.crear_geneticas_default! rescue nil

[
  { nombre: 'OG Kush',          tipo: 'hibrida', thc: 22.0, cbd: 0.3,  origen: 'California, EEUU',    criador: 'Chemdawg x Hindu Kush',  terpenos: 'Mirceno, Limoneno, Cariofileno', tiempo_floracion: 63, rendimiento: 400, altura: 90,  dificultad: 'intermedia', descripcion: 'Clasica californiana. Aroma a tierra, pino y limon. Efectos relajantes y analgesicos.',         registrada_inase: false, disponible: true, activa: true },
  { nombre: 'White Widow',      tipo: 'hibrida', thc: 19.0, cbd: 0.2,  origen: 'Paises Bajos',        criador: 'Green House Seeds',      terpenos: 'Mirceno, Cariofileno, Pineno',   tiempo_floracion: 60, rendimiento: 450, altura: 100, dificultad: 'facil',      descripcion: 'Iconica holandesa. Cubierta de resina blanca. Efectos euforicos y creativos.',                  registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Northern Lights',  tipo: 'indica',  thc: 18.0, cbd: 0.5,  origen: 'Afganistan',          criador: 'Sensi Seeds',            terpenos: 'Mirceno, Cariofileno, Linalool', tiempo_floracion: 56, rendimiento: 500, altura: 100, dificultad: 'facil',      descripcion: 'Indica clasica. Relajante profunda, ideal para el sueno y dolor neuropatico.',                  registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Harlequin',        tipo: 'sativa',  thc: 7.0,  cbd: 10.5, origen: 'Colombia/Nepal',      criador: 'Cruza multiregional',    terpenos: 'Mirceno, Cariofileno, Pineno',   tiempo_floracion: 65, rendimiento: 350, altura: 150, dificultad: 'intermedia', descripcion: 'Alta en CBD. Relacion 1:1.5 THC/CBD. Ideal para uso medicinal diurno.',                           registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Critical Mass CBD',tipo: 'indica',  thc: 5.0,  cbd: 8.0,  origen: 'Afghanistan x Skunk', criador: 'CBD Crew',               terpenos: 'Mirceno, Linalool, Cariofileno', tiempo_floracion: 56, rendimiento: 600, altura: 100, dificultad: 'facil',      descripcion: 'Medicinal de alto CBD. Sin efectos psicoactivos marcados. Popular en clubes REPROCANN.',       registrada_inase: false, disponible: true, activa: true },
  { nombre: 'Cheese',           tipo: 'indica',  thc: 17.0, cbd: 0.4,  origen: 'Reino Unido',         criador: 'Skunk #1 UK phenotype',  terpenos: 'Cariofileno, Mirceno, Linalool', tiempo_floracion: 60, rendimiento: 450, altura: 100, dificultad: 'facil',      descripcion: 'Aroma caracteristico a queso. Efectos relajantes y euforicos equilibrados.',                   registrada_inase: false, disponible: true, activa: true },
].each do |g|
  next if club.geneticas.exists?(nombre: g[:nombre])
  club.geneticas.create!(g)
  puts "  🌿 #{g[:nombre]}"
end
puts "  ✅ #{club.geneticas.count} geneticas (#{club.geneticas.where(registrada_inase: true).count} INASE)"

# ── Sedes ──────────────────────────────────────────────────────
puts "\n🏢 Creando sedes..."

sede_prod = club.sedes.find_or_create_by!(nombre: 'Palermo Produccion') do |s|
  s.tipo                = 'produccion'
  s.direccion           = 'Thames 1650'
  s.ciudad              = 'Buenos Aires'
  s.provincia           = 'CABA'
  s.declarada_reprocann = true
  s.created_by          = admin
  s.notas               = 'Sede principal de produccion. Tres salas activas con control climatico automatizado.'
end

sede_social = club.sedes.find_or_create_by!(nombre: 'Caballito Social') do |s|
  s.tipo                = 'social'
  s.direccion           = 'Av. Rivadavia 5890'
  s.ciudad              = 'Buenos Aires'
  s.provincia           = 'CABA'
  s.declarada_reprocann = true
  s.created_by          = admin
  s.notas               = 'Dispensario, consultorios medicos y sala de reuniones para socios.'
end

sede_mixta = club.sedes.find_or_create_by!(nombre: 'Lanus Mixta') do |s|
  s.tipo                = 'mixta'
  s.direccion           = 'Av. Hipolito Yrigoyen 3421'
  s.ciudad              = 'Lanus'
  s.provincia           = 'Buenos Aires'
  s.declarada_reprocann = false
  s.created_by          = admin
  s.notas               = 'Sede en proceso de habilitacion REPROCANN. Zona sur GBA.'
end

puts "  ✅ #{sede_prod.nombre}, #{sede_social.nombre}, #{sede_mixta.nombre}"

# ── Salas ──────────────────────────────────────────────────────
puts "\n🏗️  Creando salas..."

sala_veg = club.salas.find_or_create_by!(nombre: 'Vegetativo A') do |s|
  s.state       = 'activa'
  s.kind        = 'vegetativo'
  s.pots_count  = 60
  s.plants_max  = 60
  s.sede        = sede_prod
  s.created_by  = admin
  s.notes       = 'LED Samsung LM301H 18/6. Temperatura 22-25, HR 65-70. Control automatico.'
end

sala_flor = club.salas.find_or_create_by!(nombre: 'Floracion B') do |s|
  s.state       = 'activa'
  s.kind        = 'floracion'
  s.pots_count  = 36
  s.plants_max  = 36
  s.sede        = sede_prod
  s.created_by  = admin
  s.notes       = 'HPS 600W + CMH 315W. 12/12. HR 45-55. CO2 suplementado a 1200ppm.'
end

sala_mad = club.salas.find_or_create_by!(nombre: 'Sala Madres') do |s|
  s.state       = 'activa'
  s.kind        = 'madre'
  s.pots_count  = 20
  s.plants_max  = 20
  s.sede        = sede_prod
  s.created_by  = admin
  s.notes       = 'Plantas madre para clonado. Luz 20/4. Macetas 15L en sustrato coco.'
end

puts "  ✅ #{sala_veg.nombre}, #{sala_flor.nombre}, #{sala_mad.nombre}"

SalaCultivador.find_or_create_by!(sala: sala_veg,  user: cultiv)
SalaCultivador.find_or_create_by!(sala: sala_flor, user: cultiv)
puts "  ✅ Cultivadores asignados"

# ── Geneticas referencia ───────────────────────────────────────
og_kush       = club.geneticas.find_by(nombre: 'OG Kush')
harlequin     = club.geneticas.find_by(nombre: 'Harlequin')
critical_mass = club.geneticas.find_by(nombre: 'Critical Mass CBD')
polaris       = club.geneticas.find_by(nombre: 'POLARIS')
ananda        = club.geneticas.find_by(nombre: 'ANANDA001')
tropicana     = club.geneticas.find_by(nombre: 'TROPICANA WFC')

# ── Lotes ──────────────────────────────────────────────────────
puts "\n📦 Creando lotes y plantas..."

state_map = {
  'semilla'    => 'germinacion',
  'vegetativo' => 'vegetativo',
  'floracion'  => 'floracion',
  'cosecha'    => 'cosechado',
  'curado'     => 'cosechado',
  'finalizado' => 'cosechado',
}

def crear_lote(sala, attrs, genetica, n_plantas, state_map)
  lote = sala.lotes.where(estado: attrs[:estado], start_date: attrs[:start_date]).first
  return lote if lote
  lote = sala.lotes.build(attrs.merge(club: sala.club, genetica: genetica))
  lote.save!
  state = state_map[attrs[:estado]] || 'vegetativo'
  n_plantas.times do |i|
    numero = (i + 1).to_s.rjust(3, '0')
    lote.plants.create!(nombre: "#{lote.codigo}-P#{numero}", state: state, genetica: genetica)
  end
  lote.update_columns(plants_count: n_plantas)
  lote
end

lote_veg1  = crear_lote(sala_veg,  { estado: 'vegetativo', plants_count: 20, start_date: 28.days.ago.to_date, grow_type: 'sustrato',  light_type: 'led', notes: 'OG Kush semana 4. Crecimiento uniforme.'                             }, og_kush,       20, state_map)
lote_veg2  = crear_lote(sala_veg,  { estado: 'vegetativo', plants_count: 18, start_date: 14.days.ago.to_date, grow_type: 'sustrato',  light_type: 'led', notes: 'ANANDA001 INASE. Monitoreo especial, alto potencial CBD.'              }, ananda,        18, state_map)
lote_flor1 = crear_lote(sala_flor, { estado: 'floracion',  plants_count: 20, start_date: 55.days.ago.to_date, grow_type: 'sustrato',  light_type: 'hps', notes: 'POLARIS semana 7. Tricomas en maduracion. Cosecha estimada 2 semanas.' }, polaris,       20, state_map)
lote_flor2 = crear_lote(sala_flor, { estado: 'floracion',  plants_count: 10, start_date: 42.days.ago.to_date, grow_type: 'hidroponia', light_type: 'led', notes: 'Harlequin hidro semana 6. CBD excepcional. Pacientes neurologicos.'    }, harlequin,     10, state_map)
lote_mad   = crear_lote(sala_mad,  { estado: 'vegetativo', plants_count: 8,  start_date: 120.days.ago.to_date,grow_type: 'sustrato',  light_type: 'led', notes: 'Plantas madre Tropicana WFC. Produccion de esquejes semanal.'          }, tropicana,      8, state_map)
lote_fin   = crear_lote(sala_flor, { estado: 'finalizado', plants_count: 15, start_date: 110.days.ago.to_date,grow_type: 'sustrato',  light_type: 'hps', notes: 'Critical Mass CBD cosechado. Rendimiento: 420g. Excelente calidad.'    }, critical_mass, 15, state_map)

puts "  ✅ #{club.lotes.count} lotes, #{Plant.joins(:lote).where(lotes: { club_id: club.id }).count} plantas"

# ── Socios ─────────────────────────────────────────────────────
puts "\n👥 Creando socios (con vencimientos variados para testear alertas)..."
hoy = Date.today

socios_data = [
  { nombre: 'Maria',     apellido: 'Gonzalez',  dni: '28456789', fecha_nacimiento: Date.new(1975, 3, 15),  email: 'mgonzalez@email.com',  telefono: '+54 9 11 2345-6789', reprocann_numero: 'REP-2024-00123', reprocann_vencimiento: hoy + 18.months },
  { nombre: 'Juan',      apellido: 'Martinez',  dni: '35123456', fecha_nacimiento: Date.new(1988, 7, 22),  email: 'jmartinez@email.com',  telefono: '+54 9 11 3456-7890', reprocann_numero: 'REP-2024-00456', reprocann_vencimiento: hoy + 24.months },
  { nombre: 'Carlos',    apellido: 'Fernandez', dni: '25678901', fecha_nacimiento: Date.new(1968, 5, 30),  email: 'cfernandez@email.com', telefono: '+54 9 11 5678-9012', reprocann_numero: 'REP-2024-00234', reprocann_vencimiento: hoy + 30.months },
  { nombre: 'Alejandro', apellido: 'Ruiz',      dni: '38567890', fecha_nacimiento: Date.new(1991, 6, 19),  email: 'aruiz@email.com',      telefono: '+54 9 11 9012-3456', reprocann_numero: 'REP-2024-00678', reprocann_vencimiento: hoy + 20.months },
  { nombre: 'Sofia',     apellido: 'Lopez',     dni: '40234567', fecha_nacimiento: Date.new(1995, 9, 14),  email: 'slopez@email.com',     telefono: '+54 9 11 6789-0123', reprocann_numero: 'REP-2025-00111', reprocann_vencimiento: hoy + 14.months },
  { nombre: 'Roberto',   apellido: 'Diaz',      dni: '22345678', fecha_nacimiento: Date.new(1960, 2, 28),  email: 'rdiaz@email.com',      telefono: '+54 9 11 7890-1234', reprocann_numero: 'REP-2024-00567', reprocann_vencimiento: hoy + 25.days   },
  { nombre: 'Luciana',   apellido: 'Herrera',   dni: '36789012', fecha_nacimiento: Date.new(1989, 4, 7),   email: 'lherrera@email.com',   telefono: '+54 9 11 1234-5678', reprocann_numero: 'REP-2024-00789', reprocann_vencimiento: hoy + 18.days   },
  { nombre: 'Tomas',     apellido: 'Acosta',    dni: '41890123', fecha_nacimiento: Date.new(1997, 11, 25), email: 'tacosta@email.com',    telefono: '+54 9 11 2233-4455', reprocann_numero: 'REP-2024-00890', reprocann_vencimiento: hoy + 8.days    },
  { nombre: 'Laura',     apellido: 'Rodriguez', dni: '31987654', fecha_nacimiento: Date.new(1982, 11, 8),  email: 'lrodriguez@email.com', telefono: '+54 9 11 4567-8901', reprocann_numero: 'REP-2023-00789', reprocann_vencimiento: hoy - 12.days   },
  { nombre: 'Patricia',  apellido: 'Suarez',    dni: '33456789', fecha_nacimiento: Date.new(1985, 12, 3),  email: 'psuarez@email.com',    telefono: '+54 9 11 8901-2345', reprocann_numero: 'REP-2023-00890', reprocann_vencimiento: hoy - 40.days   },
  { nombre: 'Diego',     apellido: 'Paredes',   dni: '44123456', fecha_nacimiento: Date.new(2000, 3, 10),  email: 'dparedes@email.com',   telefono: '+54 9 11 5544-3322', reprocann_numero: nil,              reprocann_vencimiento: nil             },
]

socios_creados = []
socios_data.each do |p|
  dni_norm = p[:dni].gsub(/\D/, '')
  socio = club.socios.find_or_initialize_by(dni_normalizado: dni_norm)
  socio.assign_attributes(p.merge(es_paciente: true, created_by: medico))
  socio.save!
  socios_creados << socio
  estado = if p[:reprocann_vencimiento].nil? then 'sin REPROCANN'
           elsif p[:reprocann_vencimiento] < hoy then 'VENCIDO'
           elsif p[:reprocann_vencimiento] < hoy + 30.days then 'por vencer'
           else 'vigente'
           end
  puts "  #{p[:nombre]} #{p[:apellido]} — #{estado}"
end

# ── Dispensaciones ─────────────────────────────────────────────
puts "\n💊 Creando dispensaciones..."
[socios_creados[0], socios_creados[1], socios_creados[2]].each_with_index do |socio, i|
  next unless socio
  [45, 30, 15].each do |dias|
    club.dispensaciones.create!(
      socio:      socio,
      created_by: medico,
      fecha:      dias.days.ago.to_date,
      cantidad_g: (10 + i * 5).to_f,
      notas:      'Dispensacion mensual regular.',
      ) rescue nil
  end
end
puts "  ✅ Dispensaciones creadas"

# ── Movimientos contables ──────────────────────────────────────
puts "\n💰 Creando movimientos contables..."
[
  { tipo: 'ingreso', categoria: 'aporte_socio',   descripcion: 'Cuotas socios - Febrero 2026',   monto_ars: 780000,  fecha: 65.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'aporte_socio',   descripcion: 'Cuotas socios - Marzo 2026',     monto_ars: 830000,  fecha: 35.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'aporte_socio',   descripcion: 'Cuotas socios - Abril 2026',     monto_ars: 910000,  fecha: 5.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'subvencion',     descripcion: 'Donacion socio benefactor',       monto_ars: 300000,  fecha: 20.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'otro',           descripcion: 'Venta excedente semillas',        monto_ars: 45000,   fecha: 10.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'alquiler',       descripcion: 'Alquiler sede Palermo - Feb',     monto_ars: 520000,  fecha: 60.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'alquiler',       descripcion: 'Alquiler sede Caballito - Feb',   monto_ars: 380000,  fecha: 60.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'alquiler',       descripcion: 'Alquiler sede Palermo - Mar',     monto_ars: 520000,  fecha: 30.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'alquiler',       descripcion: 'Alquiler sede Caballito - Mar',   monto_ars: 380000,  fecha: 30.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'electricidad',   descripcion: 'Factura electrica Febrero',       monto_ars: 145000,  fecha: 55.days.ago.to_date, pagado: true, medio_pago: 'debito'        },
  { tipo: 'egreso',  categoria: 'electricidad',   descripcion: 'Factura electrica Marzo',         monto_ars: 162000,  fecha: 25.days.ago.to_date, pagado: true, medio_pago: 'debito'        },
  { tipo: 'egreso',  categoria: 'honorario',      descripcion: 'Honorarios Dr. Altamirano - Feb', monto_ars: 320000,  fecha: 58.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'honorario',      descripcion: 'Honorarios Dr. Altamirano - Mar', monto_ars: 320000,  fecha: 28.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'sueldo',         descripcion: 'Sueldo cultivador - Febrero',     monto_ars: 420000,  fecha: 58.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'sueldo',         descripcion: 'Sueldo cultivador - Marzo',       monto_ars: 420000,  fecha: 28.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Sustrato coco 50 bolsas',         monto_ars: 210000,  fecha: 45.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Nutrientes Plagron Coco A+B',     monto_ars: 98000,   fecha: 40.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Macetas 11L x 80 unidades',       monto_ars: 67200,   fecha: 35.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'insumo',         descripcion: 'Lamparas LED Samsung 480W x4',    monto_ars: 380000,  fecha: 50.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'mantenimiento',  descripcion: 'Servicio tecnico sistema riego',  monto_ars: 85000,   fecha: 22.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'mantenimiento',  descripcion: 'Cambio filtros HEPA aire',         monto_ars: 54000,   fecha: 15.days.ago.to_date, pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'administrativo', descripcion: 'Gestoria renovacion habilitacion', monto_ars: 120000,  fecha: 12.days.ago.to_date, pagado: true, medio_pago: 'transferencia' },
].each { |m| club.movimientos_contables.create!(m.merge(created_by: admin)) }
puts "  ✅ #{club.movimientos_contables.count} movimientos contables"

# ── Noticias ───────────────────────────────────────────────────
puts "\n📰 Creando noticias..."
[
  { titulo: 'Nueva cosecha de POLARIS disponible',
    contenido: 'Tenemos el agrado de informar que nuestra cosecha de POLARIS (variedad registrada INASE) esta disponible para dispensacion. CBD 12.3%, THC 0.8%. Ideal para tratamientos neurologicos.',
    publicada: true, publicada_at: 4.days.ago },
  { titulo: 'Taller gratuito: Introduccion al cultivo medicinal',
    contenido: 'Realizaremos un taller gratuito para socios sobre tecnicas basicas de cultivo indoor. Cupos limitados a 15 personas. Inscribite en recepcion.',
    publicada: true, publicada_at: 8.days.ago },
  { titulo: 'Resolucion 1780/2025 — Novedades REPROCANN',
    contenido: 'La Resolucion 1780/2025 amplio el cuadro de enfermedades habilitadas para el programa REPROCANN. Consulta con nuestra medica para evaluar tu situacion.',
    publicada: true, publicada_at: 12.days.ago },
  { titulo: 'Sistema de turnos online disponible',
    contenido: 'Ya podes solicitar turno para dispensacion y consulta medica a traves de la app. El sistema esta disponible 24/7.',
    publicada: true, publicada_at: 18.days.ago },
].each do |n|
  club.noticias.find_or_create_by!(titulo: n[:titulo]) { |x| x.assign_attributes(n) } rescue nil
end
puts "  ✅ 4 noticias"

# ── Eventos ────────────────────────────────────────────────────
puts "\n📅 Creando eventos..."
[
  { titulo: 'Charla: Cannabis medicinal y nuevas regulaciones 2025',
    descripcion: 'Conversatorio sobre la Res. 1780/2025, registro INASE y derechos de usuarios REPROCANN.',
    fecha_inicio: 10.days.from_now.change(hour: 19), fecha_fin: 10.days.from_now.change(hour: 21),
    lugar: 'Sede Caballito', activo: true },
  { titulo: 'Taller practico de extraccion de aceites CBD',
    descripcion: 'Tecnicas seguras de extraccion de aceites medicinales. Demostracion con material vegetal del club.',
    fecha_inicio: 17.days.from_now.change(hour: 18), fecha_fin: 17.days.from_now.change(hour: 21),
    lugar: 'Sede Palermo Produccion', activo: true },
  { titulo: 'Asamblea anual de socios',
    descripcion: 'Presentacion del balance economico 2025-2026 y plan de expansion segundo semestre.',
    fecha_inicio: 25.days.from_now.change(hour: 18), fecha_fin: 25.days.from_now.change(hour: 20),
    lugar: 'Sede Caballito', activo: true },
].each do |e|
  club.eventos.find_or_create_by!(titulo: e[:titulo]) { |x| x.assign_attributes(e) } rescue nil
end
puts "  ✅ 3 eventos"

# ── Tareas ─────────────────────────────────────────────────────
puts "\n📋 Creando tareas..."
[
  { titulo: 'Riego lote Vegetativo A',       lote: lote_veg1,  sala: sala_veg,  asignada_a: cultiv,  fecha_programada: Date.today,              estado: 'pendiente',  prioridad: 'alta'   },
  { titulo: 'Control pH hidro Harlequin',    lote: lote_flor2, sala: sala_flor, asignada_a: cultiv,  fecha_programada: Date.today,              estado: 'pendiente',  prioridad: 'alta'   },
  { titulo: 'Defoliacion lote floracion',    lote: lote_flor1, sala: sala_flor, asignada_a: cultiv,  fecha_programada: 2.days.from_now.to_date, estado: 'pendiente',  prioridad: 'media'  },
  { titulo: 'Esquejes plantas madre',        lote: lote_mad,   sala: sala_mad,  asignada_a: agricult,fecha_programada: 3.days.from_now.to_date, estado: 'pendiente',  prioridad: 'media'  },
  { titulo: 'Medicion ambiental Veg A',      lote: lote_veg1,  sala: sala_veg,  asignada_a: cultiv,  fecha_programada: Date.yesterday,          estado: 'completada', prioridad: 'normal' },
  { titulo: 'Inspeccion raices hidro',       lote: lote_flor2, sala: sala_flor, asignada_a: cultiv,  fecha_programada: 2.days.ago.to_date,      estado: 'completada', prioridad: 'alta'   },
].each do |t|
  lote_id = t.delete(:lote)&.id
  sala_id = t.delete(:sala)&.id
  descripcion = t.delete(:descripcion) { "Tarea de mantenimiento regular." }
  club.tareas.create!(t.merge(club: club, creada_por: admin, lote_id: lote_id, sala_id: sala_id, descripcion: descripcion)) rescue nil
end
puts "  ✅ #{club.tareas.count} tareas creadas"

# ── Resumen final ──────────────────────────────────────────────
puts "\n" + "="*55
puts "✅ Seed de staging completado!"
puts "="*55
puts ""
puts "🔑 Super Admins (pass: 123456Aa)"
puts "  gerlaino@cultivoespacial.com"
puts "  javier_rebello@cultivoespacial.com"
puts "  superadmin@clubcultivo.app"
puts ""
puts "🏢 Club: #{club.name} (pass: 123456Aa para todos)"
puts "  admin      : admin@cannabisverde.org.ar"
puts "  medico     : medico@cannabisverde.org.ar"
puts "  agricultor : agricultor@cannabisverde.org.ar"
puts "  cultivador : cultivador@cannabisverde.org.ar"
puts "  abogado    : abogado@cannabisverde.org.ar"
puts "  auditor    : auditor@cannabisverde.org.ar"
puts ""
puts "📊 Datos:"
puts "  Geneticas  : #{club.geneticas.count} (#{club.geneticas.where(registrada_inase: true).count} INASE)"
puts "  Sedes      : #{club.sedes.count}"
puts "  Salas      : #{club.salas.count}"
puts "  Lotes      : #{club.lotes.count} (1 finalizado para historial)"
puts "  Plantas    : #{Plant.joins(:lote).where(lotes: { club_id: club.id }).count}"
puts "  Socios     : #{club.socios.count} (2 vencidos, 2 por vencer, 1 sin REPROCANN)"
puts "  Movimientos: #{club.movimientos_contables.count}"
puts "  Tareas     : #{club.tareas.count} (2 completadas)"