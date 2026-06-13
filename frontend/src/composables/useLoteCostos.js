import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { getCostoLote, createCostoLote, updateCostoLote, recalcularCostoLote, getPesadas } from '../lib/api'

export function useLoteCostos(loteId) {
  const toast = useToast()

  const costoLote     = ref(null)
  const showCostoForm = ref(false)
  const savingCosto   = ref(false)
  const pesadasLote   = ref([])
  // gramos_producidos se excluye del form — siempre viene de pesadas aprobadas
  const costoForm     = ref({ costo_insumos: 0, costo_energia: 0, costo_mano_obra: 0, costo_prorrateado: 0, notas: '' })

  const costoTotal = computed(() => {
    const f = costoForm.value
    return (Number(f.costo_insumos) || 0) + (Number(f.costo_energia) || 0) + (Number(f.costo_mano_obra) || 0) + (Number(f.costo_prorrateado) || 0)
  })

  // Pesadas aprobadas por admin (aprobada_at presente)
  const pesadasAprobadas = computed(() => pesadasLote.value.filter(p => p.aprobada_at))

  // Pesadas registradas pero aún no aprobadas ni rechazadas
  const pesadasPendientes = computed(() => pesadasLote.value.filter(p => !p.aprobada_at && !p.rechazada_at))

  // Suma de gramos de pesadas aprobadas. Usa peso_curado_g si existe, sino peso_seco_g.
  const gramosAprobados = computed(() => {
    if (!pesadasAprobadas.value.length) return null
    const suma = pesadasAprobadas.value.reduce((acc, p) => acc + (p.peso_curado_g || p.peso_seco_g || 0), 0)
    return suma > 0 ? Math.round(suma * 10) / 10 : null
  })

  // Suma parcial de pesadas pendientes (aún sin aprobar), para mostrar como referencia
  const gramosPendientes = computed(() => {
    if (!pesadasPendientes.value.length) return null
    const suma = pesadasPendientes.value.reduce((acc, p) => acc + (p.peso_curado_g || p.peso_seco_g || 0), 0)
    return suma > 0 ? Math.round(suma * 10) / 10 : null
  })

  // Estado del campo gramos para el template
  // 'aprobado' | 'pendiente' | 'sin_datos'
  const estadoGramos = computed(() => {
    if (gramosAprobados.value) return 'aprobado'
    if (gramosPendientes.value) return 'pendiente'
    return 'sin_datos'
  })

  const costoPorGramo = computed(() => {
    const g = gramosAprobados.value
    return g > 0 ? costoTotal.value / g : null
  })

  function openCostoForm() {
    costoForm.value = {
      costo_insumos:     costoLote.value?.costo_insumos     || 0,
      costo_energia:     costoLote.value?.costo_energia      || 0,
      costo_mano_obra:   costoLote.value?.costo_mano_obra    || 0,
      costo_prorrateado: costoLote.value?.costo_prorrateado  || 0,
      notas:             costoLote.value?.notas              || '',
    }
    showCostoForm.value = true
  }

  async function saveCosto() {
    savingCosto.value = true
    try {
      const payload = {
        costo_insumos:     Number(costoForm.value.costo_insumos)     || 0,
        costo_energia:     Number(costoForm.value.costo_energia)      || 0,
        costo_mano_obra:   Number(costoForm.value.costo_mano_obra)    || 0,
        costo_prorrateado: Number(costoForm.value.costo_prorrateado)  || 0,
        gramos_producidos: gramosAprobados.value,  // siempre desde pesadas aprobadas
        notas:             costoForm.value.notas,
      }
      const fn = costoLote.value ? updateCostoLote : createCostoLote
      const { data } = await fn(loteId, payload)
      costoLote.value = data
      showCostoForm.value = false
      toast.success('Costos guardados')
    } catch {
      toast.error('Error al guardar costos')
    } finally {
      savingCosto.value = false
    }
  }

  async function cargarCostos() {
    try {
      const [costoRes, pesadasRes] = await Promise.all([
        getCostoLote(loteId),
        getPesadas(loteId),
      ])
      costoLote.value   = costoRes.data?.costo || costoRes.data || null
      pesadasLote.value = pesadasRes.data || []
    } catch {}
  }

  // Deriva insumos/energía/mano de obra desde los egresos del libro contable
  // vinculados al lote (el libro es la fuente de verdad de costos)
  const recalculando = ref(false)
  async function recalcularDesdeLibro() {
    recalculando.value = true
    try {
      const { data } = await recalcularCostoLote(loteId)
      costoLote.value = data
      toast.success('Costos recalculados desde el libro contable')
    } catch {
      toast.error('Error al recalcular costos')
    } finally {
      recalculando.value = false
    }
  }

  return {
    costoLote, showCostoForm, savingCosto, costoForm,
    costoTotal, costoPorGramo,
    gramosAprobados, gramosPendientes, estadoGramos,
    pesadasAprobadas, pesadasPendientes,
    openCostoForm, saveCosto, cargarCostos,
    recalculando, recalcularDesdeLibro,
  }
}
