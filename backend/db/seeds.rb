# ============================================================
# SEEDS — Cultivo Espacial · Dataset completo para testing UI/UX
# ============================================================
puts "🌱 Iniciando seeds..."

# ── Super Admin ──────────────────────────────────────────────
puts "\n👤 Super admin..."
sa = User.find_or_initialize_by(email: 'super@clubcultivo.app')
sa.assign_attributes(password: '123456Aa', role: 'super_admin', first_name: 'Super', last_name: 'Admin')
sa.club_id = nil
sa.save!(validate: false)
puts "  ✅ #{sa.email}"

sa2 = User.find_or_initialize_by(email: 'super@cultivoespacial.com')
sa2.assign_attributes(password: '123456Aa', role: 'super_admin', first_name: 'Cultivo', last_name: 'Espacial')
sa2.club_id = nil
sa2.save!(validate: false)
puts "  ✅ #{sa2.email}"

sa3 = User.find_or_initialize_by(email: 'german.laino@gmail.com')
sa3.assign_attributes(password: '123456Aa', role: 'super_admin', first_name: 'German', last_name: 'Laino')
sa3.club_id = nil
sa3.save!(validate: false)
puts "  ✅ #{sa3.email}"

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
cultivador = crear_user(club, email: 'cultivador@mitocondriaclub.org', role: 'cultivador', first_name: 'Diego',    last_name: 'Fernández')
manicurador= crear_user(club, email: 'manicura@mitocondriaclub.org',   role: 'manicura',   first_name: 'Valentina',last_name: 'Reyes')
dispensador= crear_user(club, email: 'dispensa@mitocondriaclub.org',   role: 'dispensador',first_name: 'Lucía',    last_name: 'Bianchi')
abogado    = crear_user(club, email: 'abogado@mitocondriaclub.org',    role: 'abogado',    first_name: 'Claudia',  last_name: 'Torres')
auditor    = crear_user(club, email: 'auditor@mitocondriaclub.org',    role: 'auditor',    first_name: 'Roberto',  last_name: 'Sánchez')
paciente_user = crear_user(club, email: 'paciente@mitocondriaclub.org', role: 'paciente',  first_name: 'Marcos',   last_name: 'Villalba')
delivery_user = crear_user(club, email: 'delivery@mitocondriaclub.org', role: 'delivery',  first_name: 'Tomás',    last_name: 'Pereyra')

# Super admins adicionales (sin club)
[
  { email: 'superadmin@cultivoespacial.app', first_name: 'Super',    last_name: 'Admin' },
  { email: 'super@cultivoespacial.com',      first_name: 'Platform', last_name: 'Admin' },
].each do |attrs|
  sa2 = User.find_or_initialize_by(email: attrs[:email])
  sa2.assign_attributes(attrs.merge(password: '123456Aa', role: 'super_admin'))
  sa2.club_id = nil
  sa2.save!(validate: false)
  puts "  ✅ #{sa2.email}"
end

# Migrar agricultor existente a cultivador si aún existe
User.where(email: 'agricultor@mitocondriaclub.org').update_all(role: 'cultivador') rescue nil
# Renombrar email zombie tesorero → admin2 (idempotente: solo actúa si admin2 aún no existe)
if (zombie = User.find_by(email: 'tesorero@mitocondriaclub.org')) && User.find_by(email: 'admin2@mitocondriaclub.org').nil?
  zombie.update!(email: 'admin2@mitocondriaclub.org', first_name: 'Hernán', last_name: 'Vidal', role: 'admin')
end

puts "  ✅ Usuarios creados/actualizados"

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
  next if Genetica.exists?(nombre: g[:nombre])
  club.geneticas.create!(g)
end
puts "  ✅ #{Genetica.count} genéticas (#{Genetica.where(global: true).count} globales)"

# referencias — buscar globalmente en caso de que la migración las haya convertido a global
og_kush    = Genetica.find_by!(nombre: 'OG Kush')
harlequin  = Genetica.find_by!(nombre: 'Harlequin')
nl         = Genetica.find_by!(nombre: 'Northern Lights')
ww         = Genetica.find_by!(nombre: 'White Widow')
cm_cbd     = Genetica.find_by!(nombre: 'Critical Mass CBD')
amnesia    = Genetica.find_by!(nombre: 'Amnesia Haze')
blue_dream = Genetica.find_by!(nombre: 'Blue Dream')
polaris    = Genetica.find_by(nombre: 'POLARIS',   global: true) || og_kush
ananda     = Genetica.find_by(nombre: 'ANANDA001', global: true) || harlequin

