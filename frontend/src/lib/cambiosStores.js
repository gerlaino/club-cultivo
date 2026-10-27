// Qué store se refresca con qué recurso del canal «algo cambió» (`ClubChannel` / `Transmite`).
//
// Es la tabla que hace que toda pantalla que lee de un store se actualice sola, sin tocarla.
// Cada store re-pide SÓLO lo que ya tiene cargado y sin spinner (`refrescar()`); una tanda de
// cambios dispara una recarga (agrupado en 300 ms) y nunca pisa una que está en vuelo.
//
// Se engancha al entrar (con usuario) y se suelta al salir: lo anotado no vale para el próximo.
import { alCambiar, alCambiarAgrupado, olvidarCambios, usarCanal } from './cambios.js'
import { cerrarCable } from './cableConsumer.js'
import { useLotesStore }  from '../stores/lotes.js'
import { useSalasStore }  from '../stores/salas.js'
import { usePlantsStore } from '../stores/plants.js'
import { useTareasStore } from '../stores/tareas.js'
import { useStatsStore }  from '../stores/stats.js'
import { useAuthStore }   from '../stores/auth.js'
import { anotarReload }   from '../utils/reloadTrace.js'

let enganchado = false

export function engancharCambios() {
  if (enganchado) return
  enganchado = true
  // El paciente escucha SU canal y nada de lo de la organización: las pantallas del portal se
  // anotan solas por lo suyo (`mensajes`).
  if (useAuthStore().user?.role === 'paciente') { usarCanal('PacienteChannel'); return }
  usarCanal('ClubChannel')
  const lotes  = useLotesStore()
  const salas  = useSalasStore()
  const plants = usePlantsStore()
  const tareas = useTareasStore()
  const stats  = useStatsStore()

  alCambiarAgrupado(['lotes', 'plantas', 'pesajes'],   () => lotes.refrescar())
  // Una sala cambia sola (nombre, fase) o porque un lote entró o salió de ella.
  alCambiarAgrupado(['salas', 'lotes'],                () => salas.refrescar())
  alCambiarAgrupado('plantas',                          (ev) => plants.refrescar(ev))
  alCambiarAgrupado('tareas',                           () => tareas.refrescar())
  // El tablero resume todo: cualquier cosa operativa lo mueve.
  alCambiarAgrupado(['lotes', 'plantas', 'stocks', 'tareas', 'dispensaciones', 'salas'], () => stats.refrescar(), { espera: 800 })

  // A ESTA PERSONA LE CAMBIARON EL ROL con la app abierta (`Acceso::CambiarRol`, 12-oct-2026).
  // El backend ya le aplica los permisos nuevos; si la pantalla siguiera con el menú viejo, todo
  // lo que toca le contestaría 403 sin explicación. Se recarga en el inicio del rol nuevo (el
  // armazón, el menú y los stores son por rol: recargar es lo único que no deja restos) y el
  // inicio le dice por qué.
  alCambiar('usuarios', (ev) => {
    const auth = useAuthStore()
    if (ev?.accion !== 'rol' || !auth.user || ev.id !== auth.user.id) return
    try { sessionStorage.setItem('aviso_rol', '1') } catch { /* sin almacenamiento: recarga igual */ }
    anotarReload('rol-cambiado')
    window.location.assign('/')
  })
}

export function soltarCambios() {
  enganchado = false
  olvidarCambios()
  cerrarCable()
}
