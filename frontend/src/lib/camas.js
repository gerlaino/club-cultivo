// Suelo vivo: lo que las pantallas de cama muestran. Las REGLAS viven en el backend (el estado, el
// «qué viene», qué receta sirve para qué, las unidades, qué agua) y viajan en la cama o en `/me`
// (`reglas_cultivo.suelo_vivo`); acá sólo se les pone texto y color.
import { useAuthStore } from '../stores/auth'

export const ESTADO_CAMA = {
  en_uso:      { label: 'En uso',      icon: 'bi-flower1',        clase: 'leaf' },
  cocinando:   { label: 'Cocinando',   icon: 'bi-hourglass-split', clase: 'amber' },
  descansando: { label: 'Descansando', icon: 'bi-moon-stars',     clase: 'sky' },
  lista:       { label: 'Lista',       icon: 'bi-check2-circle',  clase: 'leaf' },
  retirada:    { label: 'Retirada',    icon: 'bi-archive',        clase: 'ink' },
}

export function estadoCama(estado) {
  return ESTADO_CAMA[estado] || { label: estado || '—', icon: 'bi-square', clase: 'ink' }
}

// Lo que manda el backend en `/me` (la fuente); el respaldo es sólo para que una pantalla abierta
// antes del deploy no quede en blanco.
const RESPALDO = {
  usos_receta: ['riego', 'top_dress', 'mezcla'],
  usos_receta_labels: { riego: 'Riego o té', top_dress: 'Top dress', mezcla: 'Mezcla de armado' },
  unidades_por_uso: { riego: ['ml_l', 'g_l'], top_dress: ['g_m2', 'ml_m2'], mezcla: ['g_l_suelo', 'ml_l_suelo', 'l_l_suelo'] },
  unidad_labels: { ml_l: 'ml/L', g_l: 'g/L', g_m2: 'g/m²', ml_m2: 'ml/m²', g_l_suelo: 'g por L de suelo', ml_l_suelo: 'ml por L de suelo', l_l_suelo: 'L por L de suelo' },
  base_unidad: { riego: 'L', top_dress: 'm²', mezcla: 'L de suelo' },
  tipos_registro: ['armado', 'top_dress', 'te', 'cobertura', 'mulch', 'inoculacion', 'riego', 'medicion', 'nota'],
  tipos_registro_labels: { armado: 'Armado', top_dress: 'Top dress', te: 'Té al suelo', cobertura: 'Cobertura', mulch: 'Mulch', inoculacion: 'Inoculación', riego: 'Riego', medicion: 'Medición', nota: 'Nota' },
  aguas: ['red', 'declorada', 'lluvia', 'osmosis', 'pozo'],
  tareas_no_aplican: ['trasplante', 'nutricion'],
}

export function reglasSueloVivo() {
  let r = null
  try { r = useAuthStore().user?.reglas_cultivo?.suelo_vivo } catch { r = null }
  return { ...RESPALDO, ...(r || {}) }
}

export const AGUA_LABELS = { red: 'De red', declorada: 'De red, declorada', lluvia: 'De lluvia', osmosis: 'Ósmosis', pozo: 'De pozo' }
export const aguaLabel = (a) => AGUA_LABELS[a] || a || ''

// La última agua elegida (per-viewer: es una comodidad, no un dato).
const CLAVE_AGUA = 'suelo-vivo:agua'
export function ultimaAgua() { try { return localStorage.getItem(CLAVE_AGUA) || '' } catch { return '' } }
export function recordarAgua(a) { try { if (a) localStorage.setItem(CLAVE_AGUA, a) } catch { /* sin storage */ } }

export const ICONO_REGISTRO = {
  armado: 'bi-bricks', top_dress: 'bi-basket', te: 'bi-cup-hot', cobertura: 'bi-flower3', mulch: 'bi-layers',
  inoculacion: 'bi-bug', riego: 'bi-droplet', medicion: 'bi-thermometer-half', nota: 'bi-journal-text',
}

const fmtNum = (n, dec = 2) => (n == null || n === '' ? '—' : Number(n).toLocaleString('es-AR', { maximumFractionDigits: dec }))
export const fmtM2 = (n) => (n == null ? '—' : `${fmtNum(n)} m²`)