# ── Enriquecer genéticas con descripción, terpenos, criador ──
ENRICH_GENETICAS = [
  {
    nombre: 'OG Kush',
    criador: 'Triangle Genetics',
    terpenos: 'Mirceno, Limoneno, Cariofileno',
    descripcion: 'Una de las variedades más emblemáticas de la costa oeste de EEUU. ' \
      'Aroma terroso con notas de pino y limón. Efectos relajantes y eufóricos, muy valorada ' \
      'tanto recreativamente como para el manejo del dolor crónico y el estrés.',
  },
  {
    nombre: 'White Widow',
    criador: 'Green House Seeds',
    terpenos: 'Mirceno, Cariofileno, Pineno',
    descripcion: 'Clásico holandés de altísima resina. Aroma a tierra y madera con un toque especiado. ' \
      'Efecto equilibrado entre físico y mental, ideal para usuarios con experiencia moderada. ' \
      'Ganadora de la Copa del Mundo de Cannabis 1995.',
  },
  {
    nombre: 'Northern Lights',
    criador: 'Sensi Seeds',
    terpenos: 'Mirceno, Cariofileno, Linalool',
    descripcion: 'Índica pura de efecto sedante y profundamente relajante. Aroma dulce a tierra con notas ' \
      'de pino y madera. Ciclo de floración corto y rendimiento generoso, considerada un estándar ' \
      'del cultivo indoor por su estabilidad genética.',
  },
  {
    nombre: 'Harlequin',
    criador: 'Unknown / Tradición',
    terpenos: 'Mirceno, Pineno, Cariofileno',
    descripcion: 'Variedad sativa de alto CBD con ratio equilibrado THC:CBD. Efecto claro y funcional ' \
      'sin intoxicación pronunciada. Ampliamente utilizada en clubes terapéuticos para pacientes ' \
      'que buscan alivio sin deterioro cognitivo.',
  },
  {
    nombre: 'Critical Mass CBD',
    criador: 'CBD Crew',
    terpenos: 'Mirceno, Limoneno, Pineno',
    descripcion: 'Cruce terapéutico de alto CBD y bajo THC. Plantas compactas y de alta producción. ' \
      'Muy utilizada en programas medicinales por sus propiedades antiinflamatorias y ansiolíticas ' \
      'sin efecto psicoactivo significativo.',
  },
  {
    nombre: 'Amnesia Haze',
    criador: 'Soma Seeds',
    terpenos: 'Terpinoleno, Mirceno, Ocimeno',
    descripcion: 'Sativa de larga floración con efectos cerebrales potentes y euforizantes. Aroma cítrico ' \
      'e intenso con notas terrosas y especiadas. Favorita entre cultivadores experimentados por su ' \
      'potencia, producción y calidad organoléptica excepcional.',
  },
  {
    nombre: 'Blue Dream',
    criador: 'DJ Short',
    terpenos: 'Mirceno, Pineno, Cariofileno',
    descripcion: 'Híbrida equilibrada con característico aroma a arándano y vainilla. Efectos creativos ' \
      'y relajantes a la vez. Una de las variedades más populares de California por su versatilidad ' \
      'y rendimiento sólido tanto en cultivos indoor como outdoor.',
  },
].freeze

ENRICH_GENETICAS.each do |attrs|
  gen = Genetica.find_by(nombre: attrs[:nombre])
  next unless gen
  updates = {}
  updates[:criador]     = attrs[:criador]     if gen.criador.blank?
  updates[:terpenos]    = attrs[:terpenos]    if gen.terpenos.blank?
  updates[:descripcion] = attrs[:descripcion] if gen.descripcion.blank?
  gen.update!(updates) unless updates.empty?
end
puts "  ✅ Genéticas enriquecidas (descripciones, terpenos, criadores)"

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
  s.state = 'activa'; s.kind = 'vegetativo'; s.tipo = 'vegetativo'; s.pots_count = 80; s.plants_max = 80
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'LED 18/6, temperatura 22-26°C, humedad 65-70%.'
end
sala_veg.update_columns(tipo: 'vegetativo') if sala_veg.tipo.blank? || sala_veg.tipo == 'cultivo'

sala_flor = club.salas.find_or_create_by!(nombre: 'Sala Floración') do |s|
  s.state = 'activa'; s.kind = 'floracion'; s.tipo = 'floracion'; s.pots_count = 50; s.plants_max = 50
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'HPS 600W 12/12, humedad 45-55%, extracción forzada.'
end
sala_flor.update_columns(tipo: 'floracion') if sala_flor.tipo.blank? || sala_flor.tipo == 'cultivo'

sala_mad = club.salas.find_or_create_by!(nombre: 'Sala Madres') do |s|
  s.state = 'activa'; s.kind = 'madre'; s.tipo = 'madre'; s.pots_count = 20; s.plants_max = 20
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'Madres y esquejes, luz 18/6 permanente.'
end
sala_mad.update_columns(tipo: 'madre') if sala_mad.tipo.blank? || sala_mad.tipo == 'cultivo'

# Sala de curado (tipo: curado para el ciclo nuevo)
sala_curado = club.salas.find_or_create_by!(nombre: 'Sala Curado') do |s|
  s.state = 'activa'; s.kind = 'curado'; s.tipo = 'curado'; s.pots_count = 0; s.plants_max = 0
  s.sede = sede_mixta; s.created_by = admin
  s.notes = 'Curado en oscuridad, HR 58-62%, temp 18°C.'
