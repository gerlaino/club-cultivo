# ============================================================
# SEEDS — Club Cultivo · Dataset completo para testing UI/UX
# ============================================================
puts "🌱 Iniciando seeds..."

# ── Super Admin ──────────────────────────────────────────────
puts "\n👤 Super admin..."
sa = User.find_or_initialize_by(email: 'super@clubcultivo.app')
sa.assign_attributes(password: '123456Aa', role: 'super_admin', first_name: 'Super', last_name: 'Admin')
sa.club_id = nil
sa.save!(validate: false)
puts "  ✅ #{sa.email}"

# ── Club ─────────────────────────────────────────────────────
puts "\n🏢 Club..."
club = Club.find_or_create_by!(name: 'Mitocondria Club') do |c|
  c.legal_name                    = 'Asociación Civil Mitocondria'
  c.email                         = 'contacto@mitocondriaclub.org'
  c.phone                         = '+54 11 4567-8901'
  c.website                       = 'https://mitocondriaclub.org'
  c.address                       = 'Av. Corrientes 1234, Piso 2'
  c.city                          = 'Buenos Aires'
  c.state                         = 'CABA'
  c.country                       = 'Argentina'
  c.timezone                      = 'America/Argentina/Buenos_Aires'
  c.plan                          = 'cosecha'
  c.plan_trial                    = false
  c.plan_activo_hasta             = 1.year.from_now.to_date
  c.cuit                          = '30-71234567-8'
  c.numero_igj                    = 'IGJ 1234/2022'
  c.numero_resolucion_reprocann   = 'RES-2024-1780-APN-ANMAT'
  c.fecha_resolucion_reprocann    = Date.new(2024, 3, 15)
  c.tipo_organizacion             = 'asociacion_civil'
end
puts "  ✅ #{club.name}"

# ── Usuarios ─────────────────────────────────────────────────
puts "\n👥 Usuarios..."
def crear_user(club, attrs)
  u = User.find_or_initialize_by(email: attrs[:email])
  u.assign_attributes(attrs.merge(club: club, password: '123456Aa'))
  u.save!
  u
end

admin      = crear_user(club, email: 'admin@mitocondriaclub.org',      role: 'admin',      first_name: 'Pablo',    last_name: 'Ezquer')
medico     = crear_user(club, email: 'medico@mitocondriaclub.org',     role: 'medico',     first_name: 'Ana',      last_name: 'García')
agricultor = crear_user(club, email: 'agricultor@mitocondriaclub.org', role: 'agricultor', first_name: 'Martín',   last_name: 'López')
cultivador = crear_user(club, email: 'cultivador@mitocondriaclub.org', role: 'cultivador', first_name: 'Diego',    last_name: 'Fernández')
manicurador= crear_user(club, email: 'manicura@mitocondriaclub.org',   role: 'manicurador',first_name: 'Valentina',last_name: 'Reyes')
dispensador= crear_user(club, email: 'dispensa@mitocondriaclub.org',   role: 'dispensador',first_name: 'Lucía',    last_name: 'Bianchi')
tesorero   = crear_user(club, email: 'tesorero@mitocondriaclub.org',   role: 'tesorero',   first_name: 'Hernán',   last_name: 'Vidal')
abogado    = crear_user(club, email: 'abogado@mitocondriaclub.org',    role: 'abogado',    first_name: 'Claudia',  last_name: 'Torres')
auditor    = crear_user(club, email: 'auditor@mitocondriaclub.org',    role: 'auditor',    first_name: 'Roberto',  last_name: 'Sánchez')
socio_user = crear_user(club, email: 'socio@mitocondriaclub.org',      role: 'socio',      first_name: 'Marcos',   last_name: 'Villalba')
puts "  ✅ 10 usuarios creados"

# ── Genéticas ────────────────────────────────────────────────
puts "\n🧬 Genéticas..."
club.crear_geneticas_default!

