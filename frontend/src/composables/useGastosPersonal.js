// Los gastos del cultivador de casa: UN estado para las dos pantallas (escritorio y teléfono).
// Es el mismo `MovimientoContable` de una organización —por eso el costo por lote y el
// informe de costo salen solos— reducido a lo que él hace: anotar lo que compró, ver el mes y
// el año, corregir, borrar. Por acá SÓLO SALE PLATA (misma regla que «Nuevo movimiento»): no
// hay ingresos, cajas, cuotas ni sectores. Si la regla viviera dos veces, un día el teléfono
// y el escritorio dirían distinto del mismo gasto.
import { ref, computed, reactive } from 'vue'
import { listMovimientos, createMovimiento, updateMovimiento, deleteMovimiento,
         listCategoriasContables, listLotes } from '../lib/api'
import { hoyISO, toISO } from '../utils/dates.js'

// Sectores que le aplican: cultivo y lo general. Con los de dispensario y buffet la lista se
// llenaba de cosas que nunca va a comprar.
const SECTORES_PERSONAL = ['cultivo', 'general', 'administracion', 'otro']
const LOTES_ABIERTOS = ['enraizado', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado']

export function formVacio(categoriaId = '') {
  return { id: null, descripcion: '', monto_ars: null, categoria_contable_id: categoriaId,
           fecha: hoyISO(), medio_pago: 'efectivo', lote_id: null }
}

export function useGastosPersonal() {
  const hoy = hoyISO()

  // ── Mes ──
  const mes = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
  const esMesActual = computed(() => {
    const n = new Date()
    return mes.value.getFullYear() === n.getFullYear() && mes.value.getMonth() === n.getMonth()
  })
  const mesLabel = computed(() => {
    const s = mes.value.toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })
    return s.charAt(0).toUpperCase() + s.slice(1)
  })
  function rangoMes() {
    return { desde: toISO(mes.value), hasta: toISO(new Date(mes.value.getFullYear(), mes.value.getMonth() + 1, 0)) }
  }
  function moverMes(d) {
    mes.value = new Date(mes.value.getFullYear(), mes.value.getMonth() + d, 1)
    return cargar()
  }

  // ── Datos ──
  const cargando   = ref(true)
  const gastos     = ref([])
  const totalMes   = ref(0)
  const totalAnio  = ref(0)
  const categorias = ref([])
  const lotes      = ref([])
  const lotesAbiertos = computed(() => lotes.value.filter(l => LOTES_ABIERTOS.includes(l.estado)))

  async function cargar() {
    cargando.value = true
    try {
      const { data } = await listMovimientos({ tipo: 'egreso', ...rangoMes(), per_page: 200 })
      gastos.value   = data?.movimientos || []
      totalMes.value = Number(data?.totales?.egresos ?? 0)
    } catch { gastos.value = [] } finally { cargando.value = false }
  }

  async function cargarAnio() {
    try {
      const n = new Date()
      const { data } = await listMovimientos({ tipo: 'egreso', desde: toISO(new Date(n.getFullYear(), 0, 1)), hasta: hoy, per_page: 1 })
      totalAnio.value = Number(data?.totales?.egresos || 0)
    } catch { /* el del año es contexto: sin él la pantalla sirve igual */ }
  }

  async function cargarCatalogo() {
    const [cats, lts] = await Promise.allSettled([listCategoriasContables({ activas: 'true', tipo: 'egreso' }), listLotes()])
    if (cats.status === 'fulfilled') {
      categorias.value = (cats.value.data || []).filter(c => !c.unidad_negocio || SECTORES_PERSONAL.includes(c.unidad_negocio.tipo))
    }
    if (lts.status === 'fulfilled') lotes.value = lts.value.data || []
  }

  function cargarTodo() { return Promise.all([cargar(), cargarAnio(), cargarCatalogo()]) }

  // ── Alta / edición ──
  const form      = reactive(formVacio())
  const guardando = ref(false)
  const error     = ref(null)

  function nuevo() {
    Object.assign(form, formVacio(categorias.value[0]?.id || ''))
    error.value = null
  }
  function editar(g) {
    Object.assign(form, { id: g.id, descripcion: g.descripcion, monto_ars: Number(g.monto_ars),
                          categoria_contable_id: g.categoria_contable_id || '', fecha: g.fecha,
                          medio_pago: g.medio_pago || 'efectivo', lote_id: g.lote?.id || null })
    error.value = null
  }

  async function guardar() {
    guardando.value = true
    error.value = null
    const payload = {
      tipo: 'egreso', descripcion: form.descripcion, monto_ars: form.monto_ars,
      categoria_contable_id: form.categoria_contable_id, fecha: form.fecha,
      medio_pago: form.medio_pago, lote_id: form.lote_id || null, pagado: true,
    }
    try {
      if (form.id) await updateMovimiento(form.id, payload)
      else         await createMovimiento(payload)
      await Promise.all([cargar(), cargarAnio()])
      return true
    } catch (e) {
      error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo guardar'
      return false
    } finally { guardando.value = false }
  }

  async function borrar(g) {
    await deleteMovimiento(g.id)
    await Promise.all([cargar(), cargarAnio()])
  }

  function ars(n) { return '$' + Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 }) }
  function fechaCorta(f) { return f ? new Date(f + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : '' }

  return {
    hoy, mes, mesLabel, esMesActual, moverMes,
    cargando, gastos, totalMes, totalAnio, categorias, lotes, lotesAbiertos,
    cargar, cargarAnio, cargarCatalogo, cargarTodo,
    form, guardando, error, nuevo, editar, guardar, borrar,
    ars, fechaCorta,
  }
}