end
sala_curado.update_columns(tipo: 'curado', kind: 'curado') if sala_curado.tipo != 'curado'

sala_cosecha = club.salas.find_or_create_by!(nombre: 'Sala Cosecha') do |s|
  s.state = 'activa'; s.kind = 'cosechado'; s.tipo = 'cosecha'; s.pots_count = 50; s.plants_max = 50
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'Colgado y cosecha fresca. Oscuridad total primeras 48h.'
end
sala_cosecha.update_columns(tipo: 'cosecha', kind: 'cosechado') if sala_cosecha.tipo != 'cosecha'

sala_secado = club.salas.find_or_create_by!(nombre: 'Sala Secado') do |s|
  s.state = 'activa'; s.kind = 'secado'; s.tipo = 'secado'; s.pots_count = 0; s.plants_max = 0
  s.sede = sede_prod; s.created_by = admin
  s.notes = 'Oscuridad total. HR 55-60%, temp 18-20°C. Secado 10-14 días.'
end
sala_secado.update_columns(tipo: 'secado', kind: 'secado') if sala_secado.tipo != 'secado'

puts "  ✅ #{[sala_veg, sala_flor, sala_mad, sala_cosecha, sala_secado, sala_curado].map(&:nombre).join(', ')}"

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
  lote = Lote.find_or_initialize_by(codigo: codigo, club_id: sala.club_id)
  return lote unless lote.new_record?
  lote.assign_attributes(attrs.merge(club: sala.club, sala: sala, genetica: genetica, plants_count: n_plantas))
  lote.save!
  state = STATE_MAP[attrs[:estado]] || 'vegetativo'
  n_plantas.times do |i|
    lote.plants.create!(
      nombre: "#{lote.codigo}-P#{(i+1).to_s.rjust(3,'0')}",
      state:  state,
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

# ── Stock disponible (nuevo modelo) ──────────────────────────
puts "\n📦 Stock disponible..."

stock_nl  = Stock.find_or_create_by!(lote: lote_cur1,  origen: 'lote', forma_producto: 'flor_seca') do |s|
  s.sede = sede_disp; s.unidad = 'g'; s.cantidad = 850.0
  s.costo_unitario_ars = 2000.0; s.precio_sugerido_ars = 2200.0
end
stock_hrl = Stock.find_or_create_by!(lote: lote_flor2, origen: 'lote', forma_producto: 'flor_seca') do |s|
  s.sede = sede_disp; s.unidad = 'g'; s.cantidad = 420.0
  s.costo_unitario_ars = 1500.0; s.precio_sugerido_ars = 1800.0
end
stock_cmb = Stock.find_or_create_by!(lote: lote_cur2,  origen: 'lote', forma_producto: 'flor_seca') do |s|
  s.sede = sede_disp; s.unidad = 'g'; s.cantidad = 1200.0
  s.costo_unitario_ars = 1400.0; s.precio_sugerido_ars = 1600.0
end
stock_pol = Stock.find_or_create_by!(lote: lote_flor1, origen: 'lote', forma_producto: 'flor_seca') do |s|
  s.sede = sede_disp; s.unidad = 'g'; s.cantidad = 320.0
  s.costo_unitario_ars = 2200.0; s.precio_sugerido_ars = 2500.0
end
puts "  ✅ #{Stock.count} ítems de stock"

# ── Demo ciclo productivo ─────────────────────────────────────
puts "\n🔄 Demo ciclo productivo (5 lotes en estados distintos)..."

# 1 — vegetativo (sin transiciones)
lote_ciclo_veg = club.lotes.find_or_initialize_by(codigo: 'CIC-VEG-001')
if lote_ciclo_veg.new_record?
  lote_ciclo_veg.assign_attributes(
    sala: sala_veg, estado: 'vegetativo', genetica: og_kush,
    start_date: 15.days.ago.to_date, grow_type: 'sustrato', light_type: 'led',
    plants_count: 10, notes: 'Demo ciclo — vegetativo',
  )
  lote_ciclo_veg.save!
  10.times { |i| lote_ciclo_veg.plants.create!(nombre: "CIC-VEG-001-P#{(i+1).to_s.rjust(3,'0')}", state: 'vegetativo') }
  lote_ciclo_veg.update_columns(plants_count: 10)
  puts "    ✅ #{lote_ciclo_veg.codigo}: vegetativo"
end

# 2 — floración (1 pesada veg→flor)
lote_ciclo_flor = club.lotes.find_or_initialize_by(codigo: 'CIC-FLOR-001')
if lote_ciclo_flor.new_record?
  lote_ciclo_flor.assign_attributes(
    sala: sala_veg, estado: 'vegetativo', genetica: blue_dream,
    start_date: 45.days.ago.to_date, grow_type: 'sustrato', light_type: 'hps',
    plants_count: 16, notes: 'Demo ciclo — floración',
  )
  lote_ciclo_flor.save!
  16.times { |i| lote_ciclo_flor.plants.create!(nombre: "CIC-FLOR-001-P#{(i+1).to_s.rjust(3,'0')}", state: 'vegetativo') }
  lote_ciclo_flor.update_columns(plants_count: 16)
  lote_ciclo_flor.transicionar!('floracion', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 3200.0,
    notas: 'Inicio floración. 3.2kg biomasa húmeda.',
  })
  puts "    ✅ #{lote_ciclo_flor.codigo}: floracion (#{lote_ciclo_flor.pesadas.count} pesadas)"
