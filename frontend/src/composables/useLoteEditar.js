import { ref } from 'vue'
import { useToast } from './useToast.js'
import { useLotesStore } from '../stores/lotes'
import { updateLote, listGeneticas } from '../lib/api'

export function useLoteEditar(loteId) {
  const toast = useToast()
  const lotes = useLotesStore()

  const geneticas      = ref([])
  const showEditLote   = ref(false)
  const editLoteForm   = ref({})
  const editLoteError  = ref(null)
  const savingEditLote = ref(false)

  async function cargarGeneticas() {
    try {
      const { data } = await listGeneticas({ activa: true, disponible: true })
      geneticas.value = data || []
    } catch {}
  }

  function openEditLote() {
    const l = lotes.current
    editLoteForm.value = {
      codigo:            l.codigo            || '',
      estado:            l.estado            || '',
      plants_count:      l.plants_count      ?? null,
      start_date:        l.start_date        || '',
      fecha_vegetativo:  l.fecha_inicio_vegetativo || '',
      fecha_floracion:   l.fecha_inicio_floracion  || '',
      fecha_cosecha:     l.fecha_cosechado          || '',
      genetica_id:       l.genetica?.id      || '',
      grow_type:         l.grow_type         || '',
      light_type:        l.light_type        || '',
      // Los días objetivo NO se editan acá: son de la GENÉTICA (una Lemon florece lo que florece,
      // no lo que decida un lote). El lote guarda su copia como foto del momento en que se creó
      // —cambiar la genética después no puede reescribir la historia de un ciclo ya corrido— y el
      // backend la hereda solo. Editarlos por lote era la puerta para que dos lotes de la misma
      // variedad tuvieran objetivos distintos sin ninguna razón.
      // El backend serializa decimal(4,1) como "5.0"; el <select> usa "5". Normalizar para que matchee.
      tamanio_maceta:    l.tamanio_maceta != null && l.tamanio_maceta !== '' ? String(parseFloat(l.tamanio_maceta)) : '',
      notes:             l.notes             || '',
    }
    editLoteError.value = null
    showEditLote.value  = true
  }

  async function saveEditLote() {
    savingEditLote.value = true
    editLoteError.value  = null
    try {
      // Las fechas de fase NO son columnas del lote: van aparte y el backend reconcilia los eventos.
      const { codigo, fecha_vegetativo, fecha_floracion, fecha_cosecha, ...rest } = editLoteForm.value
      const payload = {
        ...rest,
        // '' = bandeja de enraizado (el que enraíza no tiene maceta). Va como null, no como 0.
        tamanio_maceta:    rest.tamanio_maceta || null,
      }
      if (!payload.genetica_id) delete payload.genetica_id
      if (!payload.light_type)  delete payload.light_type
      const fechas_fase = {}
      if (fecha_vegetativo) fechas_fase.vegetativo = fecha_vegetativo
      if (fecha_floracion)  fechas_fase.floracion  = fecha_floracion
      if (fecha_cosecha)    fechas_fase.cosecha     = fecha_cosecha
      await updateLote(loteId, payload, Object.keys(fechas_fase).length ? { fechas_fase } : {})
      await lotes.fetchOne(loteId)
      showEditLote.value = false
      toast.success('Lote actualizado')
    } catch (e) {
      editLoteError.value = e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'Error al guardar'
    } finally {
      savingEditLote.value = false
    }
  }

  return {
    geneticas, showEditLote, editLoteForm, editLoteError, savingEditLote,
    cargarGeneticas, openEditLote, saveEditLote,
  }
}
