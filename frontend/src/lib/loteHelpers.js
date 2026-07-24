// ─────────────────────────────────────────────────────────────────────────
// FUENTE ÚNICA DE VERDAD de los estados de Cultivo (front).
// Espeja los enums del backend. Si el backend cambia, se actualiza ACÁ y todo
// el front lo consume desde este módulo — no redefinir diccionarios de estado
// sueltos en cada vista (eso genera el drift que veníamos limpiando).
//   Backend: Lote::ESTADOS  y  Plant::STATES
// ─────────────────────────────────────────────────────────────────────────

// Estados canónicos del LOTE (== Lote::ESTADOS del backend, en orden de ciclo).
export const LOTE_ESTADOS = ['germinacion', 'esqueje', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado', 'finalizado']

// Estados canónicos de la PLANTA (== Plant::STATES del backend).
// Ojo: la planta usa 'germinacion' (el lote usa 'germinacion'); ver STATE_MAP.
export const PLANT_STATES = ['germinacion', 'esqueje', 'vegetativo', 'floracion', 'secado', 'cosechado', 'descartada']

export const ESTADO_META = {
  germinacion:            { label: 'Germinación',        color: '#64748b', bg: '#f1f5f9', emoji: '🌱' },
  esqueje:            { label: 'Esqueje',             color: '#0891b2', bg: '#e0f2fe', emoji: '🪴' },
  vegetativo:         { label: 'Vegetativo',          color: '#16a34a', bg: '#dcfce7', emoji: '🍃' },
  floracion:          { label: 'Floración',          color: '#d97706', bg: '#fef3c7', emoji: '🌸' },
  cosecha:            { label: 'Cosecha',            color: '#059669', bg: '#d1fae5', emoji: '🌿' },
  en_manicura:        { label: 'En manicura',        color: '#7c3aed', bg: '#ede9fe', emoji: '✂️'  },
  curado:             { label: 'Curado',             color: '#2563eb', bg: '#dbeafe', emoji: '🫙' },
  finalizado:         { label: 'Finalizado',         color: '#1b5e20', bg: '#dcfce7', emoji: '✅' },
}

// Meta de los estados de PLANTA. Claves == PLANT_STATES (canónico backend).
export const PLANT_STATE_META = {
  germinacion:{ label: 'Germinación',color: '#16a34a', emoji: '🌱' },
  esqueje:    { label: 'Esqueje',    color: '#0891b2', emoji: '🌿' },
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

export const MACETA_LABELS = {
  '0.5': 'Vaso (0.5L)', '1': '1 litro', '3': '3 litros', '5': '5 litros',
  '7': '7 litros', '10': '10 litros', '12': '12 litros', '15': '15 litros', 'otro': 'Otro',
}

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
  vegetativo: 'Vegetativo', floracion: 'Floración', curado: 'Curado', cosecha: 'Cosecha', germinacion: 'Germinación',
  manicura: 'Manicura', cerrado: 'Cerrado',
}

export const STATE_MAP = {
  germinacion: 'germinacion', esqueje: 'esqueje', vegetativo: 'vegetativo',
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
    estados: ['germinacion', 'esqueje', 'vegetativo'],   // paraguas
    subetapas: [
      { estado: 'germinacion',    label: 'Germinación' },
      { estado: 'esqueje',    label: 'Enraizado'   },
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
export function macetaLabel(m) {
  if (m == null || m === '') return '—'
  const key = String(parseFloat(m))   // "15.0" -> "15", "0.5" -> "0.5"
  return MACETA_LABELS[key] || `${m}L`
}

// Fotoperíodo (horas luz/oscuridad). Usa el valor cargado si existe; si no, lo
// deriva del estado: vegetativo/germinación/esqueje = 18/6, floración = 12/12.
export function fotoperiodoLabel(estado, stored) {
  if (stored) return stored
  if (['germinacion', 'esqueje', 'vegetativo'].includes(estado)) return '18/6'
  if (estado === 'floracion') return '12/12'
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
  if (estado === 'germinacion') return 'Plantas en germinación. El sistema avanzará automáticamente cuando estén listas.'
  if (estado === 'finalizado') return 'Lote finalizado. Stock confirmado y disponible para dispensar.'
  if (['en_manicura', 'manicura', 'curado', 'cerrado'].includes(estado)) return 'Este lote pasó tu turno. Otro rol toma desde acá.'
  return null
}
