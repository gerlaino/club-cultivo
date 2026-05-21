import { ref, computed } from 'vue'
import { logger } from '../utils/logger.js'
import { useToast } from './useToast.js'
import { useConfirm } from './useConfirm.js'
import { getLoteFotos, uploadFotoLote, deleteFotoLote } from '../lib/api'

export function useLoteFotos(loteId) {
  const toast   = useToast()
  const { confirm } = useConfirm()

  const fotos             = ref([])
  const uploadingFoto     = ref(false)
  const fotoInput         = ref(null)
  const showFotoUploadModal   = ref(false)
  const fotoUploadFile        = ref(null)
  const fotoUploadDescripcion = ref('')
  const fotoUploadPreview     = ref(null)
  const fotosExpanded     = ref(false)
  const lightboxOpen      = ref(false)
  const lightboxIndex     = ref(0)

  const lightboxImages = computed(() => fotos.value.map(f => ({ src: f.url, alt: f.filename })))

  function openLightbox(i) {
    lightboxIndex.value = i
    lightboxOpen.value  = true
  }

  async function loadFotos() {
    try {
      const { data } = await getLoteFotos(loteId)
      fotos.value = data || []
    } catch {
      fotos.value = []
    }
  }

  function toggleFotos() {
    fotosExpanded.value = !fotosExpanded.value
    if (fotosExpanded.value && fotos.value.length === 0) loadFotos()
  }

  function handleFotoSelect(e) {
    const file = e.target.files?.[0]
    if (!file) return
    fotoUploadFile.value        = file
    fotoUploadDescripcion.value = ''
    fotoUploadPreview.value     = URL.createObjectURL(file)
    showFotoUploadModal.value   = true
    if (fotoInput.value) fotoInput.value.value = ''
  }

  async function confirmarSubidaFoto() {
    if (!fotoUploadFile.value) return
    uploadingFoto.value = true
    try {
      const fd = new FormData()
      fd.append('foto', fotoUploadFile.value)
      if (fotoUploadDescripcion.value.trim()) fd.append('descripcion', fotoUploadDescripcion.value.trim())
      const { data } = await uploadFotoLote(loteId, fd)
      fotos.value.unshift(data)
      showFotoUploadModal.value   = false
      fotoUploadFile.value        = null
      fotoUploadPreview.value     = null
      fotoUploadDescripcion.value = ''
    } catch (err) {
      logger.error(err)
      toast.error('Error al subir la foto')
    } finally {
      uploadingFoto.value = false
    }
  }

  function cancelarSubidaFoto() {
    showFotoUploadModal.value   = false
    fotoUploadFile.value        = null
    fotoUploadPreview.value     = null
    fotoUploadDescripcion.value = ''
  }

  async function eliminarFoto(foto) {
    const ok = await confirm({
      title: 'Eliminar foto',
      message: '¿Seguro que querés eliminar esta foto? No se puede deshacer.',
      confirmText: 'Eliminar',
      variant: 'danger',
    })
    if (!ok) return
    try {
      await deleteFotoLote(loteId, foto.id)
      fotos.value = fotos.value.filter(f => f.id !== foto.id)
      toast.success('Foto eliminada')
    } catch {
      toast.error('Error al eliminar la foto')
    }
  }

  return {
    fotos, uploadingFoto, fotoInput,
    showFotoUploadModal, fotoUploadFile, fotoUploadDescripcion, fotoUploadPreview,
    fotosExpanded, lightboxOpen, lightboxIndex, lightboxImages,
    loadFotos, toggleFotos, openLightbox,
    handleFotoSelect, confirmarSubidaFoto, cancelarSubidaFoto, eliminarFoto,
  }
}
