// URL del WebSocket de ActionCable, derivada de la URL de la API.
//
// Soporta dos modos de VITE_API_URL:
//   - Absoluta  ("https://host/api")  → deriva el host de ahí.
//   - Relativa  ("/api")              → usa el ORIGEN ACTUAL (window.location), así el
//                                        cable siempre apunta al mismo dominio que sirve
//                                        la app. Esto evita el cross-site al cambiar de
//                                        dominio (basta con buildear con VITE_API_URL=/api).
export function cableUrl() {
  const apiBase = import.meta.env.VITE_API_URL || '/api'

  let root
  if (/^https?:\/\//i.test(apiBase)) {
    root = apiBase.replace(/\/api\/?$/, '')
  } else {
    root = window.location.origin // relativa → mismo origen que la página
  }

  const ws = root.replace(/^http/i, 'ws') // http→ws, https→wss
  return `${ws}/cable` // la cookie httpOnly viaja sola en el upgrade del WebSocket
}
