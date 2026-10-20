// ¿Esta pantalla puede OFRECER un link a esta ruta? (20-oct-2026)
//
// La misma decisión que el router toma al entrar (`puedeEntrar` + lo que sólo existe en una
// organización), para que una miga de pan o un botón no lleve a un «No tenés acceso»: el
// cultivador veía «Sede Central» como link en la ficha de sala y el autocultivo también.
import { puedeEntrar, soloDeOrganizacion } from '../router'
import { useAuthStore } from '../stores/auth'
import { useUsoPersonal } from './useUsoPersonal.js'

export function useRutaOfrecible() {
  const auth = useAuthStore()
  const { esPersonal } = useUsoPersonal()
  function ofrece(path) {
    if (esPersonal.value && soloDeOrganizacion(path)) return false
    return puedeEntrar(auth.user?.role, path)
  }
  return { ofrece }
}