end

# 3 — secado (3 pesadas: veg→flor, flor→cosecha, cosecha→secado)
lote_ciclo_sec = club.lotes.find_or_initialize_by(codigo: 'CIC-SEC-001')
if lote_ciclo_sec.new_record?
  lote_ciclo_sec.assign_attributes(
    sala: sala_veg, estado: 'vegetativo', genetica: harlequin,
    start_date: 65.days.ago.to_date, grow_type: 'hidroponia', light_type: 'led',
    plants_count: 12, notes: 'Demo ciclo — secado',
  )
  lote_ciclo_sec.save!
  12.times { |i| lote_ciclo_sec.plants.create!(nombre: "CIC-SEC-001-P#{(i+1).to_s.rjust(3,'0')}", state: 'vegetativo') }
  lote_ciclo_sec.update_columns(plants_count: 12)
  lote_ciclo_sec.transicionar!('floracion', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 4100.0,
  })
  lote_ciclo_sec.transicionar!('cosecha', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 5800.0,
    notas: 'Cosecha. 5.8kg húmedo. Manicura completada.',
  }, manicurado: true)
  lote_ciclo_sec.transicionar!('secado', pesada_attrs: {
    registrado_por: manicurador, peso_seco_g: 1100.0,
    notas: 'Iniciando secado.',
  })
  puts "    ✅ #{lote_ciclo_sec.codigo}: secado (#{lote_ciclo_sec.pesadas.count} pesadas)"
end

# 4 — curado (4 pesadas: veg→flor, flor→cosecha, cosecha→secado, secado→curado)
lote_ciclo_cur = club.lotes.find_or_initialize_by(codigo: 'CIC-CUR-001')
if lote_ciclo_cur.new_record?
  lote_ciclo_cur.assign_attributes(
    sala: sala_veg, estado: 'vegetativo', genetica: polaris,
    start_date: 85.days.ago.to_date, grow_type: 'sustrato', light_type: 'hps',
    plants_count: 20, notes: 'Demo ciclo — curado',
  )
  lote_ciclo_cur.save!
  20.times { |i| lote_ciclo_cur.plants.create!(nombre: "CIC-CUR-001-P#{(i+1).to_s.rjust(3,'0')}", state: 'vegetativo') }
  lote_ciclo_cur.update_columns(plants_count: 20)
  lote_ciclo_cur.transicionar!('floracion', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 6200.0,
  })
  lote_ciclo_cur.transicionar!('cosecha', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 8400.0,
    notas: 'Cosecha óptima. 8.4kg húmedo.',
  }, manicurado: true)
  lote_ciclo_cur.transicionar!('secado', pesada_attrs: {
    registrado_por: manicurador, peso_seco_g: 1850.0,
    notas: 'Secado 10 días. 1.85kg seco.',
  })
  lote_ciclo_cur.transicionar!('curado', pesada_attrs: {
    registrado_por: manicurador, peso_seco_g: 1850.0, peso_curado_g: 1680.0,
    notas: 'Iniciando curado.',
  }, manicurado: true)
  puts "    ✅ #{lote_ciclo_cur.codigo}: curado (#{lote_ciclo_cur.pesadas.count} pesadas)"
end

