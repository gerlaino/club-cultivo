// La puerta del paciente y el portal instalado en su teléfono (28-oct-2026, Germán: «las
// indicaciones para que instale la PWA para poder entrar al portal es fundamental»).
//
// · La PUERTA es `/paciente/<slug>` de su organización. Se recuerda en este teléfono para que, si
//   la sesión venció o cerró sesión, vuelva a la suya y no a la general (que no sabe de cuál es).
//   Es sólo el slug: no dice nada de su salud y es lo mismo que está impreso en el cartel.
// · El MANIFEST de la app instalada es el de su organización (`/api/portal_acceso/organizaciones/
//   <slug>/manifest`): se llama como ella y abre en su puerta. El de la app del equipo abre en `/m`.
// · El aviso de «instalá el portal» (Android) llega UNA vez al cargar la página, antes de que la
//   pantalla exista: se guarda acá.
import { ref } from 'vue'

const CLAVE_PUERTA = 'ce_puerta'

export function recordarPuerta(slug) {
  if (!slug) return
  try { localStorage.setItem(CLAVE_PUERTA, slug) } catch { /* sin almacenamiento: vuelve a la general */ }
}

export function puertaRecordada() {
  try { return localStorage.getItem(CLAVE_PUERTA) || null } catch { return null }
}

// La dirección a la que vuelve el paciente: la de su organización si este teléfono la conoce.
export function rutaDePuerta(slug = puertaRecordada()) {
  return slug ? `/paciente/${encodeURIComponent(slug)}` : '/paciente'
}

export const CLAVE_PUERTA_PORTAL = CLAVE_PUERTA

const API = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/$/, '')

// Cambia el manifest de la página por el de la organización, y el nombre que iOS le pone al ícono.
export function usarManifestDe(slug, nombre) {
  if (!slug || typeof document === 'undefined') return
  const href = `${API}/portal_acceso/organizaciones/${encodeURIComponent(slug)}/manifest`
  let link = document.querySelector('link[rel="manifest"]')
  if (!link) {
    link = document.createElement('link')
    link.rel = 'manifest'
    document.head.appendChild(link)
  }
  if (link.getAttribute('href') !== href) link.setAttribute('href', href)
  if (nombre) {
    const meta = document.querySelector('meta[name="apple-mobile-web-app-title"]')
    if (meta) meta.setAttribute('content', nombre)
  }
}

// El evento de instalación de Chrome/Android. `null` si no llegó (iOS nunca lo manda).
export const avisoInstalar = ref(null)

export function escucharInstalacion() {
  if (typeof window === 'undefined') return
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault()
    avisoInstalar.value = e
  })
  window.addEventListener('appinstalled', () => { avisoInstalar.value = null })
}
