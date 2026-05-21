import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { getCostoLote, createCostoLote, updateCostoLote } from '../lib/api'

export function useLoteCostos(loteId) {
  const toast = useToast()

  const costoLote     = ref(null)
  const showCostoForm = ref(false)
  const savingCosto   = ref(false)
  const costoForm     = ref({ costo_insumos: 0, costo_energia: 0, costo_mano_obra: 0, costo_prorrateado: 0, gramos_producidos: null, notas: '' })

  const costoTotal = computed(() => {
    const f = costoForm.value
    return (Number(f.costo_insumos) || 0) + (Number(f.costo_energia) || 0) + (Number(f.costo_mano_obra) || 0) + (Number(f.costo_prorrateado) || 0)
  })

  const costoPorGramo = computed(() => {
    const g = Number(costoForm.value.gramos_producidos)
    return g > 0 ? costoTotal.value / g : null
  })

  function openCostoForm() {
    if (costoLote.value) {
      costoForm.value = {
        costo_insumos:     costoLote.value.costo_insumos     || 0,
        costo_energia:     costoLote.value.costo_energia      || 0,
        costo_mano_obra:   costoLote.value.costo_mano_obra    || 0,
        costo_prorrateado: costoLote.value.costo_prorrateado  || 0,
        gramos_producidos: costoLote.value.gramos_producidos  || null,
        notas:             costoLote.value.notas              || '',
      }
    } else {
      costoForm.value = { costo_insumos: 0, costo_energia: 0, costo_mano_obra: 0, costo_prorrateado: 0, gramos_producidos: null, notas: '' }
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
        gramos_producidos: costoForm.value.gramos_producidos ? Number(costoForm.value.gramos_producidos) : null,
        notas: costoForm.value.notas,
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
      const { data } = await getCostoLote(loteId)
      costoLote.value = data?.costo || data || null
    } catch {}
  }

  return {
    costoLote, showCostoForm, savingCosto, costoForm,
    costoTotal, costoPorGramo,
    openCostoForm, saveCosto, cargarCostos,
  }
}