function fechaCorta(iso) {
  if (!iso) return ''
  const [y, m, d] = String(iso).slice(0, 10).split('-').map(Number)
  return new Date(y, m - 1, d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

// «Lista el 12-oct», «Descansa hasta el 15-nov (faltan 12 días)», «Toca top dress en 3 días».
// El cálculo es del backend (`Cama#proximo_paso`); acá se dice.
export function textoProximoPaso(p) {
  if (!p) return null
  const cuando = (n) => (n > 1 ? `en ${n} días` : n === 1 ? 'mañana' : n === 0 ? 'hoy' : `hace ${-n} ${n === -1 ? 'día' : 'días'}`)
  switch (p.tipo) {
    case 'lista':        return { texto: `Se termina de cocinar ${cuando(p.faltan_dias)} (${fechaCorta(p.fecha)})`, alerta: p.faltan_dias <= 0 }
    case 'fin_descanso': return { texto: `Descansa hasta el ${fechaCorta(p.fecha)} · ${p.faltan_dias <= 0 ? 'ya cumplió' : `faltan ${p.faltan_dias} ${p.faltan_dias === 1 ? 'día' : 'días'}`}`, alerta: false }
    case 'descansando':  return { texto: `Descansando hace ${p.lleva_dias} ${p.lleva_dias === 1 ? 'día' : 'días'} (sin fecha de fin)`, alerta: false }
    case 'top_dress':    return { texto: p.faltan_dias <= 0 ? `Toca top dress (${p.faltan_dias === 0 ? 'hoy' : `hace ${-p.faltan_dias} días`})` : `Top dress ${cuando(p.faltan_dias)}`, alerta: p.faltan_dias <= 0 }
    default: return null
  }
}

// Plantar en una cama que descansa o se cocina NO se bloquea (Germán, 22-sep): se avisa antes.
export function avisoAlPlantar(cama) {
  if (!cama) return null
  if (cama.estado === 'descansando') {
    const p = cama.proximo_paso
    return p?.tipo === 'fin_descanso' && p.faltan_dias > 0
      ? `La ${cama.nombre} descansa hasta el ${fechaCorta(p.fecha)} (faltan ${p.faltan_dias} días). Plantar corta el descanso.`
      : `La ${cama.nombre} está descansando. Plantar corta el descanso.`
  }
  if (cama.estado === 'cocinando') {
    return `La mezcla de la ${cama.nombre} se termina de cocinar el ${fechaCorta(cama.cocina_hasta)}: plantar antes puede quemar las raíces.`
  }
  if (cama.estado === 'retirada') return `La ${cama.nombre} está retirada.`
  return null
}

// Las líneas a descontar de una receta (o productos sueltos) para una base dada: litros de agua,
// m² de cama o litros de suelo. `factor` lo manda el backend por ítem (g → kg, ml → L): sin él, la
// harina en bolsas de kg se descontaría mil veces de más. Mismo cálculo que `Receta#calcular`.
export function lineasDeReceta(receta, base, overrides = [], insumos = []) {
  const b = Number(base) || 0
  const desdeReceta = receta
    ? receta.items.map(it => ({
        insumo_id: it.insumo_id, nombre: it.nombre, dosis: it.dosis, unidad_label: it.unidad_label,
        unidad_insumo: it.unidad_insumo, stock_actual: it.stock_actual,
        calculada: b ? +(Number(it.dosis) * b * (Number(it.factor) || 1)).toFixed(3) : null,
      }))
    : (overrides || []).map(x => {
        const i = insumos.find(y => y.id === x.insumo_id) || {}
        return { insumo_id: x.insumo_id, nombre: i.nombre, dosis: null, unidad_label: null, unidad_insumo: i.unidad_medida, stock_actual: i.stock_actual, calculada: null }
      })
  return desdeReceta.map(l => {
    const ov = (overrides || []).find(x => x.insumo_id === l.insumo_id)
    const cantidad = ov?.cantidad ?? l.calculada
    const faltante = cantidad != null && Number(l.stock_actual) < Number(cantidad) ? +(Number(cantidad) - Number(l.stock_actual)).toFixed(3) : 0
    return { ...l, cantidad, faltante, modo_faltante: ov?.modo_faltante || 'descontar_disponible' }
  })
}

// «armada hoy», «hace 12 días», «hace 14 meses».
export function edadCama(d) {
  if (d == null) return ''
  if (d <= 0) return 'armada hoy'
  if (d < 60) return `armada hace ${d} ${d === 1 ? 'día' : 'días'}`
  return `armada hace ${Math.round(d / 30)} meses`
}

export const UNIDAD_CORTA = { mililitro: 'ml', gramo: 'g', litro: 'L', kilogramo: 'kg', unidad: 'un' }
export const unidadCorta = (u) => UNIDAD_CORTA[u] || u || ''
export { fmtNum, fechaCorta }
