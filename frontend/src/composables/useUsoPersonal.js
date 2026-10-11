// ¿Esta cuenta es de un cultivador de casa?
//
// La regla vive en el backend (`Club#personal?`, derivada del plan) y viaja en `/preferences`
// como `personal`. Acá se lee UNA vez para todo el frontend: el menú, el envoltorio del
// teléfono, el inicio y el vocabulario preguntan esto, y si cada pantalla lo dedujera por su
// cuenta (por el plan, por las features) un día dirían distinto.
//
// Mientras las preferencias cargan (en segundo plano) vale lo que dijo `/me` (`club_personal`),
// que el router espera antes de mostrar nada. Antes contestaba `false` en ese rato: al abrir la
// app se dibujaba el inicio de una organización y después saltaba a «Hoy» (11-oct-2026).
import { computed } from 'vue'
import { useClubStore } from '../stores/club'
import { useAuthStore } from '../stores/auth'

// Para el router y los guards, que no están dentro de un componente.
export function esUsoPersonal() {
  const club = useClubStore()
  if (club.data && typeof club.data.personal === 'boolean') return club.data.personal
  return useAuthStore().user?.club_personal === true
}

export function useUsoPersonal() {
  const club = useClubStore()
  const auth = useAuthStore()
  const esPersonal = computed(() =>
    club.data && typeof club.data.personal === 'boolean' ? club.data.personal : auth.user?.club_personal === true)

  // El texto visible dice «tu cultivo» donde a una organización se le dice «la organización».
  // Sólo las formas que aparecen en pantalla; no es un diccionario.
  const org = computed(() => (esPersonal.value
    ? { de: 'de tu cultivo', la: 'tu cultivo', toda: 'todo tu cultivo', tu: 'tu cultivo' }
    : { de: 'de la organización', la: 'la organización', toda: 'toda la organización', tu: 'tu organización' }))

  // «Sala» es la palabra de una organización con cuartos numerados. El que cultiva en casa tiene
  // una carpa o un espacio, y así se lo nombra (pedido de Germán, 18-sep-2026). Los identificadores
  // (`Sala`, `sala_id`, rutas) no cambian: es texto visible, misma regla que Club → Organización.
  const sala = computed(() => (esPersonal.value
    ? { una: 'espacio de cultivo', unas: 'espacios de cultivo', Una: 'Espacio de cultivo', Unas: 'Espacios de cultivo', corta: 'espacio', cortas: 'espacios', Corta: 'Espacio', Cortas: 'Espacios' }
    : { una: 'sala', unas: 'salas', Una: 'Sala', Unas: 'Salas', corta: 'sala', cortas: 'salas', Corta: 'Sala', Cortas: 'Salas' }))

  // EN AUTOCULTIVO EL LOTE NO SE NOMBRA (9-oct-2026): vive por debajo, y para la persona son «las
  // plantas de tal genética». Una organización lo sigue viendo por su código. Lo usan todos los
  // modales que dejan elegir un lote (tarea, gasto, plan, riego), en el teléfono y en la compu.
  const nombreLote = (l) => {
    if (!l) return ''
    if (!esPersonal.value) return l.codigo || ''
    return l.genetica?.nombre || l.genetica_nombre || l.strain || 'Plantas'
  }
  const cuantasPlantas = (n) => `${n || 0} ${Number(n) === 1 ? 'planta' : 'plantas'}`

  return { esPersonal, org, sala, nombreLote, cuantasPlantas }
}
