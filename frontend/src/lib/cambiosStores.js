// Qué store se refresca con qué recurso del canal «algo cambió» (`ClubChannel` / `Transmite`).
//
// Es la tabla que hace que toda pantalla que lee de un store se actualice sola, sin tocarla.
// Cada store re-pide SÓLO lo que ya tiene cargado y sin spinner (`refrescar()`); una tanda de
// cambios dispara una recarga (agrupado en 300 ms) y nunca pisa una que está en vuelo.
//
// Se engancha al entrar (con usuario) y se suelta al salir: lo anotado no vale para el próximo.
import { alCambiarAgrupado, olvidarCambios } from './cambios.js'
import { cerrarCable } from './cableConsumer.js'
import { useLotesStore }  from '../stores/lotes.js'
import { useSalasStore }  from '../stores/salas.js'
import { usePlantsStore } from '../stores/plants.js'
import { useTareasStore } from '../stores/tareas.js'
import { useStatsStore }  from '../stores/stats.js'

let enganchado = false

export function engancharCambios() {
  if (enganchado) return
  enganchado = true
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
}

export function soltarCambios() {
  enganchado = false
  olvidarCambios()
  cerrarCable()
}
