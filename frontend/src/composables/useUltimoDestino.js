// EL ÚLTIMO FRASCO DEL LOTE (Germán, 30-oct-2026). Quien pesa planta por planta con el QR manda casi
// todo al mismo frasco: si cada escaneo arrancara en «Frasco nuevo», había que elegirlo treinta veces,
// y un registrar distraído creaba un frasco por planta. Se recuerda, por persona y por lote, adónde fue
// la planta anterior (el frasco que nació con ella pasa a ser «uno que ya existe»; un reparto se
// recuerda con sus frascos y sin los gramos). Vive en este navegador: es una comodidad, no un dato.
// `DestinoFrascos` lo descarta solo si ese frasco ya no está entre los del lote.
import { destinoVacio } from '../components/manicura/DestinoFrascos.vue'

const clave = (userId, loteId) => `ce:ultimo-frasco:${userId}:${loteId}`

function leerCrudo(userId, loteId) {
  try { return localStorage.getItem(clave(userId, loteId)) } catch { return null }
}
function escribirCrudo(userId, loteId, valor) {
  try {
    if (valor == null) localStorage.removeItem(clave(userId, loteId))
    else localStorage.setItem(clave(userId, loteId), valor)
  } catch { /* sin almacenamiento: arranca en «Frasco nuevo», como antes */ }
}

// El destino con el que arranca el próximo pesaje de ese lote, o null.
export function leerUltimoDestino(userId, loteId) {
  if (!userId || !loteId) return null
  try {
    const v = JSON.parse(leerCrudo(userId, loteId) || 'null')
    if (!v || (!v.stock_id && !(v.repartir && v.reparto?.length))) return null
    return { ...destinoVacio(), ...v, recordado: true }
  } catch { return null }
}

// Guarda adónde fue este pesaje. `stockIds` son los frascos que devolvió el backend, en el orden del
// reparto (los nuevos ya tienen número). Devuelve lo que había, para poder volver atrás al deshacer.
export function guardarUltimoDestino(userId, loteId, destino, stockIds = []) {
  if (!userId || !loteId || !destino) return null
  const previo = leerCrudo(userId, loteId)
  const ids = stockIds || []
  const v = destino.repartir
    ? { repartir: true, reparto: destino.reparto.map((f, i) => ({ stock_id: f.stock_id || ids[i] || null, descripcion: f.descripcion || '', calidad: f.calidad || '', gramos: null })) }
    : { stock_id: destino.stock_id || ids[0] || null }
  escribirCrudo(userId, loteId, JSON.stringify(v))
  return previo
}

// Vuelve a lo que había antes de un pesaje que se deshizo.
export function restaurarUltimoDestino(userId, loteId, previo) {
  escribirCrudo(userId, loteId, previo ?? null)
}
