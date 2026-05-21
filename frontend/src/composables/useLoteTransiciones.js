import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { useLotesStore } from '../stores/lotes'
import { usePlantsStore } from '../stores/plants'
import { useAuthStore } from '../stores/auth'
import { transicionarLote, avanzarFaseLote, cerrarCurado, getSedeStocks } from '../lib/api'

const ESTADO_META = {
  semilla:            { label: 'Semilla/Esqueje',   emoji: '🌱' },
  vegetativo:         { label: 'Vegetativo',         emoji: '🍃' },
  floracion:          { label: 'Floración',          emoji: '🌸' },
  cosecha:            { label: 'Cosecha',            emoji: '🌿' },
  secado:             { label: 'Manicura',           emoji: '✂️'  },
  manicura_pendiente: { label: 'Manicura pendiente', emoji: '✂️'  },
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

  // ── Cerrar curado ─────────────────────────────────────────
  const showCerrarCuradoModal = ref(false)
  const savingCurado          = ref(false)
  const curadoError           = ref(null)
  const curadoForm            = ref({ peso_curado_g: null, flor_seca: null, descarte: null, sede_destino_id: null, costo_unitario_ars: null, precio_sugerido_ars: null })

  const pesadaUltimaCurado = computed(() => {
    if (!lotes.current?.pesadas) return null
    return [...lotes.current.pesadas].reverse().find(p => p.fase_destino === 'curado') || null
  })

  const splitOk = computed(() => {
    const f = curadoForm.value
    if (!f.peso_curado_g) return false
    const sum = (parseFloat(f.flor_seca) || 0) + (parseFloat(f.descarte) || 0)
    return Math.abs(sum - parseFloat(f.peso_curado_g)) < 0.01
  })

  // ── Helpers ───────────────────────────────────────────────
  function capitalizarFase(f) {
    const LABELS = { vegetativo: 'Vegetativo', floracion: 'Floración', secado: 'Manicura', curado: 'Curado', cosecha: 'Cosecha', semilla: 'Germinación', manicura: 'Manicura', cerrado: 'Cerrado' }
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
    } else if (lote?.proxima_fase_posible === 'secado' && canAdmin.value) {
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
      if (faseSig === 'secado') {
        pesada.peso_humedo_g = transicionForm.value.peso_humedo_g
        pesada.manicurado    = transicionForm.value.manicurado
      }
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
        sala_id: cosechaSalaId.value || undefined,
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

  async function onManicuraCompletada(data) {
    lotes.current = data
    toast.success(`Lote ${data.codigo} — manicura completada y stock generado`)
    onPhaseChange?.()
  }

  // ── Cerrar curado ─────────────────────────────────────────
  async function openCerrarCuradoModal() {
    const sedeId = sedes?.value?.[0]?.id || null
    curadoForm.value = {
      peso_curado_g:       pesadaUltimaCurado.value?.peso_curado_g || null,
      flor_seca:           null,
      descarte:            null,
      sede_destino_id:     sedeId,
      costo_unitario_ars:  null,
      precio_sugerido_ars: null,
    }
    curadoError.value           = null
    showCerrarCuradoModal.value = true
    if (sedeId) {
      try {
        const { data } = await getSedeStocks(sedeId, { canal: 'regulatorio' })
        const stocks = (data || []).filter(s => s.forma_producto === 'flor_seca' && s.precio_sugerido_ars != null)
        if (stocks.length) {
          const ultimo = stocks.reduce((a, b) => (b.id > a.id ? b : a))
          curadoForm.value.precio_sugerido_ars = parseFloat(ultimo.precio_sugerido_ars)
        }
      } catch {}
    }
  }

  async function ejecutarCerrarCurado() {
    savingCurado.value = true
    curadoError.value  = null
    try {
      const { data } = await cerrarCurado(loteId, {
        peso_curado_g:       curadoForm.value.peso_curado_g,
        splitter:            { flor_seca: curadoForm.value.flor_seca, descarte: curadoForm.value.descarte },
        sede_destino_id:     curadoForm.value.sede_destino_id,
        costo_unitario_ars:  curadoForm.value.costo_unitario_ars,
        precio_sugerido_ars: curadoForm.value.precio_sugerido_ars,
      })
      lotes.current           = data.lote
      showCerrarCuradoModal.value = false
      toast.success('Curado cerrado. Stock generado exitosamente.')
      onPhaseChange?.()
    } catch (e) {
      curadoError.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'Error al cerrar curado'
    } finally {
      savingCurado.value = false
    }
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
    // Cerrar curado
    showCerrarCuradoModal, savingCurado, curadoError, curadoForm, splitOk, pesadaUltimaCurado,
    // Methods
    handleAvanzarFase, openTransicionModal, ejecutarTransicion,
    avanzarFaseRapido, ejecutarCosecha, onCosechadoParcial,
    onManicuraIniciada, onManicuraCompletada,
    openCerrarCuradoModal, ejecutarCerrarCurado,
  }
}
