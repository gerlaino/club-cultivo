import { onMounted, onBeforeUnmount } from 'vue'

// SALIR DE UN MODAL CON ESCAPE.
//
// Los modales del mostrador dejaron de cerrarse al tocar afuera: ahí se cuenta plata y
// mercadería, y el click que se te va buscando el scroll borraba todo lo escrito sin preguntar.
// Pero un modal del que no se puede salir con el teclado es otro problema —y peor para quien no
// usa el mouse—, así que la salida deliberada queda: Cancelar o Escape.
//
// Vive acá y no copiado en cada modal por lo de siempre: cuatro copias de un listener sobre
// `document` son cuatro oportunidades de olvidarse de sacarlo al desmontar.
export function useEscape (alSalir) {
  const onKey = (e) => { if (e.key === 'Escape') alSalir() }
  onMounted(() => document.addEventListener('keydown', onKey))
  onBeforeUnmount(() => document.removeEventListener('keydown', onKey))
}
