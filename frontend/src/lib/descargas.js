import api from './api.js'

// Bajar un archivo que genera el servidor (PDF / Excel), en UN solo lugar.
//
// Estaba escrito cuatro veces —el composable de informes y tres vistas— y sólo una tenía la
// parte que importa: LEER EL MOTIVO DEL RECHAZO. Con `responseType: 'blob'` el cuerpo del error
// TAMBIÉN llega como blob, así que ni el interceptor de `api.js` puede normalizarlo, y las tres
// copias hacían `catch {}` y mostraban "No se pudo generar el PDF. Reintentá en un momento."
// sobre un 422 que decía exactamente qué hacer. Es el peor mensaje posible: invita a reintentar
// algo que no va a andar nunca y hace que parezca culpa del usuario.

// El motivo real que mandó el backend, o null si no mandó ninguno.
export async function leerErrorDeBlob (e) {
  const data = e?.response?.data
  if (!data) return null
  try {
    const json = typeof data.text === 'function' ? JSON.parse(await data.text()) : data
    if (!json?.error) return null
    const faltan = json.geneticas_sin_declarar
    return faltan?.length ? `${json.error} Faltan: ${faltan.join(', ')}.` : json.error
  } catch {
    return null
  }
}

export function bajarBlob (data, filename) {
  const url  = URL.createObjectURL(new Blob([data]))
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

// Descarga y guarda. Si falla, lanza un Error cuyo `message` ya es lo que hay que mostrarle a
// la persona, y `conMotivo` dice si vino del backend o es el genérico.
export async function descargarArchivo (url, { params = {}, filename } = {}) {
  try {
    const { data } = await api.get(url, { params, responseType: 'blob' })
    bajarBlob(data, filename)
  } catch (e) {
    const motivo = await leerErrorDeBlob(e)
    const err = new Error(motivo || 'No se pudo generar el archivo. Reintentá en un momento.')
    err.conMotivo = Boolean(motivo)
    throw err
  }
}