[
  { nombre: 'OG Kush',          tipo: 'hibrida', thc: 22.0, cbd: 0.3,  tiempo_floracion: 63, rendimiento: 400, dificultad: 'intermedia', registrada_inase: false, disponible: true, activa: true, origen: 'California, EEUU' },
  { nombre: 'White Widow',      tipo: 'hibrida', thc: 19.0, cbd: 0.2,  tiempo_floracion: 60, rendimiento: 450, dificultad: 'facil',      registrada_inase: false, disponible: true, activa: true, origen: 'Países Bajos'    },
  { nombre: 'Northern Lights',  tipo: 'indica',  thc: 18.0, cbd: 0.5,  tiempo_floracion: 56, rendimiento: 500, dificultad: 'facil',      registrada_inase: false, disponible: true, activa: true, origen: 'Afganistán'      },
  { nombre: 'Harlequin',        tipo: 'sativa',  thc: 7.0,  cbd: 10.5, tiempo_floracion: 65, rendimiento: 350, dificultad: 'intermedia', registrada_inase: false, disponible: true, activa: true, origen: 'Colombia/Nepal'  },
  { nombre: 'Critical Mass CBD',tipo: 'indica',  thc: 5.0,  cbd: 8.0,  tiempo_floracion: 56, rendimiento: 600, dificultad: 'facil',      registrada_inase: false, disponible: true, activa: true, origen: 'Afganistán x Skunk' },
  { nombre: 'Amnesia Haze',     tipo: 'sativa',  thc: 21.0, cbd: 0.1,  tiempo_floracion: 70, rendimiento: 520, dificultad: 'avanzada',   registrada_inase: false, disponible: true, activa: true, origen: 'Países Bajos'    },
  { nombre: 'Blue Dream',       tipo: 'hibrida', thc: 20.0, cbd: 0.5,  tiempo_floracion: 65, rendimiento: 480, dificultad: 'facil',      registrada_inase: false, disponible: true, activa: true, origen: 'California, EEUU' },
].each do |g|
  next if club.geneticas.exists?(nombre: g[:nombre])
  club.geneticas.create!(g)
end
puts "  ✅ #{club.geneticas.count} genéticas (#{club.geneticas.where(registrada_inase: true).count} INASE)"

# referencias
og_kush    = club.geneticas.find_by!(nombre: 'OG Kush')
harlequin  = club.geneticas.find_by!(nombre: 'Harlequin')
nl         = club.geneticas.find_by!(nombre: 'Northern Lights')
ww         = club.geneticas.find_by!(nombre: 'White Widow')
cm_cbd     = club.geneticas.find_by!(nombre: 'Critical Mass CBD')
amnesia    = club.geneticas.find_by!(nombre: 'Amnesia Haze')
blue_dream = club.geneticas.find_by!(nombre: 'Blue Dream')
polaris    = club.geneticas.find_by(nombre: 'POLARIS') || og_kush
ananda     = club.geneticas.find_by(nombre: 'ANANDA001') || harlequin

# ── Sedes ────────────────────────────────────────────────────
puts "\n🏢 Sedes..."
sede_prod = club.sedes.find_or_create_by!(nombre: 'Avellaneda') do |s|
  s.tipo = 'produccion'; s.direccion = 'Av. Mitre 2340'; s.ciudad = 'Avellaneda'
  s.provincia = 'Buenos Aires'; s.declarada_reprocann = true; s.created_by = admin
  s.notas = 'Sede principal de producción. Salas de vegetativo, floración y madre.'
end
sede_disp = club.sedes.find_or_create_by!(nombre: 'Devoto') do |s|
  s.tipo = 'social'; s.direccion = 'Francisco Beiró 4580'; s.ciudad = 'Buenos Aires'
  s.provincia = 'CABA'; s.declarada_reprocann = true; s.created_by = admin
  s.notas = 'Dispensario y atención a socios. Horario L-V 14-20hs.'
end
sede_mixta = club.sedes.find_or_create_by!(nombre: 'Pompeya') do |s|
  s.tipo = 'mixta'; s.direccion = 'Pagola 4135'; s.ciudad = 'Buenos Aires'
  s.provincia = 'CABA'; s.declarada_reprocann = false; s.created_by = admin
  s.notas = 'Sede mixta en expansión. Sala de curado + dispensario pequeño.'
