import { ref } from 'vue'

// Una tarea de riego que dice CÓMO regar (receta, litros, pH, EC) no se cierra con un toque:
// «Hecho» abre «Completar tarea», que ofrece registrar el riego del lote o de la sala con eso
// precargado (12-oct-2026). Las tareas de riego sin parámetros, y las de otro tipo, siguen
// cerrándose con un toque como siempre.
//
// Uso: `if (pideRegistro(t)) return` al principio del «Hecho» de la pantalla, y montar
// `<ModalCompletarTarea :show="!!tareaRiego" :tarea="tareaRiego" @completada=… @cerrar="tareaRiego = null" />`.
const n = (x) => Number(x).toLocaleString('es-AR', { maximumFractionDigits: 2 })
// «Receta Flora 1 · 20 L · pH 6 · EC 1,6»: cómo regar, en una línea. Vacío si la tarea no lo dice.
export function resumenRiego(t) {
  const r = t?.riego
  if (!r) return ''
  return [r.receta ? `Receta ${r.receta.nombre}` : 'Agua sola', r.litros ? `${n(r.litros)} L` : null,
          r.ph != null ? `pH ${n(r.ph)}` : null, r.ec != null ? `EC ${n(r.ec)}` : null].filter(Boolean).join(' · ')
}

export const pideRegistroDeRiego = (t) => t?.tipo === 'riego' && !!t.riego && !!(t.lote || t.sala)

export function useCompletarRiego() {
  const tareaRiego = ref(null)
  function pideRegistro(t) {
    if (!pideRegistroDeRiego(t)) return false
    tareaRiego.value = t
    return true
  }
  return { tareaRiego, pideRegistro }
}
