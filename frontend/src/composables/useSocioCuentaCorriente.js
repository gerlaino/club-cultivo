import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { usePacientesStore } from '../stores/pacientes'
import { getCuentaCorriente, setLimiteCC, toggleGramosCC, setLimiteGCC, cargarGCC } from '../lib/api.js'

export function useSocioCuentaCorriente(socioId) {
  const { success: toastOk, error: toastErr } = useToast()
  const store = usePacientesStore()

  const cc             = ref(null)
  const loadingCC      = ref(false)
  const limiteEditOpen = ref(false)
  const limiteEditVal  = ref(null)
  const savingLimite   = ref(false)
  const togglingGramos = ref(false)
  const limiteGOpen    = ref(false)
  const limiteGVal     = ref(null)
  const savingLimiteG  = ref(false)
  const cargarGOpen    = ref(false)
  const cargarGVal     = ref(null)
  const savingCargarG  = ref(false)

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

  function openLimiteEdit() {
    limiteEditVal.value  = cc.value?.limite_credito ?? 0
    limiteEditOpen.value = true
  }

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
      toastOk('Límite en gramos actualizado')
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
      toastOk(`${gramos}g cargados`)
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al cargar')
    } finally {
      savingCargarG.value = false
    }
  }

  async function onDispensacionCreada(activeTab) {
    store.fetchOne(socioId)
    cc.value = null
    if (activeTab === 'cuenta_corriente') await loadCC()
  }

  return {
    cc, loadingCC,
    limiteEditOpen, limiteEditVal, savingLimite,
    togglingGramos,
    limiteGOpen, limiteGVal, savingLimiteG,
    cargarGOpen, cargarGVal, savingCargarG,
    fmtARS, ccDeudaActual, ccMargen, ccPorcentaje,
    openLimiteEdit, loadCC, saveLimite, toggleGramos, saveLimiteG, doCargarG,
    onDispensacionCreada,
  }
}