end
puts "  ✅ #{sede_prod.nombre}, #{sede_disp.nombre}, #{sede_mixta.nombre}"

# ── Salas ────────────────────────────────────────────────────
puts "\n🏗️  Salas..."
sala_veg = club.salas.find_or_create_by!(nombre: 'Sala Vegetativo') do |s|
  s.state = 'activa'; s.kind = 'vegetativo'; s.pots_count = 80; s.plants_max = 80
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'LED 18/6, temperatura 22-26°C, humedad 65-70%.'
end
sala_flor = club.salas.find_or_create_by!(nombre: 'Sala Floración') do |s|
  s.state = 'activa'; s.kind = 'floracion'; s.pots_count = 50; s.plants_max = 50
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'HPS 600W 12/12, humedad 45-55%, extracción forzada.'
end
sala_mad = club.salas.find_or_create_by!(nombre: 'Sala Madres') do |s|
  s.state = 'activa'; s.kind = 'madre'; s.pots_count = 20; s.plants_max = 20
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'Madres y esquejes, luz 18/6 permanente.'
end
sala_curado = club.salas.find_or_create_by!(nombre: 'Sala Curado') do |s|
  s.state = 'activa'; s.kind = 'secado'; s.pots_count = 0; s.plants_max = 0
  s.sede = sede_mixta; s.created_by = admin
  s.notes = 'Curado en oscuridad, HR 58-62%, temp 18°C.'
end
puts "  ✅ #{[sala_veg, sala_flor, sala_mad, sala_curado].map(&:nombre).join(', ')}"

# ── Asignar cultivador y manicurador ─────────────────────────
SalaCultivador.find_or_create_by!(sala: sala_veg,  user: cultivador)
SalaCultivador.find_or_create_by!(sala: sala_flor, user: cultivador)
SalaCultivador.find_or_create_by!(sala: sala_flor, user: manicurador)
puts "  ✅ Cultivador → veg+flor | Manicurador → flor"

# ── Lotes y plantas ──────────────────────────────────────────
puts "\n📦 Lotes y plantas..."

STATE_MAP = {
  'semilla'    => 'germinacion',
  'vegetativo' => 'vegetativo',
  'floracion'  => 'floracion',
  'cosecha'    => 'cosechado',
  'curado'     => 'cosechado',
  'finalizado' => 'cosechado',
}.freeze

def crear_lote(sala, attrs, genetica, n_plantas)
  codigo = attrs[:codigo] || "#{sala.nombre[0..2].upcase.gsub(' ', '')}-#{SecureRandom.hex(2).upcase}"
  lote = sala.lotes.find_or_initialize_by(codigo: codigo)
  return lote unless lote.new_record?
  lote.assign_attributes(attrs.merge(club: sala.club, genetica: genetica, plants_count: n_plantas))
  lote.save!
  state = STATE_MAP[attrs[:estado]] || 'vegetativo'
  n_plantas.times do |i|
    lote.plants.create!(
      nombre:   "#{lote.codigo}-P#{(i+1).to_s.rjust(3,'0')}",
      state:    state,
      genetica: genetica,
    )
  end
  lote.update_columns(plants_count: n_plantas)
  lote
end

# Sala vegetativo — lotes activos
lote_veg1 = crear_lote(sala_veg, {
  codigo: 'VEG-OGK-01', estado: 'vegetativo',
  start_date: 40.days.ago.to_date, grow_type: 'sustrato', light_type: 'led',
  notes: 'Primer lote OG Kush temporada 2026. Plantas con buen vigor.'
}, og_kush, 24)

lote_veg2 = crear_lote(sala_veg, {
  codigo: 'VEG-AND-02', estado: 'vegetativo',
  start_date: 22.days.ago.to_date, grow_type: 'sustrato', light_type: 'led',
  notes: 'ANANDA001 INASE. Monitoreo especial para REPROCANN.'
}, ananda, 18)

lote_veg3 = crear_lote(sala_veg, {
  codigo: 'VEG-BD-03', estado: 'semilla',
  start_date: 5.days.ago.to_date, grow_type: 'hidroponia', light_type: 'led',
  notes: 'Blue Dream en germinación. Sistema DWC.'
}, blue_dream, 12)

