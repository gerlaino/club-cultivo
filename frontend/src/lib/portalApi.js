// Lo que la organización le muestra a SUS MIEMBROS.
//
// Vivía en `web-publica/`, un proyecto Vite aparte que pegaba a `/public/*` sin credenciales.
// Nunca funcionó multi-club — el backend resolvía el club con `Club.first` — así que cualquiera
// que supiera la URL leía el catálogo de la organización #1. Ahora es todo autenticado y el club
// sale del usuario logueado: estas llamadas usan la misma instancia de axios que el resto de la
// app, con la cookie de sesión.
import api from './api'

const datos = (r) => r.data?.data ?? r.data

export const getPortalClub      = ()            => api.get('/portal/club').then(r => r.data)
export const getPortalGeneticas = ()            => api.get('/portal/geneticas').then(datos)
export const getPortalGenetica  = (id)          => api.get(`/portal/geneticas/${id}`).then(datos)
export const getPortalNoticias  = ()            => api.get('/portal/noticias').then(datos)
export const getPortalNoticia   = (id)          => api.get(`/portal/noticias/${id}`).then(datos)
export const getPortalEventos   = (pasados = false) =>
  api.get('/portal/eventos', { params: pasados ? { pasados: true } : {} }).then(datos)
export const getPortalEvento    = (id)          => api.get(`/portal/eventos/${id}`).then(datos)
// «Asistiré» (27-oct-2026): marcar que va, o que ya no.
export const asistirEvento      = (id)          => api.post(`/portal/eventos/${id}/asistencia`).then(datos)
export const noAsistirEvento    = (id)          => api.delete(`/portal/eventos/${id}/asistencia`).then(datos)
export const getPortalGaleria   = ()            => api.get('/portal/galeria').then(datos)
// Lo suyo: qué retiró y cuándo.
export const getPortalHistorial = ()            => api.get('/portal/historial').then(datos)
// Una dispensa suya, con la trazabilidad de cada frasco (27-oct-2026).
export const getPortalDispensa  = (id)          => api.get(`/portal/historial/${id}`).then(datos)
// El chat con la organización (27-oct-2026). Devuelve `{ data, conversacion, sin_leer }`.
export const getPortalMensajes    = ()            => api.get('/portal/mensajes').then(r => r.data)
// `{ texto, archivo, dispensacionId }`: con archivo va como formulario (multipart).
export const enviarPortalMensaje  = ({ texto, archivo, dispensacionId }) => {
  if (!archivo) return api.post('/portal/mensajes', { texto, dispensacion_id: dispensacionId || undefined }).then(datos)
  const fd = new FormData()
  if (texto) fd.append('texto', texto)
  if (dispensacionId) fd.append('dispensacion_id', dispensacionId)
  fd.append('adjunto', archivo)
  return api.post('/portal/mensajes', fd, { timeout: 60000, headers: { 'Content-Type': 'multipart/form-data' } }).then(datos)
}
export const marcarPortalMensajesLeidos = ()      => api.post('/portal/mensajes/leidos')
// Sus papeles: el REPROCANN y la constancia de renovación que sube él (27-oct-2026).
export const getPortalPapeles = () => api.get('/portal/papeles').then(datos)
// Lo que hay hoy sobre la mesa de cada sede (27-oct-2026).
export const getPortalCatalogo = () => api.get('/portal/catalogo').then(datos)
export const subirRenovacionReprocann = (archivo) => {
  const fd = new FormData()
  fd.append('constancia', archivo)
  return api.post('/portal/papeles/renovacion', fd, { timeout: 60000, headers: { 'Content-Type': 'multipart/form-data' } }).then(datos)
}
// Su cuenta corriente, si la organización se la abrió. Devuelve `{ tiene: false }` si no.
export const getPortalCuentaCorriente = ()      => api.get('/portal/cuenta_corriente').then(datos)
// Su credencial y lo que hay que decirle antes de que scrollee: alimenta el inicio y la franja.
export const getPortalMiEstado  = ()            => api.get('/portal/mi_estado').then(datos)
// Lo clínico suyo: próximo turno e indicación vigente. Devuelve `{ tiene_modulo: false }` si la
// organización no tiene el módulo médico.
export const getPortalMiSalud   = ()            => api.get('/portal/mi_salud').then(datos)

// Compatibilidad con las vistas mudadas, que llamaban `publicApi.getGeneticas()`.
export default {
  getClub:      getPortalClub,
  getGeneticas: getPortalGeneticas,
  getGenetica:  getPortalGenetica,
  getNoticias:  getPortalNoticias,
  getNoticia:   getPortalNoticia,
  getEventos:   getPortalEventos,
  getEvento:    getPortalEvento,
  getGaleria:   getPortalGaleria,
  getHistorial: getPortalHistorial,
  getCuentaCorriente: getPortalCuentaCorriente,
  getMiEstado: getPortalMiEstado,
  getMiSalud: getPortalMiSalud,
}
