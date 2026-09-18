// ¿Esta cuenta es de un cultivador de casa?
//
// La regla vive en el backend (`Club#personal?`, derivada del plan) y viaja en `/preferences`
// como `personal`. Acá se lee UNA vez para todo el frontend: el menú, el envoltorio del
// teléfono, el inicio y el vocabulario preguntan esto, y si cada pantalla lo dedujera por su
// cuenta (por el plan, por las features) un día dirían distinto.
//
// Con las preferencias todavía sin cargar contesta `false`: se dibuja como organización un
// instante y se corrige; rebotar o esconder por una carrera de carga es peor.
import { computed } from 'vue'
import { useClubStore } from '../stores/club'

export function useUsoPersonal() {
  const club = useClubStore()
  const esPersonal = computed(() => club.data?.personal === true)

  // El texto visible dice «tu cultivo» donde a una organización se le dice «la organización».
  // Sólo las formas que aparecen en pantalla; no es un diccionario.
  const org = computed(() => (esPersonal.value
    ? { de: 'de tu cultivo', la: 'tu cultivo', toda: 'todo tu cultivo', tu: 'tu cultivo' }
    : { de: 'de la organización', la: 'la organización', toda: 'toda la organización', tu: 'tu organización' }))

  return { esPersonal, org }
}