# Sala floración — listos para manicurar
lote_flor1 = crear_lote(sala_flor, {
  codigo: 'FLOR-POL-01', estado: 'floracion',
  start_date: 55.days.ago.to_date, grow_type: 'sustrato', light_type: 'hps',
  notes: 'POLARIS alto CBD. Semana 8 de floración. Casi lista para cosechar.'
}, polaris, 30)

lote_flor2 = crear_lote(sala_flor, {
  codigo: 'FLOR-HAR-02', estado: 'cosecha',
  start_date: 68.days.ago.to_date, grow_type: 'hidroponia', light_type: 'led',
  notes: 'Harlequin cosechada. Pendiente de manicura.'
}, harlequin, 8)

lote_flor3 = crear_lote(sala_flor, {
  codigo: 'FLOR-WW-03', estado: 'cosecha',
  start_date: 72.days.ago.to_date, grow_type: 'sustrato', light_type: 'hps',
  notes: 'White Widow cosechada. Esperando aprobación de pesaje.'
}, ww, 20)

# Sala curado
lote_cur1 = crear_lote(sala_curado, {
  codigo: 'CUR-NL-01', estado: 'curado',
  start_date: 90.days.ago.to_date, grow_type: 'sustrato', light_type: 'hps',
  notes: 'Northern Lights en curado. Semana 3. Aroma excepcional.'
}, nl, 15)

lote_cur2 = crear_lote(sala_curado, {
  codigo: 'CUR-CMC-02', estado: 'curado',
  start_date: 85.days.ago.to_date, grow_type: 'sustrato', light_type: 'led',
  notes: 'Critical Mass CBD curado. Lista para dispensar.'
}, cm_cbd, 10)

# Sala madres
lote_mad = crear_lote(sala_mad, {
  codigo: 'MAD-AMN-01', estado: 'vegetativo',
  start_date: 120.days.ago.to_date, grow_type: 'sustrato', light_type: 'led',
  notes: 'Amnesia Haze. Planta madre principal, excelente producción de esquejes.'
}, amnesia, 6)

puts "  ✅ #{Lote.count} lotes, #{Plant.count} plantas"

# ── Costos de lotes (algunos) ─────────────────────────────────
puts "\n💲 Costos de lotes..."
[
  [lote_flor2, { costo_insumos: 42000, costo_energia: 18500, costo_mano_obra: 35000, costo_prorrateado: 12000, gramos_producidos: 320.0 }],
  [lote_flor3, { costo_insumos: 68000, costo_energia: 31000, costo_mano_obra: 55000, costo_prorrateado: 18000, gramos_producidos: 780.0 }],
  [lote_cur1,  { costo_insumos: 51000, costo_energia: 22000, costo_mano_obra: 40000, costo_prorrateado: 14000, gramos_producidos: 560.0 }],
].each do |lote, attrs|
  next if lote.costo_lote.present?
  total = attrs.values_at(:costo_insumos, :costo_energia, :costo_mano_obra, :costo_prorrateado).sum
  gpg   = (total.to_f / attrs[:gramos_producidos]).round(2)
  lote.create_costo_lote!(attrs.merge(
    club: lote.club,
    costo_total: total,
    costo_por_gramo: gpg,
    calculado_at: Time.current,
    notas: 'Calculado al finalizar cosecha.'
  ))
end
puts "  ✅ Costos cargados"

# ── Inventario sede dispensario ───────────────────────────────
puts "\n📦 Inventario sede Devoto..."

def crear_stock(sede, club, user, genetica, producto, stock_g, precio, lote = nil)
  item = sede.inventarios.find_or_initialize_by(genetica: genetica)
  item.assign_attributes(
    club: club, created_by: user,
    producto: producto, stock_gramos: stock_g,
    stock_minimo: 50.0, precio_por_unidad: precio,
  )
  item.save!

  stock_inicial = stock_g
  mov_attrs = {
    sede: sede, club: club, sede_inventario: item,
    created_by: user, tipo: 'ingreso',
    cantidad: stock_g, stock_anterior: 0,
    stock_nuevo: stock_g, estado: 'aprobado',
    aprobado_por: user, aprobado_at: Time.current,
  }
  mov_attrs[:lote_id] = lote.id if lote
  mov_attrs[:motivo]  = lote ? "Cosecha lote #{lote.codigo}" : 'Ingreso inicial de stock'
  InventarioMovimiento.create!(mov_attrs)
  item
