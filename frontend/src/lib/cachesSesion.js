// LO QUE GUARDÓ EL SERVICE WORKER ES DE QUIEN TENÍA LA SESIÓN (29-oct-2026).
//
// El service worker guarda las respuestas de la API (padrón, fichas, dispensas) y las imágenes
// para mostrarlas sin señal. Son de la persona que estaba logueada: en una compu compartida del
// dispensario, el que se sienta después no las tiene que ver. Antes se borraban sólo con «Cerrar
// sesión»; si la sesión se vencía sola quedaban, y con señal floja la app le servía al siguiente
// lo del anterior. Ahora se borran en los tres momentos en que cambia la persona: al cerrar
// sesión, cuando la sesión se vence (el 401) y al entrar.
//
// Se borran los datos (`api-cache`) y las imágenes (`imagenes-*`: fotos subidas, documentos de
// pacientes). NO se borra el código: la cáscara (`workbox-precache-*`; borrarla con el service worker
// activo dejaba la app instalada sin abrir sin señal, 26-oct-2026) ni las pantallas (`codigo-*`):
// sin ellas, una pestaña con la versión anterior pide archivos que el deploy ya sacó del servidor y
// se rompe (29-oct-2026). El código no tiene nada de nadie.
//
// Con techo de tiempo al entrar: un login no puede quedar esperando al caché. Al cerrar sesión se
// espera entero (`techoMs: null`): la página se recarga después y no hay apuro.
const TECHO_MS = 1500
const CODIGO = ['workbox-precache', 'codigo-']

export async function borrarCachesDeSesion({ techoMs = TECHO_MS } = {}) {
  if (typeof caches === 'undefined') return
  const borrar = (async () => {
    try {
      const keys = await caches.keys()
      await Promise.all(keys.filter((k) => !CODIGO.some((c) => k.startsWith(c))).map((k) => caches.delete(k)))
    } catch { /* sin Cache Storage: no hay nada que borrar */ }
  })()
  if (techoMs == null) return borrar
  await Promise.race([borrar, new Promise((resolve) => setTimeout(resolve, techoMs))])
}