# 5 — finalizado (ciclo completo + stock flor_seca + derivado hash + 3 plants es_seleccion)
lote_ciclo_fin = club.lotes.find_or_initialize_by(codigo: 'CIC-FIN-001')
if lote_ciclo_fin.new_record?
  lote_ciclo_fin.assign_attributes(
    sala: sala_veg, estado: 'vegetativo', genetica: nl,
    start_date: 130.days.ago.to_date, grow_type: 'sustrato', light_type: 'hps',
    plants_count: 8, notes: 'Demo ciclo — finalizado con stock',
  )
  lote_ciclo_fin.save!
  plantas_fin = 8.times.map do |i|
    lote_ciclo_fin.plants.create!(
      nombre: "CIC-FIN-001-P#{(i+1).to_s.rjust(3,'0')}",
      state: 'vegetativo', es_seleccion: i < 3,
    )
  end
  lote_ciclo_fin.update_columns(plants_count: 8)

  lote_ciclo_fin.transicionar!('floracion', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 2600.0,
  })
  lote_ciclo_fin.transicionar!('cosecha', pesada_attrs: {
    registrado_por: cultivador, peso_humedo_g: 4200.0,
    notas: 'Fenotipos A/B/C seleccionados con pesos destacados.',
  }, manicurado: true, pesadas_plantas_attrs: [
    { plant_id: plantas_fin[0].id, peso_humedo_g: 640.0 },
    { plant_id: plantas_fin[1].id, peso_humedo_g: 590.0 },
    { plant_id: plantas_fin[2].id, peso_humedo_g: 520.0 },
  ])
  lote_ciclo_fin.transicionar!('secado', pesada_attrs: {
    registrado_por: manicurador, peso_seco_g: 920.0,
    notas: '10 días secado. 920g seco.',
  })
  lote_ciclo_fin.transicionar!('curado', pesada_attrs: {
    registrado_por: manicurador, peso_seco_g: 920.0, peso_curado_g: 800.0,
    notas: 'Iniciando curado en frascos.',
  }, manicurado: true)

  stock_ciclo_gen = lote_ciclo_fin.cerrar_curado!(
    splitter:            { flor_seca: 680.0, descarte: 120.0 },
    sede_destino_id:     sede_disp.id,
    costo_unitario_ars:  1800.0,
    precio_sugerido_ars: 2100.0,
    registrado_por:      admin,
  )

  Stock.create!(
    sede:                    sede_disp,
    lote:                    lote_ciclo_fin,
    origen:                  'derivado_lote',
    forma_producto:          'hash',
    unidad:                  'g',
    cantidad:                40.0,
    lote_origen_consumido_g: 200.0,
    costo_unitario_ars:      12_000.0,
    precio_sugerido_ars:     15_000.0,
    descripcion:             'Hash prensado en frío — Northern Lights CIC-FIN-001',
  )
  puts "    ✅ #{lote_ciclo_fin.codigo}: finalizado — flor: #{stock_ciclo_gen.cantidad}g, hash: 40g"
end

puts "  ✅ Demo ciclo completo: #{Stock.count} stocks totales"

# ── Socios / pacientes ───────────────────────────────────────
puts "\n👥 Socios y pacientes..."
HOY = Date.today

