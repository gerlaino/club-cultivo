// ─────────────────────────────────────────────────────────────────────────
// FUENTE ÚNICA DE VERDAD de los estados de Cultivo (front).
// Espeja los enums del backend. Si el backend cambia, se actualiza ACÁ y todo
// el front lo consume desde este módulo — no redefinir diccionarios de estado
// sueltos en cada vista (eso genera el drift que veníamos limpiando).
//   Backend: Lote::ESTADOS  y  Plant::STATES
// ─────────────────────────────────────────────────────────────────────────

// Estados canónicos del LOTE (== Lote::ESTADOS del backend, en orden de ciclo).
export const LOTE_ESTADOS = ['enraizado', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado', 'finalizado']

// Estados canónicos de la PLANTA (== Plant::STATES del backend).
// Lote y planta comparten el mismo vocabulario de fases desde el colapso a 'enraizado'.
export const PLANT_STATES = ['enraizado', 'vegetativo', 'floracion', 'secado', 'cosechado', 'descartada']

export const ESTADO_META = {
  enraizado:            { label: 'Enraizado',          color: '#0891b2', bg: '#e0f2fe', emoji: '🌱' },
  vegetativo:         { label: 'Vegetativo',          color: '#16a34a', bg: '#dcfce7', emoji: '🍃' },
  floracion:          { label: 'Floración',          color: '#d97706', bg: '#fef3c7', emoji: '🌸' },
  cosecha:            { label: 'Cosecha',            color: '#059669', bg: '#d1fae5', emoji: '🌿' },
  en_manicura:        { label: 'En manicura',        color: '#7c3aed', bg: '#ede9fe', emoji: '✂️'  },
  curado:             { label: 'Curado',             color: '#2563eb', bg: '#dbeafe', emoji: '🫙' },
  finalizado:         { label: 'Finalizado',         color: '#1b5e20', bg: '#dcfce7', emoji: '✅' },
}

// Meta de los estados de PLANTA. Claves == PLANT_STATES (canónico backend).
export const PLANT_STATE_META = {
  enraizado:{ label: 'Enraizado',  color: '#0891b2', emoji: '🌱' },
  vegetativo: { label: 'Vegetativo', color: '#16a34a', emoji: '🍃' },
  floracion:  { label: 'Floración',  color: '#d97706', emoji: '🌸' },
  secado:     { label: 'Secado',     color: '#c2410c', emoji: '🍂' },
  cosechado:  { label: 'Cosechada',  color: '#2563eb', emoji: '✅' },
  descartada: { label: 'Descartada', color: '#dc2626', emoji: '❌' },
}

export const ESTADO_SALUD_META = {
  excelente: { color: '#16a34a', emoji: '🟢' },
  bueno:     { color: '#65a30d', emoji: '🟡' },
  regular:   { color: '#d97706', emoji: '🟠' },
  malo:      { color: '#dc2626', emoji: '🔴' },
  critico:   { color: '#991b1b', emoji: '🚨' },
}

export const PLAGAS_META = {
  ninguna:  { color: '#16a34a', emoji: '✅' },
  leve:     { color: '#d97706', emoji: '⚠️' },
  moderada: { color: '#ea580c', emoji: '🐛' },
  severa:   { color: '#dc2626', emoji: '🚨' },
}

// El volumen y nada más: "vaso", "maceta" o "pote" son el envase, no el dato. Lo que gobierna el
// riego, la frecuencia y cuándo toca trasplantar son los litros — y 0,335 L y 0,5 L no son lo mismo
// aunque los dos se llamen "vaso".
export const MACETA_LABELS = {
  '0.335': '0,335 L', '0.5': '0,5 L', '1': '1 litro', '3': '3 litros', '5': '5 litros',
  '7': '7 litros', '10': '10 litros', '12': '12 litros', '15': '15 litros', '20': '20 litros',
  'otro': 'Otro',
}

// Fuente ÚNICA de las opciones de maceta. Estaba copiada en cinco archivos (dos de ellos con
// valores distintos), así que agregar un tamaño obligaba a acordarse de los cinco.
export const MACETA_OPCIONES = Object.entries(MACETA_LABELS)
  .filter(([v]) => v !== 'otro')
  .map(([v, l]) => ({ v, l }))

export const TAREAS_LOTE = [
  { key: 'riego',                label: 'Riego',               emoji: '💧' },
  { key: 'nutricion',            label: 'Nutrición',           emoji: '🧪' },
  { key: 'poda',                 label: 'Poda',                emoji: '✂️'  },
  { key: 'defoliacion',          label: 'Defoliación',         emoji: '🍃' },
  { key: 'scrog_lst',            label: 'SCROG/LST',           emoji: '🪢' },
  { key: 'revision_plagas',      label: 'Revisión plagas',     emoji: '🔍' },
  { key: 'limpieza_sala',        label: 'Limpieza sala',       emoji: '🧹' },
  { key: 'ajuste_luz',           label: 'Ajuste de luz',       emoji: '💡' },
  { key: 'registro_ambiental',   label: 'Registro ambiental',  emoji: '🌡️' },
]

export const CICLO_BASE = ['vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado']

export const FASE_LABELS = {
  vegetativo: 'Vegetativo', floracion: 'Floración', curado: 'Curado', cosecha: 'Cosecha', enraizado: 'Enraizado',
  manicura: 'Manicura', cerrado: 'Cerrado',
}

export const STATE_MAP = {
  enraizado: 'enraizado', vegetativo: 'vegetativo',
  floracion: 'floracion', cosecha: 'cosechado',
  curado: 'cosechado', finalizado: 'cosechado',
}

export const POST_HARVEST_ESTADOS = ['cosecha', 'en_manicura', 'curado', 'finalizado']

// ─────────────────────────────────────────────────────────────────────────
// ESPINA BIOLÓGICA — eje FIJO y comparable entre lotes/cepas (para informes).
//
// 'Vegetativo' es un PARAGUAS: germinación (semilla) y enraizado (esqueje)
// comparten fotoperíodo (18/6) y fisiología, así que se consolidan con el
// vegetativo propiamente dicho. La espina se mantiene estable aunque el grow
// haga N trasplantes distintos → permite benchmarking entre lotes/clubes.
//
// El desglose de 'Vege' por contenedor (335cm³ → maceta N) es ENRIQUECIMIENTO
// que el informe superpone desde los eventos de trasplante; no es un estado.
// ─────────────────────────────────────────────────────────────────────────
export const ESPINA_BIOLOGICA = [
  {
    key: 'vegetativo',
    label: 'Vegetativo',
    estados: ['enraizado', 'vegetativo'],   // paraguas
    subetapas: [
      { estado: 'enraizado',      label: 'Enraizado' },
      { estado: 'vegetativo', label: 'Vege'        },  // se subdivide por trasplantes
    ],
  },
  {
    key: 'floracion',
    label: 'Floración',
    estados: ['floracion'],
    subetapas: [{ estado: 'floracion', label: 'Floración' }],
  },
]

// Grupo paraguas por estado del lote → para consolidar KPIs/labels sin repetir
// la lógica del agrupamiento. 'post' = todo lo post-cosecha (métrica aparte).
export const GRUPO_FASE = {
  germinacion: 'vegetativo', esqueje: 'vegetativo', vegetativo: 'vegetativo',
  floracion: 'floracion',
  cosecha: 'post', en_manicura: 'post', curado: 'post', finalizado: 'post',
}
export function grupoFase(estado) { return GRUPO_FASE[estado] || 'otro' }

// Dado un mapa { estado: dias } (que el informe deriva de los LoteEvento),
// devuelve el desglose por espina: total por bloque + sub-etapas con días > 0.
// Ej: desglosarCiclo({ germinacion:3, vegetativo:42, floracion:63 }) →
//   [{ key:'vegetativo', label:'Vegetativo', total:45,
//      subetapas:[{label:'Germinación',dias:3},{label:'Vege',dias:42}] },
//    { key:'floracion',  label:'Floración',  total:63, subetapas:[…] }]
export function desglosarCiclo(diasPorEstado = {}) {
  return ESPINA_BIOLOGICA.map(bloque => {
    const subetapas = bloque.subetapas
      .map(s => ({ label: s.label, dias: Number(diasPorEstado[s.estado]) || 0 }))
      .filter(s => s.dias > 0)
    const total = subetapas.reduce((a, s) => a + s.dias, 0)
    return { key: bloque.key, label: bloque.label, total, subetapas }
  }).filter(b => b.total > 0)
}

export function em(e)  { return ESTADO_META[e]       || { label: e || '—', color: '#64748b', bg: '#f1f5f9', emoji: '•' } }

export function pm(s)  { return PLANT_STATE_META[s]  || { label: s || '—', color: '#64748b', emoji: '🌿' } }
export function sm(s)  { return ESTADO_SALUD_META[s] || { color: '#94a3b8', emoji: '⚪' } }
export function pgm(p) { return PLAGAS_META[p]       || { color: '#94a3b8', emoji: '—' } }

export function growLabel(g)  { return { sustrato: 'Sustrato', hidroponia: 'Hidroponia' }[g] || g || '—' }
export function lightLabel(l) { return { led: 'LED', hps: 'HPS', cmh: 'CMH', natural: 'Natural', mixta: 'Mixta' }[l] || l || '—' }

// Dónde enraíza el lote. QUÉ métodos existen lo manda el backend (`/me` →
// `reglas_cultivo.metodos_enraizado`); acá sólo se les pone nombre.
const METODO_ENRAIZADO_LABELS = { incubadora: 'Incubadora (hidroponía)', jiffy: 'Jiffy', taco: 'Taco / lana de roca' }
export function metodoEnraizadoLabel(m) { return METODO_ENRAIZADO_LABELS[m] || m || '—' }
export function opcionesMetodoEnraizado(reglasCultivo) {
  return (reglasCultivo?.metodos_enraizado || []).map(v => ({ value: v, label: metodoEnraizadoLabel(v) }))
}
export function macetaLabel(m) {
  if (m == null || m === '') return '—'
  const key = String(parseFloat(m))   // "15.0" -> "15", "0.5" -> "0.5"
  return MACETA_LABELS[key] || `${m}L`
}

// Fotoperíodo (horas luz/oscuridad). Usa el valor cargado si existe; si no, lo
// deriva del estado: vegetativo/germinación/esqueje = 18/6, floración = 12/12.
// Una automática no cambia de luz: 18/6 también en floración.
export function fotoperiodoLabel(estado, stored, automatica = false) {
  if (stored) return stored
  if (['enraizado', 'vegetativo'].includes(estado)) return '18/6'
  if (estado === 'floracion') return automatica ? '18/6' : '12/12'
  return '—'
}

export function parseDate(d) {
  if (!d) return null
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return new Date(d + 'T00:00:00')
  return new Date(d)
}

export function formatDate(d) {
  if (!d) return '—'
  const date = parseDate(d)
  return !date || isNaN(date.getTime()) ? '—' : date.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

export function formatDateTime(d) {
  if (!d) return '—'
  const date = parseDate(d)
  return !date || isNaN(date.getTime()) ? '—' : date.toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export function capitalizarFase(f) { return FASE_LABELS[f] || (f ? f.charAt(0).toUpperCase() + f.slice(1) : '') }

export function phaseBannerMsg(estado) {
  if (estado === 'cosecha') return 'Lote cosechado. Manicura toma desde acá.'
  if (estado === 'enraizado') return 'Plantas enraizando: todavía sin raíz funcional. Humedad alta, sin nutrientes.'
  if (estado === 'finalizado') return 'Lote finalizado. Stock confirmado y disponible para dispensar.'
  if (['en_manicura', 'manicura', 'curado', 'cerrado'].includes(estado)) return 'Este lote pasó tu turno. Otro rol toma desde acá.'
  return null
}

// «Faltan 8 días para floración»: qué viene y cuándo, en una frase. El número lo manda el
// backend (`Lote#proximo_paso`: desde que entró a la fase más el objetivo de la genética);
// acá sólo se le pone palabras. null si el lote no tiene con qué contar.
const PROXIMO_PASO_LABEL = { floracion: 'floración', cosecha: 'la cosecha', curado: 'el curado' }
// La misma frase, corta, para una celda de tabla: «Flora en 8 d», «Cosecha hoy», «Cosecha hace 3 d».
const PROXIMO_PASO_CORTO = { floracion: 'Flora', cosecha: 'Cosecha', curado: 'Curado' }
// Pasado el objetivo se dice lo que hay que HACER («Cosechar · tocaba hace 32 d»): «Cosecha hace
// 32 d» se leía como que ya se había cosechado.
const PROXIMO_PASO_ACCION_CORTA = { floracion: 'Pasar a flora', cosecha: 'Cosechar', curado: 'Curar' }
export function textoProximoPasoCorto(lote) {
  const p = lote?.proximo_paso
  if (!p?.fase) return null
  const que = PROXIMO_PASO_CORTO[p.fase] || p.fase
  const n   = p.faltan_dias
  if (n > 0)   return `${que} en ${n} d`
  if (n === 0) return `${que} hoy`
  return `${PROXIMO_PASO_ACCION_CORTA[p.fase] || que} · tocaba hace ${-n} d`
}

// «Pasar a floración: tocaba hace 33 días (la genética pide 45 de vege; lleva 78)». Antes decía
// «Floración venció hace 33 días» y no se sabía contra qué. Los números y de dónde salen los manda
// el backend (`Lote#proximo_paso`).
const PROXIMO_PASO_ACCION = { floracion: 'Pasar a floración', cosecha: 'Cosechar', curado: 'Pasar a curado' }
// La fase en la que está el lote, según lo que viene después.
const FASE_ANTERIOR = { floracion: 'vege', cosecha: 'floración', curado: 'secado' }
function porQueToca(p) {
  const quien = p.objetivo_origen === 'genetica' ? 'la genética pide' : 'el plan del lote pide'
  const lleva = p.lleva_dias != null ? `; lleva ${p.lleva_dias}` : ''
  if (p.objetivo_origen === 'fecha_estimada') {
    const f = p.fecha ? parseDate(p.fecha)?.toLocaleDateString('es-AR', { day: 'numeric', month: 'numeric' }) : null
    return f ? `cosecha estimada para el ${f}${lleva ? `${lleva} de ${FASE_ANTERIOR[p.fase]}` : ''}` : null
  }
  if (!p.objetivo_dias) return null
  if (p.automatica) return `${quien} un ciclo de ${p.objetivo_dias}${lleva}`
  return `${quien} ${p.objetivo_dias} de ${FASE_ANTERIOR[p.fase] || 'esta fase'}${lleva}`
}
export function textoProximoPaso(lote) {
  const p = lote?.proximo_paso
  if (!p?.fase) return null
  const que = PROXIMO_PASO_LABEL[p.fase] || p.fase
  const n   = p.faltan_dias
  // Automática: el reloj es el ciclo (desde que va a maceta), y conviene decir de dónde sale.
  if (p.automatica && lote.dias_ciclo_objetivo && n > 1) return `Faltan ${n} días para la cosecha (ciclo de ${lote.dias_ciclo_objetivo})`
  if (n > 1)   return `Faltan ${n} días para ${que}`
  if (n === 1) return `Mañana toca ${que}`
  if (n === 0) return `Hoy toca ${que}`
  const pasados = -n
  const accion  = PROXIMO_PASO_ACCION[p.fase] || `${que.charAt(0).toUpperCase()}${que.slice(1)}`
  const razon   = porQueToca(p)
  return `${accion}: tocaba hace ${pasados} ${pasados === 1 ? 'día' : 'días'}${razon ? ` (${razon})` : ''}`
}
