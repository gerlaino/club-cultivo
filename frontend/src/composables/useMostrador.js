// EL ESTADO DEL MOSTRADOR DE UNA SEDE, en un solo lugar.
//
// Existe porque la mesa se mira desde DOS pantallas y no puede tener dos verdades: la de
// escritorio (`MostradorView`, donde administración gobierna la mesa) y la del teléfono
// (`MMostradorView`, donde el dispensador atiende de pie). Son la misma mesa y la misma caja,
// así que lo que difiere es la PRESENTACIÓN y nada más.
//
// La regla del proyecto es que una regla escrita en dos lados ya está mal, y acá el síntoma
// sería el peor: la pantalla del teléfono ofreciendo algo que el backend rechaza, o dos
// pantallas mostrando distinto lo que hay sobre la misma mesa. Lo que se duplicaba —cargar,
// guardar, contar, abrir, cerrar, mover plata, la sede inicial, el canal— vive acá.
//
// Lo que NO vive acá, a propósito, es el estado de los modales (`conteo`, `itemAContar`,
// `plata`, `revisando`, `tab`): eso sí es de cada pantalla, y cada una los abre a su manera.
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getMostrador, cargarMostrador, abrirMostrador, cerrarMostrador, contarMostrador,
         ingresoCajaMostrador, salidaCajaMostrador } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { useSedeStore } from '../stores/sede.js'
import { useStockChannel } from './useStockChannel.js'
import { useToast } from './useToast.js'

// La merma y las rendiciones son información de GESTIÓN, y la mesa la gobierna administración.
// Quien atiende decide con lo que tiene sobre la mesa.
//
// Se exporta porque decide DOS cosas que tienen que coincidir: qué ve cada rol dentro de la
// pantalla, y cuál de las dos pantallas se le sirve bajo `/m/mostrador`. Escrita dos veces, un
// día el dispatch manda a una pantalla y la pantalla se dibuja para el otro rol.
export const gestionaMostrador = (role) => ['admin', 'supervisor', 'super_admin'].includes(role)