end

inv_nl  = crear_stock(sede_disp, club, admin, nl,       'flores', 850.0,  2200.0, lote_cur1)
inv_hrl = crear_stock(sede_disp, club, admin, harlequin,'flores', 420.0,  1800.0, lote_flor2)
inv_cmb = crear_stock(sede_disp, club, admin, cm_cbd,   'flores', 1200.0, 1600.0, lote_cur2)
inv_pol = crear_stock(sede_disp, club, admin, polaris,  'flores', 320.0,  2500.0)

# También en Pompeya (sede mixta)
inv_og  = crear_stock(sede_mixta, club, admin, og_kush, 'flores', 280.0, 2000.0)

puts "  ✅ #{SedeInventario.count} ítems de stock"

# ── Movimiento PENDIENTE del manicurador ─────────────────────
puts "\n⏳ Movimiento pendiente (manicurador)..."
# Simula que Valentina registró una cosecha y espera aprobación
item_ww = sede_disp.inventarios.find_or_initialize_by(genetica: ww)
item_ww.assign_attributes(club: club, created_by: admin, producto: 'flores', stock_gramos: 0, stock_minimo: 50, precio_por_unidad: 1900)
item_ww.save!

InventarioMovimiento.create!(
  sede:            sede_disp,
  club:            club,
  sede_inventario: item_ww,
  created_by:      manicurador,
  lote_id:         lote_flor3.id,
  tipo:            'ingreso',
  cantidad:        680.0,
  stock_anterior:  0,
  stock_nuevo:     0,
  estado:          'pendiente',
  motivo:          "Manicura — lote #{lote_flor3.codigo}",
)
puts "  ✅ Pendiente de aprobación: 680g White Widow (lote #{lote_flor3.codigo})"

# ── Socios / pacientes ───────────────────────────────────────
puts "\n👥 Socios y pacientes..."
HOY = Date.today

SOCIOS_DATA = [
  { nombre: 'María',     apellido: 'González',   dni: '28456789', fn: Date.new(1975,  3, 15), email: 'mgonzalez@email.com',  tel: '+54 9 11 2345-6789', rnum: 'REP-2024-00123', rvenc: HOY + 18.months, es_pac: true  },
  { nombre: 'Juan',      apellido: 'Martínez',   dni: '35123456', fn: Date.new(1988,  7, 22), email: 'jmartinez@email.com',  tel: '+54 9 11 3456-7890', rnum: 'REP-2024-00456', rvenc: HOY + 6.months,  es_pac: true  },
  { nombre: 'Laura',     apellido: 'Rodríguez',  dni: '31987654', fn: Date.new(1982, 11,  8), email: 'lrodriguez@email.com', tel: '+54 9 11 4567-8901', rnum: 'REP-2023-00789', rvenc: HOY - 15.days,   es_pac: true  },
  { nombre: 'Carlos',    apellido: 'Fernández',  dni: '25678901', fn: Date.new(1968,  5, 30), email: 'cfernandez@email.com', tel: '+54 9 11 5678-9012', rnum: 'REP-2024-00234', rvenc: HOY + 24.months, es_pac: true  },
  { nombre: 'Sofía',     apellido: 'López',      dni: '40234567', fn: Date.new(1995,  9, 14), email: 'slopez@email.com',     tel: '+54 9 11 6789-0123', rnum: nil,              rvenc: nil,             es_pac: false },
  { nombre: 'Roberto',   apellido: 'Díaz',       dni: '22345678', fn: Date.new(1960,  2, 28), email: 'rdiaz@email.com',      tel: '+54 9 11 7890-1234', rnum: 'REP-2024-00567', rvenc: HOY + 20.days,   es_pac: true  },
  { nombre: 'Patricia',  apellido: 'Suárez',     dni: '33456789', fn: Date.new(1985, 12,  3), email: 'psuarez@email.com',    tel: '+54 9 11 8901-2345', rnum: 'REP-2023-00890', rvenc: HOY - 45.days,   es_pac: true  },
  { nombre: 'Alejandro', apellido: 'Ruiz',       dni: '38567890', fn: Date.new(1991,  6, 19), email: 'aruiz@email.com',      tel: '+54 9 11 9012-3456', rnum: 'REP-2024-00678', rvenc: HOY + 30.months, es_pac: true  },
  { nombre: 'Valeria',   apellido: 'Pereira',    dni: '42001234', fn: Date.new(1998,  4,  5), email: 'vpereira@email.com',   tel: '+54 9 11 1234-5678', rnum: 'REP-2025-00901', rvenc: HOY + 36.months, es_pac: true  },
  { nombre: 'Néstor',    apellido: 'Cáceres',    dni: '18765432', fn: Date.new(1955,  8, 12), email: 'ncaceres@email.com',   tel: '+54 9 11 9876-5432', rnum: 'REP-2024-00345', rvenc: HOY + 12.months, es_pac: true  },
].freeze