PACIENTES_DATA = [
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

pacientes = PACIENTES_DATA.map do |p|
  dni_norm = p[:dni].gsub(/\D/, '')
  paciente = club.pacientes.find_or_initialize_by(dni_normalizado: dni_norm)
  paciente.assign_attributes(
    nombre: p[:nombre], apellido: p[:apellido], dni: p[:dni],
    fecha_nacimiento: p[:fn], email: p[:email], telefono: p[:tel],
    reprocann_numero: p[:rnum], reprocann_vencimiento: p[:rvenc],
    es_paciente: p[:es_pac], created_by: medico,
  )
  paciente.save!
  paciente
end
puts "  ✅ #{club.pacientes.count} pacientes"

# ── Cuentas corrientes ────────────────────────────────────────
puts "\n💳 Cuentas corrientes..."
pacientes.each do |paciente|
  CuentaCorriente.find_or_create_by!(paciente: paciente) do |cc|
    cc.club = club; cc.limite_credito = 200_000.0; cc.saldo_disponible = 150_000.0
  end
end
puts "  ✅ #{CuentaCorriente.count} cuentas corrientes"

# ── Indicaciones médicas ──────────────────────────────────────
puts "\n💊 Indicaciones médicas..."
pacientes_con_indicacion = pacientes.select { |s| s.es_paciente? }.first(6)
PATOLOGIAS = ['Epilepsia refractaria', 'Dolor crónico', 'Ansiedad severa', 'Insomnio crónico', 'Esclerosis múltiple', 'PTSD'].freeze
VIAS       = ['oral', 'inhalada', 'sublingual', 'topica'].freeze

indicaciones = pacientes_con_indicacion.map.with_index do |paciente, i|
  ind = IndicacionMedica.find_or_initialize_by(paciente: paciente, patologia: PATOLOGIAS[i % PATOLOGIAS.size])
  ind.assign_attributes(
    user:               medico,
    dosificacion:       "#{[10, 15, 20, 25][i % 4]}mg CBD / #{[5, 8, 12, 0][i % 4]}mg THC — 2 veces al día",
    via_administracion: VIAS[i % VIAS.size],
    fecha_emision:      (90 - i * 10).days.ago.to_date,
    fecha_vencimiento:  (365 - i * 10).days.from_now.to_date,
    activa:             true,
    duracion_dias:      365,
  )
  ind.save!
  ind
end
puts "  ✅ #{IndicacionMedica.count} indicaciones"

# ── Dispensaciones ───────────────────────────────────────────
puts "\n💊 Dispensaciones..."
stock_ciclo_flor = Stock.find_by(lote: lote_ciclo_fin, forma_producto: 'flor_seca', origen: 'lote')
stocks_disponibles = [stock_nl, stock_hrl, stock_cmb, stock_pol, stock_ciclo_flor].compact

pacientes_con_indicacion.first(5).each_with_index do |socio, si|
  stock = stocks_disponibles[si % stocks_disponibles.size]
  ind   = indicaciones[si]
  next unless stock && ind

  fecha = (30 - si * 5).days.ago.to_date
  next if Dispensacion.del_paciente(socio.id).where(fecha_dispensacion: fecha).exists?

  stock.reload
  next unless stock.cantidad > 10

  cantidad  = [15.0, 20.0, 25.0, 30.0, 10.0][si % 5]
  descuento = [0, 10, 15, 0, 20][si % 5].to_f
  factor    = 1.0 - descuento / 100.0
  precio_pg = stock.precio_sugerido_ars.to_f
  aporte    = (cantidad * precio_pg * factor).round(2)

  Dispensacion.create!(
    paciente:            socio,
    sede:                sede_disp,
    user:                dispensador,
    stock:               stock,
    indicacion_medica:   ind,
    cantidad:            cantidad,
    precio_unitario_ars: precio_pg,
    fecha_dispensacion:  fecha,
    observaciones:       'Entregado sin novedad.',
    aporte_socio_ars:    aporte,
  )

  puts "  💊 #{socio.nombre} #{socio.apellido} — #{cantidad}g #{stock.lote&.genetica&.nombre || stock.forma_producto}"
end
puts "  ✅ #{Dispensacion.joins(:sede).where(sedes: { club_id: club.id }).count} dispensaciones"

# ── Movimientos contables ─────────────────────────────────────
puts "\n💰 Movimientos contables..."
[
  { sede: sede_disp,  tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Febrero 2026',  monto_ars: 780000, fecha: 60.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_disp,  tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Marzo 2026',    monto_ars: 850000, fecha: 30.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_disp,  tipo: 'ingreso', categoria: 'aporte_socio',  descripcion: 'Cuotas socios - Abril 2026',    monto_ars: 920000, fecha: 2.days.ago.to_date,   pagado: true, medio_pago: 'transferencia' },
  { sede: sede_disp,  tipo: 'ingreso', categoria: 'subvencion',    descripcion: 'Donación socio benefactor',      monto_ars: 200000, fecha: 10.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'alquiler',      descripcion: 'Alquiler sede Avellaneda - Abr', monto_ars: 420000, fecha: 5.days.ago.to_date,   pagado: true, medio_pago: 'transferencia' },
  { sede: sede_disp,  tipo: 'egreso',  categoria: 'alquiler',      descripcion: 'Alquiler sede Devoto - Abr',     monto_ars: 340000, fecha: 5.days.ago.to_date,   pagado: true, medio_pago: 'transferencia' },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'electricidad',  descripcion: 'Factura eléctrica Marzo',        monto_ars: 108000, fecha: 25.days.ago.to_date,  pagado: true, medio_pago: 'debito'        },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Sustrato premium 60 bolsas',     monto_ars: 245000, fecha: 40.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Nutrientes Canna Coco A+B 10L',  monto_ars: 89000,  fecha: 35.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Macetas Air-Pot 11L x 80u',      monto_ars: 68000,  fecha: 45.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'honorario',     descripcion: 'Honorarios médico - Marzo',       monto_ars: 280000, fecha: 28.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'sueldo',        descripcion: 'Sueldo cultivador - Marzo',       monto_ars: 395000, fecha: 28.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'sueldo',        descripcion: 'Sueldo manicurador - Marzo',      monto_ars: 320000, fecha: 28.days.ago.to_date,  pagado: true, medio_pago: 'transferencia' },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'mantenimiento', descripcion: 'Reemplazo lámparas HPS x4',       monto_ars: 186000, fecha: 20.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Carbono activo filtros',           monto_ars: 42000,  fecha: 15.days.ago.to_date,  pagado: true, medio_pago: 'efectivo'      },
  { sede: sede_prod,  tipo: 'egreso',  categoria: 'electricidad',  descripcion: 'Factura eléctrica Abril',          monto_ars: 121000, fecha: 3.days.ago.to_date,   pagado: false, medio_pago: nil            },
  { sede: sede_mixta, tipo: 'egreso',  categoria: 'insumo',        descripcion: 'Bolsas de curado 3.5L x 200u',    monto_ars: 35000,  fecha: 8.days.ago.to_date,   pagado: true, medio_pago: 'efectivo'      },
].each do |m|
  next if club.movimientos_contables.exists?(descripcion: m[:descripcion], fecha: m[:fecha])
  club.movimientos_contables.create!(m.merge(created_by: admin))
end
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

# ── Ambiente (H1/H2) ─────────────────────────────────────────
puts "\n🌡️  Ambiente H1/H2..."

lote_activo_flor = club.lotes.find_by(codigo: 'CIC-FLOR-001')

