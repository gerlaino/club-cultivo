import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { usePacientesStore } from '../stores/pacientes'
import { getCuentaCorriente, setLimiteCC, toggleGramosCC, setLimiteGCC, cargarGCC, updatePaciente } from '../lib/api.js'

export function useSocioCuentaCorriente(socioId) {
  const { success: toastOk, error: toastErr } = useToast()
  const store = usePacientesStore()

  const cc             = ref(null)
  const loadingCC      = ref(false)

  // ── Crédito ARS ───────────────────────────────────────────
  const limiteEditOpen = ref(false)
  const limiteEditVal  = ref(null)
  const savingLimite   = ref(false)

  // ── Crédito gramos ────────────────────────────────────────
  const togglingGramos = ref(false)
  const limiteGOpen    = ref(false)
  const limiteGVal     = ref(null)
  const savingLimiteG  = ref(false)
  const cargarGOpen    = ref(false)
  const cargarGVal     = ref(null)
  const savingCargarG  = ref(false)

  // ── Descuento ────────────────────────────────────────────
  const descuentoEditOpen = ref(false)
  const descuentoEditVal  = ref(null)
  const savingDescuento   = ref(false)

  // Lee el descuento directamente del store del paciente (reactivo)
  const descuentoPorcentaje = computed(() => store.current?.descuento_porcentaje ?? 0)

  // ── Formateo ──────────────────────────────────────────────
  const fmtARS = (n) => new Intl.NumberFormat('es-AR', {
    style: 'currency', currency: 'ARS',
    minimumFractionDigits: 0, maximumFractionDigits: 0,
  }).format(n || 0)

  const ccDeudaActual = computed(() => Math.max(0, -(cc.value?.saldo_disponible ?? 0)))
  const ccMargen      = computed(() => (cc.value?.saldo_disponible ?? 0) + (cc.value?.limite_credito ?? 0))
  const ccPorcentaje  = computed(() => {
    if (!cc.value?.limite_credito) return 0
    return Math.min(Math.round(ccDeudaActual.value / cc.value.limite_credito * 100), 100)
  })

  // ── Carga ─────────────────────────────────────────────────
  async function loadCC() {
    if (cc.value) return
    loadingCC.value = true
    try {
      const { data } = await getCuentaCorriente(socioId)
      cc.value = data
    } catch {
      toastErr('No se pudo cargar la cuenta corriente')
    } finally {
      loadingCC.value = false
    }
  }

  // ── Toggle crédito ARS ────────────────────────────────────
  async function toggleLimite() {
    if ((cc.value?.limite_credito ?? 0) > 0) {
      // Desactivar → poner en 0
      savingLimite.value = true
      try {
        const { data } = await setLimiteCC(socioId, 0)
        cc.value = data
        store.fetchOne(socioId)
        toastOk('Crédito en pesos desactivado')
      } catch (e) {
        toastErr(e?.response?.data?.error || 'Error')
      } finally {
        savingLimite.value = false
      }
    } else {
      // Activar → abrir input
      limiteEditVal.value  = null
      limiteEditOpen.value = true
    }
  }

  function openLimiteEdit() {
    limiteEditVal.value  = cc.value?.limite_credito ?? 0
    limiteEditOpen.value = true
  }

  async function saveLimite() {
    const nuevo = Number(limiteEditVal.value)
    if (nuevo < 0) return
    savingLimite.value = true
    try {
      const { data } = await setLimiteCC(socioId, nuevo)
      cc.value = data
      limiteEditOpen.value = false
      store.fetchOne(socioId)
      toastOk('Límite actualizado')
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al guardar límite')
    } finally {
      savingLimite.value = false
    }
  }

  // ── Toggle crédito gramos ─────────────────────────────────
  async function toggleGramos() {
    togglingGramos.value = true
    try {
      const { data } = await toggleGramosCC(socioId)
      cc.value = data
      store.fetchOne(socioId)
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al cambiar estado')
    } finally {
      togglingGramos.value = false
    }
  }

  async function saveLimiteG() {
    const nuevo = Number(limiteGVal.value)
    if (nuevo <= 0) return
    savingLimiteG.value = true
    try {
      const { data } = await setLimiteGCC(socioId, nuevo)
      cc.value = data
      limiteGOpen.value = false
      toastOk('Cupo en gramos actualizado')
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al guardar')
    } finally {
      savingLimiteG.value = false
    }
  }

  async function doCargarG() {
    const gramos = Number(cargarGVal.value)
    if (gramos <= 0) return
    savingCargarG.value = true
    try {
      const { data } = await cargarGCC(socioId, { gramos })
      cc.value = data
      cargarGOpen.value = false
      cargarGVal.value  = null
      store.fetchOne(socioId)
      toastOk(`${gramos}g acreditados`)
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al acreditar')
    } finally {
      savingCargarG.value = false
    }
  }

  // ── Descuento ────────────────────────────────────────────
  async function toggleDescuento() {
    if (descuentoPorcentaje.value > 0) {
      await _saveDescuento(0)
    } else {
      descuentoEditVal.value  = null
      descuentoEditOpen.value = true
    }
  }

  function openDescuentoEdit() {
    descuentoEditVal.value  = descuentoPorcentaje.value || null
    descuentoEditOpen.value = true
  }

  async function saveDescuento() {
    const v = Number(descuentoEditVal.value)
    if (v < 0 || v > 100) return
    await _saveDescuento(v)
  }

  async function _saveDescuento(valor) {
    savingDescuento.value = true
    try {
      await updatePaciente(socioId, { descuento_porcentaje: valor })
      await store.fetchOne(socioId)
      descuentoEditOpen.value = false
      toastOk(valor === 0 ? 'Descuento eliminado' : `Descuento de ${valor}% configurado`)
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al guardar descuento')
    } finally {
      savingDescuento.value = false
    }
  }

  async function onDispensacionCreada(activeTab) {
    store.fetchOne(socioId)
    cc.value = null
    if (activeTab === 'cuenta_corriente') await loadCC()
  }

  return {
    cc, loadingCC,
    // Crédito ARS
    limiteEditOpen, limiteEditVal, savingLimite,
    toggleLimite, openLimiteEdit, saveLimite,
    // Gramos
    togglingGramos,
    limiteGOpen, limiteGVal, savingLimiteG,
    cargarGOpen, cargarGVal, savingCargarG,
    toggleGramos, saveLimiteG, doCargarG,
    // Descuento
    descuentoPorcentaje, descuentoEditOpen, descuentoEditVal, savingDescuento,
    toggleDescuento, openDescuentoEdit, saveDescuento,
    // Utils
    fmtARS, ccDeudaActual, ccMargen, ccPorcentaje,
    loadCC, onDispensacionCreada,
  }
}
