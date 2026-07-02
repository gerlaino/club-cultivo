// Convierte la URL del logo del club en un data URL (base64) para EMBEBERLO en las
// ventanas de impresión (etiquetas/banderitas). Embebido = la etiqueta es autocontenida
// e imprime al instante, sin depender de que la red cargue la imagen a tiempo.
//
// Leer una imagen remota a base64 (fetch) requiere CORS; en dev anda, en prod con storage
// en la nube podría fallar. Si falla, devolvemos la URL cruda como fallback: un <img src=url>
// se muestra igual sin CORS (solo leer sus bytes lo necesita). Cacheado por URL.
let _cache = null

export async function logoDataUrl(url) {
  if (!url) return null
  if (_cache && _cache.url === url) return _cache.data

  try {
    const res  = await fetch(url)
    const blob = await res.blob()
    const data = await new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload  = () => resolve(reader.result)
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
    _cache = { url, data }
    return data
  } catch {
    return url // fallback: la URL directa (el <img> la muestra igual, sin CORS)
  }
}
