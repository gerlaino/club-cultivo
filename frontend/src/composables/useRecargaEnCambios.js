// Para una pantalla que pide directo a la API (sin store): «cuando cambie X, volvé a cargar».
// Se desanota sola al desmontar. Agrupa y no pisa una carga en vuelo (ver `alCambiarAgrupado`).
//
//   useRecargaEnCambios(['stocks', 'mostrador'], cargar)
//   useRecargaEnCambios('lotes', cargar, { filtro: ev => ev.id === Number(route.params.id) })
import { onBeforeUnmount } from 'vue'
import { alCambiarAgrupado } from '../lib/cambios.js'

export function useRecargaEnCambios(recursos, recargar, opciones = {}) {
  const soltar = alCambiarAgrupado(recursos, recargar, opciones)
  onBeforeUnmount(soltar)
  return soltar
}
