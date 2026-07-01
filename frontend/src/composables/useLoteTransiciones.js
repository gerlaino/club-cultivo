import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { useLotesStore } from '../stores/lotes'
import { usePlantsStore } from '../stores/plants'
import { useAuthStore } from '../stores/auth'
import { transicionarLote, avanzarFaseLote } from '../lib/api'

const ESTADO_META = {
  semilla:            { label: 'Germinación',        emoji: '🌱' },
  esqueje:            { label: 'Esqueje',            emoji: '🪴' },
  vegetativo:         { label: 'Vegetativo',         emoji: '🍃' },
  floracion:          { label: 'Floración',          emoji: '🌸' },
  cosecha:            { label: 'Cosecha',            emoji: '🌿' },
  en_manicura:        { label: 'En manicura',        emoji: '✂️'  },
  curado:             { label: 'Curado',             emoji: '🫙' },
  finalizado:         { label: 'Finalizado',         emoji: '✅' },
}
function em(e) { return ESTADO_META[e] || { label: e || '—', emoji: '•' } }

export function useLoteTransiciones(loteId, { onPhaseChange = null, sedes = null } = {}) {
  const toast  = useToast()
  const lotes  = useLotesStore()
  const plants = usePlantsStore()
  const auth   = useAuthStore()

  const isCultivador = computed(() => auth.role === 'cultivador')
  const canAdmin     = computed(() => ['admin', 'supervisor'].includes(auth.role))

  // ── Transición modal (admin/supervisor) ──────────────────
  const showTransicionModal = ref(false)
  const savingTransicion    = ref(false)
  const transicionError     = ref(null)
  const transicionForm      = ref({ peso_humedo_g: null, peso_seco_g: null, manicurado: false, notas: '' })
  const transicionSalaId    = ref(null)

  // ── Avanzar sala (cultivador) ─────────────────────────────
  const showAvanzarSalaModal  = ref(false)
  const avanzarSalaId         = ref(null)
  const transicionandoRapido  = ref(false)

  // ── Manicura (admin/supervisor) ───────────────────────────
  const showIniciarManicuraModal   = ref(false)
  const showCompletarManicuraModal = ref(false)

  // ── Cosecha (cultivador floración → cosecha) ──────────────
  const showCosechaModal = ref(false)
  const cosechaSalaId    = ref(null)
  const savingCosecha    = ref(false)
  const cosechaError     = ref(null)
  const cosechaForm      = ref({ plantas_cosechadas: null, notas: '' })

  // ── Cosecha parcial ───────────────────────────────────────
  const showCosechaPartialModal = ref(false)

  // ── Helpers ───────────────────────────────────────────────
  function capitalizarFase(f) {
    const LABELS = { vegetativo: 'Vegetativo', floracion: 'Floración', curado: 'Curado', cosecha: 'Cosecha', semilla: 'Germinación', manicura: 'Manicura', cerrado: 'Cerrado' }
    return LABELS[f] || (f ? f.charAt(0).toUpperCase() + f.slice(1) : '')
  }

  // ── Dispatch: qué modal abrir según fase y rol ────────────
  function openTransicionModal() {
    transicionForm.value   = { peso_humedo_g: null, peso_seco_g: null, manicurado: false, notas: '' }
    transicionError.value  = null
    transicionSalaId.value = lotes.current?.sala_id ?? null
    showTransicionModal.value = true
  }

  async function handleAvanzarFase() {
    const lote = lotes.current
    if (lote?.proxima_fase_posible === 'cosecha') {
      // La cosecha ya no requiere una sala de cosecha: es un evento → post-cosecha.
      if (!plants.itemsByLote[String(loteId)]) {
        try { await plants.fetchByLote(loteId) } catch {}
      }
      const plantList = plants.byLote(loteId)
      if (plantList.length > 0) {
        showCosechaPartialModal.value = true
      } else {
        cosechaForm.value  = { plantas_cosechadas: lote.plants_count || null, notas: '' }
        cosechaError.value = null
        cosechaSalaId.value = lote?.sala_id ?? null
        showCosechaModal.value = true
      }
    } else if (lote?.estado === 'cosecha' && canAdmin.value) {
      // Cosecha → manicura: se asigna un responsable (no hay fase 'secado').
      showIniciarManicuraModal.value = true
    } else if (isCultivador.value) {
      avanzarSalaId.value = lote?.sala_id ?? null
      showAvanzarSalaModal.value = true
    } else {
      openTransicionModal()
    }
  }

  // ── Ejecutar transición (admin) ───────────────────────────
  async function ejecutarTransicion() {
    const lote = lotes.current
    const faseSig = lote?.proxima_fase_posible
    if (!faseSig) return
    savingTransicion.value = true
    transicionError.value  = null
    try {
      const pesada = {}
      if (faseSig === 'curado') pesada.peso_seco_g = transicionForm.value.peso_seco_g
      if (transicionForm.value.notas) pesada.notas = transicionForm.value.notas
      const { data } = await transicionarLote(loteId, {
        nueva_fase: faseSig, pesada,
        sala_id: transicionSalaId.value || undefined,
      })
      lotes.current = data
      showTransicionModal.value = false
      toast.success(`Lote avanzado a ${em(faseSig).label}`)
      onPhaseChange?.()
      await plants.fetchByLote(loteId)
    } catch (e) {
      transicionError.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'Error al transicionar'
    } finally {
      savingTransicion.value = false
    }
  }

  // ── Avanzar rápido (cultivador) ───────────────────────────
  async function avanzarFaseRapido(salaId = null) {
    transicionandoRapido.value = true
    showAvanzarSalaModal.value = false
    try {
      const payload = salaId ? { sala_id: salaId } : {}
      const { data } = await avanzarFaseLote(lotes.current.id, payload)
      lotes.current = data
      toast.success(`Lote avanzado a ${capitalizarFase(data.estado)}`)
      onPhaseChange?.()
      await plants.fetchByLote(loteId)
    } catch (e) {
      const msg = e?.response?.data?.error || 'Error al avanzar el lote'
      if (e?.response?.status === 422) toast.warning(msg)
      else toast.error(msg)
    } finally {
      transicionandoRapido.value = false
    }
  }

  // ── Cosecha modal (cultivador) ────────────────────────────
  async function ejecutarCosecha() {
    if (!cosechaForm.value.plantas_cosechadas) return
    savingCosecha.value = true
    cosechaError.value  = null
    try {
      const { data } = await transicionarLote(lotes.current.id, {
        nueva_fase: 'cosecha',
        // La cosecha es un evento → post-cosecha, no se elige sala.
        pesada: {
          plantas_cosechadas: cosechaForm.value.plantas_cosechadas,
          notas: cosechaForm.value.notas || undefined,
        },
      })
      lotes.current = data
      showCosechaModal.value = false
      toast.success('Cosecha registrada')
      onPhaseChange?.()
      await plants.fetchByLote(loteId)
    } catch (e) {
      cosechaError.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'Error al registrar cosecha'
    } finally {
      savingCosecha.value = false
    }
  }

  // ── Cosecha parcial callback ──────────────────────────────
  function onCosechadoParcial(loteActualizado) {
    lotes.current = loteActualizado
    if (loteActualizado.plants?.length) {
      const stateById = Object.fromEntries(loteActualizado.plants.map(p => [p.id, p.state]))
      const current = plants.itemsByLote[String(loteId)] || []
      plants.itemsByLote[String(loteId)] = current.map(p =>
        p.id in stateById ? { ...p, state: stateById[p.id] } : p
      )
    }
    showCosechaPartialModal.value = false
    toast.success('Cosecha registrada')
    plants.fetchByLote(loteId)
    onPhaseChange?.()
  }

  // ── Manicura callbacks ────────────────────────────────────
  async function onManicuraIniciada(data) {
    lotes.current = data
    toast.success(`Lote ${data.codigo} — manicura iniciada`)
    onPhaseChange?.()
    await plants.fetchByLote(loteId)
  }

  async function onManicuraCompletada() {
    // El modal ahora crea un PesajeManicura enviado (no finaliza el lote): el admin lo
    // confirma desde Manicura y ahí se genera el stock.
    toast.success('Pesaje enviado a confirmar — el admin lo confirma y genera el stock')
    onPhaseChange?.()
  }

  return {
    // Transición
    showTransicionModal, savingTransicion, transicionError, transicionForm, transicionSalaId,
    // Avanzar sala
    showAvanzarSalaModal, avanzarSalaId, transicionandoRapido,
    // Manicura
    showIniciarManicuraModal, showCompletarManicuraModal,
    // Cosecha
    showCosechaModal, cosechaSalaId, savingCosecha, cosechaError, cosechaForm,
    // Cosecha parcial
    showCosechaPartialModal,
    // Methods
    handleAvanzarFase, openTransicionModal, ejecutarTransicion,
    avanzarFaseRapido, ejecutarCosecha, onCosechadoParcial,
    onManicuraIniciada, onManicuraCompletada,
  }
}