socios = SOCIOS_DATA.map do |p|
  dni_norm = p[:dni].gsub(/\D/, '')
  socio = club.socios.find_or_initialize_by(dni_normalizado: dni_norm)
  socio.assign_attributes(
    nombre: p[:nombre], apellido: p[:apellido], dni: p[:dni],
    fecha_nacimiento: p[:fn], email: p[:email], telefono: p[:tel],
    reprocann_numero: p[:rnum], reprocann_vencimiento: p[:rvenc],
    es_paciente: p[:es_pac], created_by: medico,
  )
  socio.save!
  socio
end
puts "  ✅ #{club.socios.count} socios"

# ── Indicaciones médicas ──────────────────────────────────────
puts "\n💊 Indicaciones médicas..."
socios_pacientes = socios.select { |s| s.es_paciente? }.first(6)
PATOLOGIAS = ['Epilepsia refractaria', 'Dolor crónico', 'Ansiedad severa', 'Insomnio crónico', 'Esclerosis múltiple', 'PTSD'].freeze
VIAS       = ['oral', 'inhalada', 'sublingual', 'topica'].freeze

indicaciones = socios_pacientes.map.with_index do |socio, i|
  IndicacionMedica.create!(
    socio:              socio,
    user:               medico,
    patologia:          PATOLOGIAS[i % PATOLOGIAS.size],
    dosificacion:       "#{[10, 15, 20, 25][i % 4]}mg CBD / #{[5, 8, 12, 0][i % 4]}mg THC — 2 veces al día",
    via_administracion: VIAS[i % VIAS.size],
    fecha_emision:      (90 - i * 10).days.ago.to_date,
    fecha_vencimiento:  (365 - i * 10).days.from_now.to_date,
    activa:             true,
    duracion_dias:      365,
  )
end
puts "  ✅ #{IndicacionMedica.count} indicaciones"

# ── Dispensaciones ───────────────────────────────────────────
puts "\n💊 Dispensaciones..."
inventarios_disponibles = [inv_nl, inv_hrl, inv_cmb, inv_pol]

socios_pacientes.first(5).each_with_index do |socio, si|
  inv = inventarios_disponibles[si % inventarios_disponibles.size]
  ind = indicaciones[si]
  next unless inv && ind && inv.stock_gramos > 10

  cantidad = [15.0, 20.0, 25.0, 30.0, 10.0][si % 5]
  descuento = [0, 10, 15, 0, 20][si % 5].to_f
  factor   = 1.0 - descuento / 100.0
  costo_pg = inv.precio_por_unidad.to_f / 1000.0
  aporte   = (cantidad * costo_pg * factor).round(2)

  disp = Dispensacion.create!(
    socio:                socio,
    sede:                 sede_disp,
    user:                 dispensador,
    sede_inventario:      inv,
    cantidad_gramos:      cantidad,
    tipo_producto:        inv.producto,
    fecha_dispensacion:   (30 - si * 5).days.ago.to_date,
    observaciones:        'Entregado sin novedad.',
    porcentaje_descuento: descuento > 0 ? descuento : nil,
    aporte_socio_ars:     aporte,
    costo_por_gramo:      costo_pg,
    costo_total_calculado: (cantidad * costo_pg).round(2),
  )

  inv.stock_gramos = (inv.stock_gramos - cantidad).round(2)
  inv.save!
  InventarioMovimiento.create!(
    sede: sede_disp, club: club, sede_inventario: inv,
    created_by: dispensador, dispensacion: disp,
    tipo: 'egreso_dispensacion', cantidad: cantidad,
    stock_anterior: inv.stock_gramos + cantidad,
    stock_nuevo: inv.stock_gramos, estado: 'aprobado',
    aprobado_por: dispensador, aprobado_at: Time.current,
    motivo: "Dispensación a #{socio.nombre} #{socio.apellido}",
  )
  puts "  💊 #{socio.nombre} #{socio.apellido} — #{cantidad}g #{inv.genetica&.nombre}"