[
  { tipo: 'temperatura', valor: '24.5', unidad: '°C',  sala: sala_veg,  horas: 48 },
  { tipo: 'humedad',     valor: '67.0', unidad: '%',   sala: sala_veg,  horas: 46 },
  { tipo: 'vpd',         valor: '0.85', unidad: 'kPa', sala: sala_veg,  horas: 44 },
  { tipo: 'co2',         valor: '820',  unidad: 'ppm', sala: sala_veg,  horas: 42 },
  { tipo: 'temperatura', valor: '24.2', unidad: '°C',  sala: sala_veg,  horas: 24 },
  { tipo: 'humedad',     valor: '65.0', unidad: '%',   sala: sala_veg,  horas: 22 },
  { tipo: 'temperatura', valor: '26.8', unidad: '°C',  sala: sala_flor, horas: 48 },
  { tipo: 'humedad',     valor: '52.0', unidad: '%',   sala: sala_flor, horas: 46 },
  { tipo: 'co2',         valor: '820',  unidad: 'ppm', sala: sala_flor, horas: 44 },
  { tipo: 'vpd',         valor: '1.10', unidad: 'kPa', sala: sala_flor, horas: 42 },
  { tipo: 'temperatura', valor: '31.2', unidad: '°C',  sala: sala_flor, horas: 24 },  # alerta: > 30
  { tipo: 'co2',         valor: '540',  unidad: 'ppm', sala: sala_flor, horas: 22 },  # alerta: < 600
  { tipo: 'humedad',     valor: '50.5', unidad: '%',   sala: sala_flor, horas: 20 },
].each do |l|
  LecturaAmbiental.find_or_create_by!(
    club_id: club.id, sala: l[:sala], tipo: l[:tipo],
    medido_at: l[:horas].hours.ago.change(sec: 0)
  ) do |r|
    r.valor  = l[:valor]
    r.unidad = l[:unidad]
    r.fuente = 'manual'
    r.lote   = lote_activo_flor if l[:sala] == sala_flor && lote_activo_flor
  end
end

regla_temp = ReglaAmbiental.find_or_create_by!(club: club, sala: sala_flor, nombre: 'Temperatura alta floración') do |r|
  r.tipo_lectura     = 'temperatura'
  r.condicion        = 'gt'
  r.umbral_a         = 30.0
  r.duracion_minutos = 15
  r.accion           = 'notificar'
  r.prioridad        = 'alta'
  r.activa           = true
end
regla_hum = ReglaAmbiental.find_or_create_by!(club: club, sala: sala_veg, nombre: 'Humedad baja vegetativo') do |r|
  r.tipo_lectura     = 'humedad'
  r.condicion        = 'lt'
  r.umbral_a         = 45.0
  r.duracion_minutos = 10
  r.accion           = 'notificar'
  r.prioridad        = 'media'
  r.activa           = true
end
regla_co2 = ReglaAmbiental.find_or_create_by!(club: club, sala: sala_flor, nombre: 'CO2 bajo floración') do |r|
  r.tipo_lectura     = 'co2'
  r.condicion        = 'lt'
  r.umbral_a         = 600.0
  r.duracion_minutos = 20
  r.accion           = 'notificar'
  r.prioridad        = 'alta'
  r.activa           = true
end

lectura_temp_alta = LecturaAmbiental.find_by(sala: sala_flor, tipo: 'temperatura', valor: '31.2')
lectura_co2_baja  = LecturaAmbiental.find_by(sala: sala_flor, tipo: 'co2',         valor: '540')

if lectura_temp_alta
  Alerta.find_or_create_by!(club_id: club.id, regla: regla_temp, sala: sala_flor, estado: 'activa') do |a|
    a.mensaje = "Temperatura 31.2°C supera umbral (30°C) en Sala Floración"
    a.lectura = lectura_temp_alta
  end
end
if lectura_co2_baja
  Alerta.find_or_create_by!(club_id: club.id, regla: regla_co2, sala: sala_flor, estado: 'activa') do |a|
    a.mensaje = "CO2 540ppm por debajo del umbral (600ppm) en Sala Floración"
    a.lectura = lectura_co2_baja
  end
end

puts "  ✅ #{LecturaAmbiental.count} lecturas, #{ReglaAmbiental.count} reglas, #{Alerta.count} alertas"

# ── Club Demo ────────────────────────────────────────────────
puts "\n🎭 Club Demo..."
demo = Club.find_or_create_by!(slug: 'club_demo') do |c|
  c.name               = 'Club Demo'
  c.plan               = 'cosecha'
  c.plan_activo_hasta  = 1.year.from_now.to_date
  c.city               = 'Buenos Aires'
  c.country            = 'Argentina'
  c.timezone           = 'America/Argentina/Buenos_Aires'
end

demo_admin = User.find_or_initialize_by(email: 'admin@clubdemo.org')
demo_admin.assign_attributes(
  password: '123456Aa', role: 'admin',
  first_name: 'Admin', last_name: 'Demo', club: demo
)
demo_admin.save!

demo_sede = demo.sedes.find_or_create_by!(nombre: 'Sede Demo') do |s|
  s.tipo = 'produccion'; s.ciudad = 'Buenos Aires'; s.created_by = demo_admin
