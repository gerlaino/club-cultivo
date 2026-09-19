// Los frascos del cultivador de casa: UN estado para el teléfono y el escritorio. Lo cosechado
// (el `Stock` de siempre), cuánto queda, lo que está por pesar, y la única salida que él tiene:
// consumir. Si la regla viviera dos veces, un día las dos pantallas dirían distinto del mismo
// frasco.
import { ref, computed, reactive } from 'vue'
import { listStocksHistorial, listLotes, consumirStock, getStockMovimientos } from '../lib/api'
import { hoyISO } from '../utils/dates.js'

export const FORMAS = { flor_seca: 'Flor seca', preroll: 'Prerolls', aceite: 'Aceite', hash: 'Hash', prensado: 'Prensado', tintura: 'Tintura', crema: 'Crema', capsula: 'Cápsulas', comestible: 'Comestible', otro: 'Otro', externo: 'Externo' }
export function formaLabel(f) { return FORMAS[f] || f }
export function fmt(n) { const v = Number(n || 0); return Number.isInteger(v) ? String(v) : v.toFixed(1) }

export function useFrascosPersonal() {
  const hoy      = hoyISO()
  const cargando = ref(true)
  const stocks   = ref([])
  const lotes    = ref([])

  const frascos  = computed(() => stocks.value.filter(s => Number(s.cantidad) > 0 && s.estado !== 'agotado'))
  const agotados = computed(() => stocks.value.filter(s => !(Number(s.cantidad) > 0) || s.estado === 'agotado'))
  const porPesar = computed(() => lotes.value.filter(l => ['cosecha', 'en_manicura'].includes(l.estado)))
  // Por unidad, nunca sumando gramos con prerolls.
  const totalPorUnidad = computed(() => {
    const t = {}
    for (const s of frascos.value) { const u = s.unidad || 'g'; t[u] = (t[u] || 0) + Number(s.cantidad || 0) }
    return t
  })

  async function cargar() {
    cargando.value = true
    try {
      // `historial`: la lista completa. La de por defecto trae sólo lo asignado a una sede, y un
      // frasco recién pesado puede estar sin sede todavía.
      const [st, lt] = await Promise.allSettled([listStocksHistorial(), listLotes()])
      if (st.status === 'fulfilled') stocks.value = st.value.data || []
      if (lt.status === 'fulfilled') lotes.value  = lt.value.data || []
    } finally { cargando.value = false }
  }

  // ── Consumo ──
  const consumo = reactive({ stock: null, cantidad: null, fecha: hoy, nota: '', error: null, guardando: false })
  function prepararConsumo(s) { Object.assign(consumo, { stock: s, cantidad: null, fecha: hoy, nota: '', error: null, guardando: false }) }

  async function confirmarConsumo() {
    if (!(consumo.cantidad > 0)) return false
    consumo.guardando = true
    consumo.error = null
    try {
      const { data } = await consumirStock(consumo.stock.id, { cantidad: consumo.cantidad, fecha: consumo.fecha, nota: consumo.nota })
      const i = stocks.value.findIndex(s => s.id === data.id)
      if (i >= 0) stocks.value[i] = data
      return data
    } catch (e) {
      consumo.error = e?.response?.data?.error || 'No se pudo anotar'
      return false
    } finally { consumo.guardando = false }
  }

  // ── Lo que salió de un frasco ──
  async function movimientosDe(stock) {
    const { data } = await getStockMovimientos(stock.id)
    return data || []
  }

  return { hoy, cargando, stocks, lotes, frascos, agotados, porPesar, totalPorUnidad, cargar,
           consumo, prepararConsumo, confirmarConsumo, movimientosDe }
}
