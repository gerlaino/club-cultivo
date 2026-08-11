import { ref } from 'vue'
import { useToast } from './useToast.js'
import {
  getMailsPaciente, enviarMailPaciente, fetchPlantillasMail,
} from '../lib/api.js'

// Las plantillas ya NO viven acá. Eran cuatro textos hardcodeados en el frontend, con el
// agravante de que el backend validaba sus nombres en `MailEnviado::TIPOS`: la plantilla de un
// lado y su validación del otro. Ahora son de cada organización y las edita su admin en
// Configuración → Correo electrónico.
//
// Queda la opción de escribir libre, que no es una plantilla sino su ausencia.
export const MAIL_LIBRE = { id: null, nombre: 'Escribir libre', asunto: '', cuerpo: '' }

export function useSocioCorreo(socioId, { s }) {
  const { success: toastOk, error: toastErr } = useToast()

  const mailHistory   = ref([])
  const mailLoading   = ref(false)
  const mailSending   = ref(false)
  const mailPreview   = ref(false)
  const plantillas    = ref([])
  const mailPlantilla = ref(null)   // id de la plantilla elegida, o null = libre
  const mailForm      = ref({ asunto: '', cuerpo: '' })

  // Las variables las resuelve el backend al renderizar la plantilla; acá se resuelven sólo para
  // que lo que el usuario ve en el formulario sea LO QUE SE MANDA. Si el reemplazo se hiciera
  // sólo del lado del servidor, el operador editaría un texto con llaves y recibiría otro.
  function resolver(texto) {
    const p = s.value || {}
    const mapa = {
      nombre:                p.nombre || '',
      apellido:              p.apellido || '',
      nombre_completo:       [p.nombre, p.apellido].filter(Boolean).join(' '),
      organizacion:          p.club_nombre || '',
      reprocann_numero:      p.reprocann_numero || '',
      reprocann_vencimiento: p.reprocann_vencimiento
        ? new Date(p.reprocann_vencimiento).toLocaleDateString('es-AR')
        : '',
    }
    return String(texto || '').replace(/\{\{\s*([a-z_]+)\s*\}\}/g,
      (crudo, clave) => (mapa[clave] !== undefined ? mapa[clave] : crudo))
  }

  function aplicarPlantilla(id) {
    mailPlantilla.value = id
    if (id === null) {
      mailForm.value = { asunto: '', cuerpo: '' }
      return
    }
    const tpl = plantillas.value.find(p => p.id === id)
    if (!tpl) return
    mailForm.value = { asunto: resolver(tpl.asunto), cuerpo: resolver(tpl.cuerpo) }
  }

  async function cargarPlantillas() {
    try {
      const { data } = await fetchPlantillasMail()
      // Sólo las activas: una apagada existe pero no se ofrece para enviar.
      plantillas.value = (data.data || []).filter(p => p.activa)
    } catch {
      // Sin módulo de correo o sin permiso: se puede escribir libre igual.
      plantillas.value = []
    }
  }

  async function loadMailHistory() {
    mailLoading.value = true
    try {
      const { data } = await getMailsPaciente(socioId)
      mailHistory.value = data
    } catch {
      mailHistory.value = []
    } finally {
      mailLoading.value = false
    }
  }

  async function submitMail() {
    if (!mailForm.value.asunto.trim() || !mailForm.value.cuerpo.trim()) return
    mailSending.value = true
    try {
      const elegida = plantillas.value.find(p => p.id === mailPlantilla.value)
      const { data } = await enviarMailPaciente(socioId, {
        // `tipo` es la clasificación gruesa que guarda `mails_enviados`; la plantilla concreta
        // va aparte, en `plantilla_mail_id`.
        tipo:              elegida?.bienvenida ? 'bienvenida' : 'personalizado',
        plantilla_mail_id: mailPlantilla.value,
        asunto:            mailForm.value.asunto.trim(),
        cuerpo:            mailForm.value.cuerpo.trim(),
      })
      mailHistory.value   = [data, ...mailHistory.value]
      mailForm.value      = { asunto: '', cuerpo: '' }
      mailPlantilla.value = null
      mailPreview.value   = false
      toastOk('Mail enviado correctamente')
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al enviar el mail')
    } finally {
      mailSending.value = false
    }
  }

  return {
    MAIL_LIBRE,
    mailHistory, mailLoading, mailSending, mailPreview, mailPlantilla, mailForm, plantillas,
    aplicarPlantilla, cargarPlantillas, loadMailHistory, submitMail,
  }
}