end
demo_sala = demo.salas.find_or_create_by!(nombre: 'Sala Demo') do |s|
  s.state = 'activa'; s.kind = 'floracion'; s.tipo = 'floracion'
  s.pots_count = 20; s.plants_max = 20; s.sede = demo_sede; s.created_by = demo_admin
end
demo_paciente = demo.pacientes.find_or_initialize_by(dni_normalizado: '99000001')
if demo_paciente.new_record?
  demo_paciente.assign_attributes(
    nombre: 'Paciente', apellido: 'Demo', dni: '99.000.001',
    fecha_nacimiento: Date.new(1990, 1, 1),
    email: 'paciente@demo.com', es_paciente: true, created_by: demo_admin
  )
  demo_paciente.save!
end
demo_genetica = Genetica.find_by(global: true, nombre: 'POLARIS') ||
                Genetica.where(global: true).first
demo_lote = demo.lotes.find_or_initialize_by(codigo: 'DEMO-001')
if demo_lote.new_record?
  demo_lote.assign_attributes(
    sala: demo_sala, estado: 'floracion', genetica: demo_genetica,
    start_date: 30.days.ago.to_date, grow_type: 'sustrato', light_type: 'led',
    plants_count: 5, notes: 'Lote demo'
  )
  demo_lote.save!
  5.times { |i| demo_lote.plants.create!(nombre: "DEMO-001-P#{(i+1).to_s.rjust(3,'0')}", state: 'floracion') }
  demo_lote.update_columns(plants_count: 5)
end
Stock.find_or_create_by!(lote: demo_lote, forma_producto: 'flor_seca', origen: 'lote') do |s|
  s.sede = demo_sede; s.unidad = 'g'; s.cantidad = 100.0
  s.costo_unitario_ars = 1500.0; s.precio_sugerido_ars = 2000.0
end
demo_regla = ReglaAmbiental.find_or_create_by!(club: demo, sala: demo_sala, nombre: 'Temperatura demo') do |r|
  r.tipo_lectura = 'temperatura'; r.condicion = 'gt'; r.umbral_a = 30.0
  r.duracion_minutos = 15; r.accion = 'notificar'; r.prioridad = 'alta'; r.activa = true
end
Alerta.find_or_create_by!(club_id: demo.id, regla: demo_regla, sala: demo_sala, estado: 'activa') do |a|
  a.mensaje = "Temperatura alta en Sala Demo (alerta de ejemplo)"
end
puts "  ✅ Club Demo: #{demo.name} | admin: #{demo_admin.email}"

# ── Resumen ──────────────────────────────────────────────────
puts "\n" + "="*60
puts "🎉 Seeds completados!"
puts "="*60
puts ""
puts "📧 Credenciales — password: 123456Aa"
puts "  super_admin  : super@clubcultivo.app"
puts "  super_admin2 : superadmin@cultivoespacial.app"
puts "  --- Mitocondria Club ---"
puts "  admin        : admin@mitocondriaclub.org"
puts "  médico       : medico@mitocondriaclub.org"
puts "  cultivador   : cultivador@mitocondriaclub.org"
puts "  manicura     : manicura@mitocondriaclub.org"
puts "  dispensador  : dispensa@mitocondriaclub.org"
puts "  abogado      : abogado@mitocondriaclub.org"
puts "  auditor      : auditor@mitocondriaclub.org"
puts "  paciente     : paciente@mitocondriaclub.org"
puts "  delivery     : delivery@mitocondriaclub.org"
puts "  --- Club Demo ---"
puts "  admin        : admin@clubdemo.org"
puts ""
puts "📊 Dataset — Mitocondria Club:"
puts "  🧬 Genéticas : #{Genetica.count} total (#{Genetica.where(global: true).count} globales)"
puts "  👥 Pacientes : #{club.pacientes.count} (#{club.pacientes.where(es_paciente: true).count} con REPROCANN)"
puts "  🏢 Sedes     : #{club.sedes.count}"
puts "  🏗️  Salas    : #{club.salas.count}"
puts "  📦 Lotes     : #{club.lotes.count}"
puts "  🪴 Plantas   : #{Plant.joins(:lote).where(lotes: { club_id: club.id }).count}"
puts "  📦 Stock     : #{Stock.joins(:sede).where(sedes: { club_id: club.id }).count} ítems (#{Pesada.joins(:lote).where(lotes: { club_id: club.id }).count} pesadas)"
puts "  💊 Dispens.  : #{Dispensacion.joins(:sede).where(sedes: { club_id: club.id }).count}"
puts "  💰 Contabl.  : #{club.movimientos_contables.count}"
puts ""
puts "📊 Dataset — Club Demo:"
puts "  🏗️  Salas    : #{demo.salas.count}"
puts "  📦 Lotes     : #{demo.lotes.count}"
puts "  👥 Pacientes : #{demo.pacientes.count}"
puts ""