export function useMostrador () {
  const sedeStore = useSedeStore()
  const auth      = useAuthStore()
  const toast     = useToast()
  const route     = useRoute()

  const gestiona = computed(() => gestionaMostrador(auth.user?.role))

  const sedeId    = ref(null)
  const cargando  = ref(true)
  const cargado   = ref(false)
  const guardando = ref(false)
  const error     = ref('')
  const turno     = ref(null)
  const mesa      = ref([])
  const disponibles = ref([])
  const fondoSugerido = ref(null)
  const sinRevisar = ref(0)

  // Lo que va a quedar sobre la mesa: { stock_id: cantidad }. Vive acá y no en la tabla para
  // sobrevivir al buscador y al orden — si viviera adentro, filtrar borraría lo ya escrito.
  const cantidades = ref({})

  const sedes  = computed(() => (sedeStore.sedes || []).filter(s => s.tipo === 'social' || s.tipo === 'mixta'))
  const estado = computed(() => (turno.value ? 'abierto' : 'cerrado'))

  // Administración ve TODO el stock apto de la sede, con lo que hay en el depósito y lo que hay
  // sobre la mesa. Quien atiende ve sólo la mesa: él no elige qué hay.
  const tabla = computed(() => {
    if (!gestiona.value) return mesa.value
    const enMesa = new Map(mesa.value.map(m => [m.stock_id, m.mostrador]))
    return disponibles.value.map(s => ({ ...s, mostrador: enMesa.get(s.stock_id) || 0 }))
  })

  // Lo que cambia, con el antes y el después de cada producto: es lo que se revisa en el modal.
  // Con buscador y orden de por medio, lo tocado puede no estar todo en pantalla al guardar.
  const cambiosMesa = computed(() =>
    tabla.value
      .filter(s => {
        const v = cantidades.value[s.stock_id]
        return v !== undefined && Number(v) !== Number(s.mostrador || 0)
      })
      .map(s => ({
        stock_id: s.stock_id, forma: s.forma, genetica: s.genetica, numero: s.numero,
        unidad: s.unidad, antes: Number(s.mostrador || 0), ahora: Number(cantidades.value[s.stock_id]),
      }))
  )

  // Con cuánta plata queda la mesa si se guarda. Sólo para administración, que es quien la gobierna.
  const valorMesaDespues = computed(() =>
    tabla.value.reduce((t, s) => {
      const cant = Number(cantidades.value[s.stock_id] ?? s.mostrador ?? 0)
      return t + cant * Number(s.precio_ars || 0)
    }, 0)
  )

  const esperadoEfectivo = computed(() =>
    turno.value?.caja?.esperado_ars ?? Number(fondoSugerido.value || 0)
  )
  // Plata en efectivo que entró sin ser una dispensa — pagó una deuda, señó una reserva. Se le
  // muestra a quien arquea aparte, para que una diferencia se pueda explicar por su origen.
  const otrosIngresosEfectivo = computed(() => turno.value?.caja?.otros_ingresos_efectivo_ars || 0)

  // Lo que administración tocó mientras la caja estaba abierta. Sin esto, quien atiende cierra
  // con un faltante que no es suyo y no lo puede explicar.
  // AGRUPADOS por quién, qué producto y por qué. Cargar la mesa de a poco es lo normal —se sube
  // una variedad, después otra, después se completa— y sin agrupar salían cuatro renglones casi
  // idénticos ("subió 100 g de Flor seca a las 17:51", "subió 150 g de Flor seca a las 17:51"…)
  // que hay que leer uno por uno para entender que se cargaron 650 g. La pregunta de quien
  // atiende es CUÁNTO cambió lo suyo, no cuántas veces tocaron el botón.
  const movimientosDelTurno = computed(() => {
    const porClave = new Map()

    mesa.value.forEach(m => {
      (m.movimientos_del_turno || [])
        .filter(mv => mv.tipo !== 'ajuste')
        .forEach(mv => {
          const sentido = Number(mv.cantidad) > 0 ? 'sube' : 'baja'
          const clave = [mv.usuario, m.forma, m.unidad, mv.motivo || '', sentido].join('|')
          const previo = porClave.get(clave)

          if (previo) {
            previo.cantidad += Number(mv.cantidad)
            previo.veces += 1
            if (mv.cuando > previo.cuando) previo.cuando = mv.cuando
          } else {
            porClave.set(clave, {
              usuario: mv.usuario, motivo: mv.motivo, cuando: mv.cuando,
              cantidad: Number(mv.cantidad), forma: m.forma, unidad: m.unidad, veces: 1,
            })
          }
        })
    })

    return [...porClave.values()].sort((a, b) => (a.cuando < b.cuando ? 1 : -1))
  })

  let cargaEnCurso = 0

  async function cargar () {
    if (!sedeId.value) {
      // Todavía no sabemos con qué sede trabajar: el watcher corre con `immediate` ANTES de que
      // `onMounted` la fije. Si la pantalla se dibujara vacía y un instante después se rearmara,
      // lo que la persona haya empezado a escribir se pierde sin que haya tocado nada.
      cargando.value = !sedeStore.loaded || sedes.value.length > 0
      return
    }
    const mia = ++cargaEnCurso
    if (!cargado.value) cargando.value = true
    error.value = ''
    try {
      const { data } = await getMostrador(sedeId.value)
      if (mia !== cargaEnCurso) return // llegó tarde: ya hay una carga más nueva

      turno.value       = data.turno
      mesa.value        = data.mesa || []
      disponibles.value = data.disponibles || []
      fondoSugerido.value = data.fondo_sugerido ?? null
      sinRevisar.value  = data.sin_revisar ?? 0
      // La tabla arranca con lo que HAY: se corrige lo que haya que corregir, no se declara todo.
      cantidades.value  = Object.fromEntries(tabla.value.map(s => [s.stock_id, Number(s.mostrador || 0)]))
    } catch (e) {
      if (mia === cargaEnCurso) error.value = e?.response?.data?.error || 'No se pudo cargar el mostrador.'
    } finally {
      if (mia === cargaEnCurso) { cargando.value = false; cargado.value = true }
    }
  }

  // Sólo lo que cambió: mandar la tabla entera haría que el backend evalúe productos que nadie
  // tocó.
  //
  // `destino` viaja sólo en lo que BAJA ('deposito' o 'merma'): lo que se perdió sale del
  // inventario y lo demás vuelve al depósito. Subir nunca puede ser una pérdida.
  async function guardarMesa ({ motivo, destinos = {} }) {
    const cambios = cambiosMesa.value.map(c => {
      const linea = { stock_id: c.stock_id, cantidad: c.ahora }
      if (destinos[c.stock_id]) linea.destino = destinos[c.stock_id]
      return linea
    })
    if (!cambios.length) return false

    guardando.value = true
    try {
      await cargarMostrador(sedeId.value, { cambios, motivo })
      toast.success(cambios.length === 1 ? 'Mesa actualizada' : `${cambios.length} productos actualizados`)
      await cargar()
      return true
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo actualizar la mesa.')
      return false
    } finally { guardando.value = false }
  }

  // `esCierre` viaja como parámetro y no se lee de un `ref` de la pantalla: cuál de los dos
  // conteos es lo sabe quien abrió el modal, y cada pantalla lo abre a su manera.
  async function confirmarConteo (payload, { esCierre } = {}) {
    guardando.value = true
    try {
      if (esCierre) await cerrarMostrador(sedeId.value, payload)
      else          await abrirMostrador(sedeId.value, payload)
      toast.success(esCierre ? 'Caja cerrada' : 'Caja abierta')
      await cargar()
      return true
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo registrar el conteo.')
      return false
    } finally { guardando.value = false }
  }

  // Contar un producto suelto, con la caja abierta y sin cerrarla. A diferencia del conteo de
  // APERTURA —que sólo corre el punto de partida— acá la diferencia SÍ ajusta el inventario: el
  // producto estaba sobre la mesa, se contó, y no está.
  async function confirmarConteoDeUno (payload) {
    guardando.value = true
    try {
      await contarMostrador(sedeId.value, payload)
      toast.success('Conteo registrado')
      await cargar()
      return true
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo registrar el conteo.')
      return false
    } finally { guardando.value = false }
  }

  async function moverPlata ({ tipo, monto, motivo, clase }) {
    const cajaId = turno.value?.caja?.id
    if (!cajaId) return false
    guardando.value = true
    try {
      if (tipo === 'ingreso') await ingresoCajaMostrador(sedeId.value, cajaId, { monto_ars: monto, motivo })
      else                    await salidaCajaMostrador(sedeId.value, cajaId, { monto_ars: monto, motivo, clase })
      toast.success(tipo === 'ingreso' ? 'Plata puesta en el cajón' : 'Plata sacada del cajón')
      await cargar()
      return true
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo mover la plata.')
      return false
    } finally { guardando.value = false }
  }

  onMounted(async () => {
    if (!sedeStore.loaded) await sedeStore.fetchSedes()
    // No se llama a `cargar()` acá: fijar la sede dispara el watcher, que carga. Hacer las dos
    // cosas mandaba DOS pedidos por cada apertura de la pantalla.
    //
    // `?sede=` es cómo se llega desde "Cajas del día" o desde la ficha de una sede: sin esto, el
    // admin con varias sedes clickeaba "cómo está Norte" y aterrizaba en la primera de la lista,
    // que podía no ser Norte. Sólo se respeta si es una sede propia — si viene una ajena o
    // inválida, se cae a la primera como siempre.
    const desdeUrl = Number(route.query.sede)
    // Y si no vino por URL, LA SUYA antes que la primera de la lista: quien atiende abrió la caja
    // en su mostrador, y aterrizar en el de otra sede le muestra una mesa vacía y ninguna caja
    // abierta — o sea, la pantalla le dice que no hizo lo que acaba de hacer. `/me` ya trae cuál
    // es (`dispensario_sede`), así que no hace falta preguntar nada.
    const propia = auth.user?.dispensario_sede?.id ?? auth.user?.dispensario_sede_id
    sedeId.value =
      (desdeUrl && sedes.value.some(s => s.id === desdeUrl)) ? desdeUrl
      : (propia && sedes.value.some(s => s.id === propia))   ? propia
      : sedes.value[0]?.id ?? null
  })

  // La mesa se actualiza sola: si administración baja producto desde su oficina, quien atiende lo
  // ve sin recargar — recargar es lo que nadie hace con alguien esperando enfrente. Y se agrupan:
  // una tanda de cambios emite un aviso por producto.
  let recargaPendiente = null
  useStockChannel(null, (evento) => {
    if (evento?.tipo !== 'mostrador_actualizado') return
    if (evento.sede_id && evento.sede_id !== sedeId.value) return

    clearTimeout(recargaPendiente)
    recargaPendiente = setTimeout(cargar, 300)
  })

  watch(sedeId, () => { cargado.value = false; cantidades.value = {}; cargar() }, { immediate: true })

  return {
    gestiona, sedeId, sedes, cargando, guardando, error, turno, mesa, estado,
    fondoSugerido, sinRevisar, cantidades, tabla, cambiosMesa, valorMesaDespues,
    esperadoEfectivo, otrosIngresosEfectivo, movimientosDelTurno,
    cargar, guardarMesa, confirmarConteo, confirmarConteoDeUno, moverPlata,
  }
}