end

# ── Movimientos contables ─────────────────────────────────────
puts "\n💰 Movimientos contables..."
[
  { tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Febrero 2026',  monto_ars: 780000, fecha: 60.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Marzo 2026',    monto_ars: 850000, fecha: 30.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Abril 2026',    monto_ars: 920000, fecha: 2.days.ago.to_date,   pagado: true, medio_pago: 'transferencia' },
  { tipo: 'ingreso', categoria: 'subvencion',    descripcion: 'Donación socio benefactor',      monto_ars: 200000, fecha: 10.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'alquiler',      descripcion: 'Alquiler sede Avellaneda - Abr', monto_ars: 420000, fecha: 5.days.ago.to_date,   pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'alquiler',      descripcion: 'Alquiler sede Devoto - Abr',     monto_ars: 340000, fecha: 5.days.ago.to_date,   pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'electricidad',  descripcion: 'Factura eléctrica Marzo',        monto_ars: 108000, fecha: 25.days.ago.to_date,  pagado: true, medio_pago: 'debito'        },
  { tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Sustrato premium 60 bolsas',     monto_ars: 245000, fecha: 40.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Nutrientes Canna Coco A+B 10L',  monto_ars: 89000,  fecha: 35.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Macetas Air-Pot 11L x 80u',      monto_ars: 68000,  fecha: 45.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'honorario',     descripcion: 'Honorarios médico - Marzo',       monto_ars: 280000, fecha: 28.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'sueldo',        descripcion: 'Sueldo cultivador - Marzo',       monto_ars: 395000, fecha: 28.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'sueldo',        descripcion: 'Sueldo manicurador - Marzo',      monto_ars: 320000, fecha: 28.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { tipo: 'egreso',  categoria: 'mantenimiento', descripcion: 'Reemplazo lámparas HPS x4',       monto_ars: 186000, fecha: 20.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Carbono activo filtros',           monto_ars: 42000,  fecha: 15.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { tipo: 'egreso',  categoria: 'electricidad',  descripcion: 'Factura eléctrica Abril',          monto_ars: 121000, fecha: 3.days.ago.to_date,   pagado: false, medio_pago: nil            },
  { tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Bolsas de curado 3.5L x 200u',    monto_ars: 35000,  fecha: 8.days.ago.to_date,   pagado: true, medio_pago: 'efectivo'      },
].each { |m| club.movimientos_contables.create!(m.merge(created_by: admin)) }
puts "  ✅ #{club.movimientos_contables.count} movimientos"

# ── Noticias ─────────────────────────────────────────────────
puts "\n📰 Noticias..."
[
  { titulo: 'Cosecha POLARIS disponible — alto CBD',
    contenido: 'Informamos que nuestra cosecha de POLARIS (INASE) está disponible para dispensación. CBD 12%, THC <0.3%. Ideal para tratamientos neurológicos y dolor crónico.',
    publicada: true, publicada_at: 3.days.ago },
  { titulo: 'Taller: Introducción al cultivo medicinal',
    contenido: 'El próximo mes realizaremos un taller gratuito para socios. Aprenderás sobre fotoperiodo, nutrición y control ambiental. Cupos limitados — inscribite en la recepción.',
    publicada: true, publicada_at: 7.days.ago },
  { titulo: 'Renovación de autorizaciones REPROCANN',
    contenido: 'Las autorizaciones REPROCANN tienen vigencia de 3 años. Consulten con el equipo médico con al menos 60 días de anticipación para gestionar la renovación sin interrupciones.',
    publicada: true, publicada_at: 14.days.ago },
  { titulo: 'Nueva sala de curado habilitada en Pompeya',
    contenido: 'Habilitamos la Sala Curado en sede Pompeya. Capacidad para 200kg por ciclo, control de HR y temperatura automatizado.',
    publicada: true, publicada_at: 21.days.ago },
].each { |n| club.noticias.find_or_create_by!(titulo: n[:titulo]) { |x| x.assign_attributes(n) } }
puts "  ✅ #{club.noticias.count} noticias"

# ── Eventos ──────────────────────────────────────────────────
puts "\n📅 Eventos..."
[
  { titulo: 'Charla: Cannabis medicinal y REPROCANN 2025',
    descripcion: 'Conversatorio sobre los cambios normativos y cómo afecta a los usuarios del programa. Entrada libre para socios.',
    fecha_inicio: 10.days.from_now.change(hour: 19), fecha_fin: 10.days.from_now.change(hour: 21),
    lugar: 'Sede Devoto', activo: true },
  { titulo: 'Taller de extracción de aceites medicinales',
    descripcion: 'Técnicas seguras de extracción CO2/etanol con demostración práctica. Incluye degustación de productos finales.',
    fecha_inicio: 20.days.from_now.change(hour: 18), fecha_fin: 20.days.from_now.change(hour: 21),
    lugar: 'Sede Avellaneda', activo: true },
  { titulo: 'Asamblea anual de socios',
    descripcion: 'Presentación del balance anual, elección de autoridades y aprobación del plan de expansión 2027.',
    fecha_inicio: 35.days.from_now.change(hour: 17), fecha_fin: 35.days.from_now.change(hour: 20),
    lugar: 'Sede Devoto', activo: true },
].each { |e| club.eventos.find_or_create_by!(titulo: e[:titulo]) { |x| x.assign_attributes(e) } }
puts "  ✅ #{club.eventos.count} eventos"

# ── Resumen ──────────────────────────────────────────────────
puts "\n" + "="*60
puts "🎉 Seeds completados!"
puts "="*60
puts ""
puts "📧 Credenciales — password: 123456Aa"
puts "  super_admin  : super@clubcultivo.app"
puts "  admin        : admin@mitocondriaclub.org"
puts "  médico       : medico@mitocondriaclub.org"
puts "  agricultor   : agricultor@mitocondriaclub.org"
puts "  cultivador   : cultivador@mitocondriaclub.org"
puts "  manicurador  : manicura@mitocondriaclub.org"
puts "  dispensador  : dispensa@mitocondriaclub.org"
puts "  tesorero     : tesorero@mitocondriaclub.org"
puts "  abogado      : abogado@mitocondriaclub.org"
puts "  auditor      : auditor@mitocondriaclub.org"
puts "  socio        : socio@mitocondriaclub.org"
puts ""
puts "📊 Dataset:"
puts "  🧬 Genéticas : #{club.geneticas.count} (#{club.geneticas.where(registrada_inase: true).count} INASE)"
puts "  👥 Socios    : #{club.socios.count} (#{club.socios.where(es_paciente: true).count} pacientes)"
puts "  🏢 Sedes     : #{club.sedes.count}"
puts "  🏗️  Salas    : #{club.salas.count}"
puts "  📦 Lotes     : #{club.lotes.count}"
puts "  🪴 Plantas   : #{Plant.joins(:lote).where(lotes: { club_id: club.id }).count}"
puts "  📦 Stock     : #{SedeInventario.where(club: club).count} ítems, #{InventarioMovimiento.where(club: club, estado: 'pendiente').count} pendientes"
puts "  💊 Dispens.  : #{Dispensacion.joins(:sede).where(sedes: { club_id: club.id }).count}"
puts "  💰 Contabl.  : #{club.movimientos_contables.count}"
puts ""
