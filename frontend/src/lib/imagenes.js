// Achicar una foto ANTES de subirla.
//
// Una foto del teléfono pesa 3–6 MB y la galería la muestra de 120 px: se guardaba entera y se
// bajaba entera cada vez. Acá se lleva a 1600 px de lado mayor y JPEG al 82 %, que es más de lo
// que cualquier pantalla de la app llega a mostrar y deja una foto de ~250 KB: diez veces menos
// de subida, de bajada y de bucket. Es la primera capa del ahorro; el tope de fotos del plan
// (`PlanEnforcer`) es la segunda, y las miniaturas en el servidor quedaron para más adelante.
//
// Si el navegador no puede (formato raro, sin canvas), devuelve el archivo original: subir la
// foto grande es mejor que no subirla. Las que ya son chicas pasan tal cual.
const LADO_MAX = 1600
const CALIDAD  = 0.82
const YA_CHICA = 350 * 1024

export async function achicarImagen(archivo, { lado = LADO_MAX, calidad = CALIDAD } = {}) {
  if (!archivo || !archivo.type?.startsWith('image/')) return archivo
  if (archivo.size <= YA_CHICA) return archivo
  if (typeof createImageBitmap !== 'function' || typeof document === 'undefined') return archivo

  try {
    // `imageOrientation: 'from-image'` respeta el EXIF: sin esto, una foto vertical del teléfono
    // quedaba acostada al pasar por el canvas.
    const bitmap = await createImageBitmap(archivo, { imageOrientation: 'from-image' })
    const escala = Math.min(1, lado / Math.max(bitmap.width, bitmap.height))
    if (escala === 1 && archivo.type === 'image/jpeg') { bitmap.close?.(); return archivo }

    const canvas = document.createElement('canvas')
    canvas.width  = Math.round(bitmap.width  * escala)
    canvas.height = Math.round(bitmap.height * escala)
    canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    bitmap.close?.()

    const blob = await new Promise(res => canvas.toBlob(res, 'image/jpeg', calidad))
    if (!blob || blob.size >= archivo.size) return archivo
    const nombre = (archivo.name || 'foto').replace(/\.[^.]+$/, '') + '.jpg'
    return new File([blob], nombre, { type: 'image/jpeg', lastModified: archivo.lastModified || Date.now() })
  } catch {
    return archivo
  }
}
