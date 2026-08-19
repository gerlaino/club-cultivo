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
export const getPortalGaleria   = ()            => api.get('/portal/galeria').then(datos)
// Lo suyo: qué retiró y cuándo.
export const getPortalHistorial = ()            => api.get('/portal/historial').then(datos)

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
}
