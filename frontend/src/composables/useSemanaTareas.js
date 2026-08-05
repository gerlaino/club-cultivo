import { computed, unref } from 'vue'

const toISO = (d) => new Date(d).toISOString().slice(0, 10)

/**
 * La semana de trabajo tal como se lee: una tarea que venció y sigue pendiente NO se queda en
 * el día en que estaba programada, se arrastra a HOY marcada como atrasada. Es la diferencia
 * entre un calendario ("qué había planeado el martes") y una bandeja de trabajo ("qué tengo que
 * hacer"), y para quien está en la sala sirve la segunda.
 *
 * Estaba implementado sólo en el dashboard de escritorio: la vista mobile mostraba el día
 * literal, así que 19 tareas atrasadas quedaban escondidas en su día y hoy aparecía vacío.
 *
 * @param {Ref<{dias: Array}>} semana  respuesta del store de tareas
 * @returns { dias, tareasDeHoy, totalPendientes, hoyISO }
 */
export function useSemanaTareas(semana) {
  const hoyISO = toISO(new Date())

  const pendiente = (t) => t.estado !== 'completada' && t.estado !== 'cancelada'

  const dias = computed(() => {
    const raw = unref(semana)?.dias
    if (!raw?.length) return []

    const out = raw.map(d => ({ ...d, tareas: [...(d.tareas || [])] }))
    const hoyIdx = out.findIndex(d => d.fecha === hoyISO)
    if (hoyIdx <= 0) return out

    for (let i = 0; i < hoyIdx; i++) {
      const atrasadas = out[i].tareas.filter(pendiente)
      // unshift: lo atrasado va PRIMERO, así el plegado de la columna esconde lo menos urgente.
      atrasadas.forEach(t => out[hoyIdx].tareas.unshift({ ...t, _atrasada: true }))
      out[i] = { ...out[i], tareas: out[i].tareas.filter(t => !pendiente(t)) }
    }
    return out
  })

  const tareasDeHoy = computed(() =>
    dias.value.find(d => d.fecha === hoyISO)?.tareas.filter(pendiente) || [])

  const totalPendientes = computed(() =>
    dias.value.reduce((acc, d) => acc + d.tareas.filter(pendiente).length, 0))

  return { dias, tareasDeHoy, totalPendientes, hoyISO }
}
