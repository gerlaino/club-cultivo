import { ref } from 'vue'
import { useToast } from './useToast.js'
import { enviarMailPaciente, getMailsPaciente } from '../lib/api.js'

export const MAIL_TEMPLATES = [
  {
    key: 'bienvenida',
    label: 'Bienvenida',
    icon: '🌿',
    asunto: (p, club) => `Bienvenido/a a ${club}`,
    cuerpo:  (p)       => `Hola ${p.nombre},\n\nTe damos la bienvenida como paciente de nuestro club.\n\nEstamos a tu disposición para cualquier consulta.\n\nSaludos,`,
  },
  {
    key: 'reprocann',
    label: 'REPROCANN',
    icon: '📋',
    asunto: (p)  => `Renovación de REPROCANN — ${p.nombre} ${p.apellido}`,
    cuerpo:  (p) => {
      const venc = p.reprocann_vencimiento
        ? new Date(p.reprocann_vencimiento).toLocaleDateString('es-AR')
        : 'próximamente'
      return `Hola ${p.nombre},\n\nTe recordamos que tu habilitación REPROCANN vence el ${venc}.\n\nPor favor comunicate con nosotros para gestionar la renovación antes de esa fecha.\n\nSaludos,`
    },
  },
  {
    key: 'disponibilidad',
    label: 'Disponibilidad',
    icon: '📦',
    asunto: (p)  => `Aviso de disponibilidad — ${p.nombre} ${p.apellido}`,
    cuerpo:  (p) => `Hola ${p.nombre},\n\nTe informamos que hay producto disponible para tu retiro.\n\nPodés pasar a retirar en los horarios habituales. Ante cualquier duda no dudes en contactarnos.\n\nSaludos,`,
  },
  {
    key: 'personalizado',
    label: 'Libre',
    icon: '✏️',
    asunto: () => '',
    cuerpo:  () => '',
  },
]

export function useSocioCorreo(socioId, { s }) {
  const { success: toastOk, error: toastErr } = useToast()

  const mailHistory  = ref([])
  const mailLoading  = ref(false)
  const mailSending  = ref(false)
  const mailPreview  = ref(false)
  const mailTemplate = ref('personalizado')
  const mailForm     = ref({ asunto: '', cuerpo: '' })

  function applyMailTemplate(key) {
    mailTemplate.value = key
    const tpl = MAIL_TEMPLATES.find(t => t.key === key)
    if (!tpl || !s.value) return
    const clubName = s.value.club_nombre || ''
    mailForm.value.asunto = tpl.asunto(s.value, clubName)
    mailForm.value.cuerpo = tpl.cuerpo(s.value, clubName)
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
      const { data } = await enviarMailPaciente(socioId, {
        tipo:   mailTemplate.value,
        asunto: mailForm.value.asunto.trim(),
        cuerpo: mailForm.value.cuerpo.trim(),
      })
      mailHistory.value = [data, ...mailHistory.value]
      mailForm.value     = { asunto: '', cuerpo: '' }
      mailTemplate.value = 'personalizado'
      mailPreview.value  = false
      toastOk('Mail enviado correctamente')
    } catch (e) {
      toastErr(e?.response?.data?.error || 'Error al enviar el mail')
    } finally {
      mailSending.value = false
    }
  }

  return {
    MAIL_TEMPLATES,
    mailHistory, mailLoading, mailSending, mailPreview, mailTemplate, mailForm,
    applyMailTemplate, loadMailHistory, submitMail,
  }
}
