<template>
  <div class="mrm">
    <!-- EL PERÍODO EN BOTONES, sin un "Ver" que apretar. Eran dos campos de fecha y un botón para
         la pregunta que se hace el 95% de las veces: "¿cómo vengo este mes?". -->
    <div class="mrm__filtros">
      <div class="mrm__periodos">
        <button v-for="p in PERIODOS" :key="p.id" class="mrm__periodo"
                :class="{ 'is-on': periodo === p.id }" @click="elegirPeriodo(p.id)">
          {{ p.label }}
        </button>
        <button class="mrm__periodo" :class="{ 'is-on': periodo === 'otro' }"
                @click="periodo = 'otro'">Otro</button>
      </div>

      <template v-if="periodo === 'otro'">
        <label class="mrm__campo-inline">Desde
          <input v-model="rango.desde" type="date" class="mrm__input mrm__input--fecha" @change="cargar" />
        </label>
        <label class="mrm__campo-inline">Hasta
          <input v-model="rango.hasta" type="date" class="mrm__input mrm__input--fecha" @change="cargar" />
        </label>
      </template>

      <!-- Comparar sedes es LA pregunta que encuentra el cuello de botella: si en una se pierde
           el triple que en otra con el mismo producto, el problema no es la merma. -->
      <label v-if="variasSedes" class="mrm__campo-inline">
        <input v-model="todasLasSedes" type="checkbox" @change="cargar" /> Todas las sedes
      </label>
    </div>

    <p v-if="cargando" class="mrm__vacio">Calculando…</p>
    <p v-else-if="!merma || !merma.resumen.turnos" class="mrm__vacio">
      Todavía no hay cierres en este período.
    </p>

    <template v-else>
      <!-- ══ ① ¿CÓMO VIENE? ════════════════════════════════════════════════════
           EL NÚMERO PRIMERO, SIEMPRE. Acá había un cuadro que arrancaba diciendo «con ese
           volumen el porcentaje no dice nada» y abajo, en gris y monoespaciado, los $27.636 que
           faltaban. La pantalla declarándose muda encima del único dato que importaba.
           El porcentaje es una aclaración, no el titular: cuando no se puede calcular —no se
           entregó nada— no queda un «–%», simplemente no se dice. -->
      <section class="mrm__estado" :class="`mrm__estado--${tono}`">
        <p class="mrm__estado-frase">{{ titular }}</p>
        <!-- Y LA PLATA, en su propia oración. «¿Cómo viene?» hablaba sólo del producto: el
             efectivo que faltó en el cajón no estaba en ningún resumen, sólo abriendo cierre
             por cierre. Se dice en neto y con signo, y sólo cuando pasó algo. -->
        <p v-if="fraseCaja" class="mrm__estado-sub mrm__estado-caja">{{ fraseCaja }}</p>
        <p v-if="aclaracion" class="mrm__estado-sub">{{ aclaracion }}</p>
        <p v-if="veredicto && veredicto.motor" class="mrm__estado-sub">
          La está moviendo <b>{{ veredicto.motor.producto }}</b>:
          faltaron {{ fmt(veredicto.motor.faltante) }} {{ veredicto.motor.unidad }}
          (${{ fmt(veredicto.motor.faltante_ars) }}) en la semana.
        </p>

        <div v-if="serie.length > 1" class="mrm__tendencia">
          <div class="mrm__barras">
            <div v-for="s in serie" :key="s.semana" class="mrm__barra-col"
                 :title="`Semana del ${fecha(s.semana)}: ${s.merma_pct ?? 0}% · ${fmt(s.faltante)} faltantes`">
              <div class="mrm__barra" :style="{ height: alto(s) }"></div>
              <span class="mrm__barra-lbl">{{ fecha(s.semana) }}</span>
            </div>
          </div>
          <span class="mrm__tendencia-lbl">Merma por semana, en % de lo entregado</span>
        </div>
      </section>

      <!-- ══ ③ ¿DÓNDE SE VA? ═══════════════════════════════════════════════════
           UNA tabla con un corte a la vez, no tres apiladas con las mismas columnas: había que
           elegir cuál mirar antes de saber qué se estaba buscando. -->
      <!-- «Dónde se va» era un título sin sujeto: ¿dónde se va qué? -->
      <h2 class="mrm__seccion">De qué falta</h2>
      <div class="mrm__corte">
        <div class="mrm__cortes">
          <button v-for="c in cortes" :key="c.id" class="mrm__periodo"
                  :class="{ 'is-on': corte === c.id }" @click="corte = c.id">{{ c.label }}</button>
        </div>
        <button class="mrm__btn mrm__btn--mini mrm__btn--ghost" @click="bajarCsv">Bajar CSV</button>
      </div>

      <p v-if="!filas.length" class="mrm__nada">No falta nada en este período.</p>

      <!-- El hallazgo que la tabla vieja no sabía decir. Va como aviso y no como una línea más:
           faltar producto de algo que nadie vendió es otra cosa, y más urgente. -->

      <!-- FILAS DE DOS LÍNEAS, NO UNA TABLA DE CINCO COLUMNAS.
           Era «% · vs promedio · Faltó · A costo · Entregado»: cinco números sin sujeto, y
           «Entregado» nadie sabía qué era (es el denominador del %). Con la mesa parada, todas
           las celdas decían «–%» y «0 g» — una tabla entera de guiones.
           Ahora manda LA PLATA, que es lo único comparable entre productos y que existe siempre:
           el porcentaje desaparece cuando no se vendió nada, y ordenar por él dejaba el orden
           sin hacer nada. Se cae también la frase que defendía el criterio: ordenar por plata no
           necesita explicación. -->
      <ul v-else class="mrm__filas">
        <li v-for="f in filas" :key="f.clave" class="mrm__item">
          <!-- LA FILA DE UN PRODUCTO SE ABRE Y MUESTRA SU GRÁFICO. Era otra solapa («Producto
               por producto») con su propio filtro de fecha: la misma pregunta partida en dos
               lugares. El gráfico es la EXPLICACIÓN del número, y va donde está el número. -->
          <component :is="abrible(f) ? 'button' : 'div'" class="mrm__fila"
                     :class="{ 'mrm__fila--abrible': abrible(f), 'is-abierta': abierta === f.clave }"
                     :type="abrible(f) ? 'button' : undefined"
                     :aria-expanded="abrible(f) ? String(abierta === f.clave) : undefined"
                     @click="abrible(f) && alternar(f)">
            <div class="mrm__fila-txt">
              <span class="mrm__fila-titulo">{{ f.titulo }}</span>
              <span class="mrm__fila-sub">{{ f.contexto }}</span>
            </div>
            <div class="mrm__fila-num">
              <span class="mrm__fila-ars">${{ fmt(f.ars) }}</span>
              <span class="mrm__fila-cant">{{ fmt(f.faltante) }} {{ f.unidad }}</span>
            </div>
            <i v-if="abrible(f)" class="bi mrm__fila-arr" :class="abierta === f.clave ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
          </component>

          <div v-if="abierta === f.clave" class="mrm__detalle">
            <p v-if="cargandoEvolucion" class="mrm__detalle-nota">Buscando cierre por cierre…</p>
            <template v-else>
              <p class="mrm__detalle-nota">
                Lo que tenía que haber (punteado) contra lo que se contó (lleno), cierre por cierre.
                Cada frasco con <b>su propia escala</b>: el hueco entre las dos líneas es lo que faltó.
              </p>
              <p v-if="!graficosDe(f).length" class="mrm__detalle-nota">
                Todavía no hay cierres con conteo de este producto en el período.
              </p>
              <div v-else class="mrm__graficos">
                <GraficoProducto v-for="g in graficosDe(f)" :key="g.stock_id" :producto="g" />
              </div>
            </template>
          </div>
        </li>
      </ul>
    </template>

  </div>
</template>
<script setup>
// DÓNDE SE LE VA EL PRODUCTO a la organización.
//
// No es una auditoría ni un tablero de culpas: la merma es inevitable, y contarla sirve para
// saber cuánta hay, en qué producto y en qué momento — que es lo que deja ver un cuello de
// botella. El texto de la pantalla tiene que sonar así.
//
// ORDENADA POR PREGUNTA, no por entidad — el mismo criterio con el que se ordenaron los informes:
//   ① ¿cómo viene?      → el veredicto contra el patrón de ESTA organización, y la tendencia
//   ② ¿qué tengo que hacer? → los turnos que piden una mirada, que se terminan
//   ③ ¿dónde se va?     → UNA tabla, con un corte a la vez
//
// Antes eran cuatro tablas apiladas (sede, producto, turno) con las MISMAS columnas y tres KPIs
// arriba: había que elegir cuál mirar antes de saber qué se estaba buscando, y el número
// principal —"2,4% de lo entregado"— no se comparaba con nada. La app ya sabía si eso era mucho
// o poco (`MermaMostradorJob` avisa cuando cambia contra las ocho semanas anteriores) y esta
// pantalla no lo usaba: le llegaba el mail diciendo "algo cambió", entraba a mirar, y acá no
// decía nada de eso.
import { ref, computed, watch } from 'vue'
import { getMermaMostrador, getEvolucionMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import GraficoProducto from './GraficoProducto.vue'

const props = defineProps({
  sedeId:      { type: Number, default: null },
  variasSedes: { type: Boolean, default: false },
})
// El badge de la solapa lo pinta el padre: lo que se marca acá tiene que bajarle el número.
const emit = defineEmits(['sin-revisar'])

const toast    = useToast()
const merma    = ref(null)
const cargando = ref(false)
const todasLasSedes = ref(false)
const corte    = ref('producto')
const periodo  = ref('mes')
// El rango arranca VACÍO y lo completa el backend con el mes en curso en SU zona horaria.
//
// Antes lo calculaba acá con `toISOString()`, que da la fecha en UTC: con el navegador en una
// zona y Rails en Buenos Aires, entre las 21:00 y las 00:00 el rango pedía un mañana donde
// todavía no había cerrado nadie, y la solapa se veía vacía justo en el horario en que se cierra
// el mostrador. El cliente no tiene por qué adivinar qué día es en el servidor.
const rango = ref({ desde: '', hasta: '' })

// Los períodos que se piden de verdad. "Este mes" es la pregunta del 95% de las veces y era dos
// campos de fecha y un botón; los otros dos existen para ver una tendencia, que en un mes corto
// no se ve.
const PERIODOS = [
  { id: 'mes',  label: 'Este mes',   dias: null },
  { id: 'd30',  label: '30 días',    dias: 30 },
  { id: 'd90',  label: '90 días',    dias: 90 },
]

const veredicto = computed(() => merma.value?.veredicto || null)
const serie     = computed(() => merma.value?.serie || [])

// El tono acompaña, no grita: la merma es inevitable y no es culpa de nadie. Rojo no hay.
const tono = computed(() => ({ subio: 'alerta', normal: 'ok' })[veredicto.value?.estado] || 'mudo')

// EL TITULAR: ARRANCA POR EL NÚMERO, SIEMPRE.
//
// Antes la frase empezaba por el veredicto —«se entregó poco (0), el porcentaje no dice nada»—
// con la plata faltante escondida en un pie gris. La pantalla se declaraba muda encima del único
// dato que importaba. Ahora el hecho va primero y el veredicto es la línea de abajo.
const faltanteArs = computed(() => Number(merma.value?.resumen?.faltante_ars) || 0)
const cierres     = computed(() => Number(merma.value?.resumen?.turnos) || 0)

// La plata, neta y con signo. Se dice sólo cuando pasó algo: «$0» es una celda vacía con formato.
const fraseCaja = computed(() => {
  const r = merma.value?.resumen
  const neto = Number(r?.caja_ars) || 0
  const n = Number(r?.caja_turnos) || 0
  if (!n || Math.abs(neto) < 1) return ''
  const en = `en ${n} ${n === 1 ? 'cierre' : 'cierres'}`
  return neto < 0
    ? `Y en la caja faltaron $${fmt(Math.abs(neto))} ${en}.`
    : `Y en la caja sobraron $${fmt(neto)} ${en}.`
})

// ── EL GRÁFICO DE CADA PRODUCTO, adentro de su fila ──────────────────────────────────────
// La evolución se pide UNA vez por rango, cuando alguien abre la primera fila, y se filtra acá:
// Merma agrupa por etiqueta (genética + forma) y la evolución va por frasco, así que una fila
// puede abrir dos gráficos — dos lotes de la misma variedad, cada uno con su escala.
const abierta = ref(null)
const evolucion = ref(null)          // { clave, productos }
const cargandoEvolucion = ref(false)

// Sólo el corte por producto tiene detalle, y sólo de UNA sede: el gráfico cuelga del mostrador
// y con «todas las sedes» la fila es del club entero.
const abrible = (f) => corte.value === 'producto' && !todasLasSedes.value

function alternar (f) {
  abierta.value = abierta.value === f.clave ? null : f.clave
  if (abierta.value) cargarEvolucion()
}

const graficosDe = (f) => (evolucion.value?.productos || []).filter(g => g.etiqueta === f.titulo)

async function cargarEvolucion () {
  const clave = `${props.sedeId}|${rango.value.desde}|${rango.value.hasta}`
  if (evolucion.value?.clave === clave) return
  cargandoEvolucion.value = true
  try {
    const { data } = await getEvolucionMostrador(props.sedeId, { ...rango.value })
    evolucion.value = { clave, productos: data.productos || [] }
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo calcular cierre por cierre.')
    evolucion.value = { clave, productos: [] }
  } finally {
    cargandoEvolucion.value = false
  }
}

const titular = computed(() => {
  const m = merma.value
  if (!m) return ''
  const n = `${cierres.value} ${cierres.value === 1 ? 'cierre' : 'cierres'}`
  // «Cuadró» y «a costo» son palabras de contador. El que abre esta pantalla sabe de plantas.
  if (!faltanteArs.value) return `No falta nada. ${n} en este período.`
  return `Falta producto por $${fmt(faltanteArs.value)} en ${n}.`
})

// La comparación contra el historial, que es lo que contesta «¿viene subiendo?». Va DEBAJO del
// número y sólo cuando dice algo: un «–%» no es información, es una celda vacía con formato.
const aclaracion = computed(() => {
  const v = veredicto.value
  if (!v) return ''
  const semanas = v.semanas_previas || 8
  switch (v.estado) {
    case 'subio':
      return `Subió a ${v.pct}% esta semana, contra ${v.pct_previo}% de las últimas ${semanas} ` +
             'semanas. Conviene mirar qué la está moviendo.'
    case 'normal':
      return `${v.pct}% esta semana: como viene siempre acá (${v.pct_previo}% en las últimas ` +
             `${semanas} semanas).`
    case 'poco_volumen':
      return 'Todavía se entregó poco como para comparar contra tu historial.'
    case 'sin_historia':
      return 'Todavía no hay con qué comparar: hacen falta unas semanas de cierres.'
    default:
      return ''
  }
})

// La barra más alta es el peor porcentaje de la serie: comparar contra un máximo fijo dejaría
// todas las semanas planas en una organización prolija, que es la mayoría.
const topeSerie = computed(() =>
  Math.max(...serie.value.map(s => Number(s.merma_pct) || 0), 0.1)
)
const alto = (s) => `${Math.max(((Number(s.merma_pct) || 0) / topeSerie.value) * 100, 3)}%`

// LOS CORTES, sin «Cierre por cierre»: eso ES la solapa Cierres, con su filtro «Para mirar» y su
// botón de corregir. Tenerlo también acá eran dos listas de lo mismo en dos lugares.
//
// Y sin las notas de tres renglones que explicaban cada corte: eran texto defendiendo el diseño.
// Lo que hay que saber para no leer mal el corte por persona viaja EN LA FILA (los cierres que
// tiene, y si son pocos), que es donde se lo mira.
const cortes = computed(() => [
  { id: 'producto', label: 'Por producto' },
  ...(merma.value?.por_sede?.length ? [{ id: 'sede', label: 'Por sede' }] : []),
  { id: 'persona', label: 'Por persona' },
])

const encabezado = computed(() =>
  ({ producto: 'Producto', sede: 'Sede', turno: 'Cerró', persona: 'Atendió' })[corte.value]
)

// Los cortes se normalizan a LA MISMA FILA: título, contexto en castellano, plata y cantidad.
//
// `contexto` es la segunda línea y es donde vive todo lo que antes eran columnas de números sin
// sujeto. Ahí va el porcentaje —pero SÓLO cuando se puede calcular— y ahí aparece el hallazgo que
// la tabla vieja no sabía decir: faltar 23 g de algo con CERO entregado no es merma, es producto
// que desapareció sin venderse, y es más urgente que cualquier porcentaje.
//
// ORDENADAS POR PLATA. Es lo único comparable entre productos y que existe siempre: el porcentaje
// desaparece cuando no se vendió nada, y ordenar por él dejaba el orden sin hacer nada.
const filas = computed(() => {
  const m = merma.value
  if (!m) return []

  const cierres = (n) => `${n} ${n === 1 ? 'cierre' : 'cierres'}`
  // Cuánto se entregó de esto, y qué proporción se fue. Con 0 entregado no hay porcentaje que
  // valga: se dice lo que pasó de verdad.
  // EL PORCENTAJE, DICHO COMO SE DICE. «0,7%» hay que traducirlo mentalmente; «se pierden 7 de
  // cada 1.000 que salen» es el mismo dato en la cabeza del que lo lee.
  const sobreLoEntregado = (f) => {
    const d = Number(f.dispensado) || 0
    if (!d) return 'no se entregó nada de esto en el período'
    const pct = Number(f.merma_pct ?? f.pct)
    const u = f.unidad || ''
    if (!Number.isFinite(pct) || pct <= 0) return `sobre ${fmt(d)} ${u} entregados`.trim()
    const cada = Math.round(pct * 10)   // % → cuántos de cada 1.000
    return `sobre ${fmt(d)} ${u} entregados: se pierden ${cada} de cada 1.000 que salen`.replace('  ', ' ')
  }

  let lista
  if (corte.value === 'sede') {
    lista = (m.por_sede || []).map(x => ({
      clave: `s${x.sede_id}`, titulo: x.sede, unidad: '',
      faltante: x.faltante, ars: x.faltante_ars,
      contexto: `${cierres(x.turnos)} · ${sobreLoEntregado(x)}`,
    }))
  } else if (corte.value === 'persona') {
    lista = (m.por_persona || []).map(x => ({
      clave: `u${x.usuario_id}`, titulo: x.persona, unidad: '',
      faltante: x.faltante, ars: x.faltante_ars,
      // LO QUE EVITA LEER MAL EL NÚMERO, en la misma línea y en castellano: quien más volumen
      // mueve encabeza siempre, y con pocos cierres no hay conclusión posible.
      contexto: [
        cierres(x.turnos),
        sobreLoEntregado(x),
        x.suficientes && x.contra_promedio != null
          ? `${x.contra_promedio > 0 ? '+' : ''}${fmt(x.contra_promedio)} pts contra el promedio de acá`
          : 'todavía son pocos cierres para concluir',
        x.cerro_otro ? 'algún cierre lo hizo otra persona' : null,
      ].filter(Boolean).join(' · '),
    }))
  } else {
    lista = (m.por_producto || []).map(x => ({
      clave: `p${x.producto}`, titulo: x.producto, unidad: x.unidad,
      faltante: x.faltante, ars: x.faltante_ars,
      contexto: `${cierres(x.turnos)} · ${sobreLoEntregado(x)}`,
    }))
  }

  // Sin las filas en cero: en una lista de «dónde se va», un renglón que no se fue a ningún lado
  // es una fila que hay que leer para descartar.
  return lista.filter(f => Number(f.ars) > 0 || Number(f.faltante) > 0)
              .sort((a, b) => (Number(b.ars) || 0) - (Number(a.ars) || 0))
})

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

function elegirPeriodo (id) {
  periodo.value = id
  const p = PERIODOS.find(x => x.id === id)
  if (!p) return
  if (!p.dias) { rango.value = { desde: '', hasta: '' } }   // el backend pone el mes en curso
  else {
    const hasta = new Date()
    const desde = new Date(Date.now() - (p.dias - 1) * 86400000)
    rango.value = { desde: iso(desde), hasta: iso(hasta) }
  }
  cargar()
}
// La fecha del NAVEGADOR, en su día local: `toISOString()` la pasa a UTC y de noche adelanta un
// día — el mismo error que ya había hecho ver la solapa vacía a las 21:00.
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

async function cargar () {
  if (!props.sedeId) return
  cargando.value = true
  try {
    const params = { ...rango.value }
    if (todasLasSedes.value) params.todas = 1
    const { data } = await getMermaMostrador(props.sedeId, params)
    merma.value = data
    abierta.value = null
    emit('sin-revisar', data.sin_revisar ?? 0)
    // El backend contesta con el rango que efectivamente usó: los campos lo muestran.
    if (data.rango) rango.value = { desde: data.rango.desde, hasta: data.rango.hasta }
    if (corte.value === 'sede' && !data.por_sede?.length) corte.value = 'producto'
    // «Cierre por cierre» se mudó a la solapa Cierres: si quedó elegido de una sesión anterior,
    // vuelve al corte por producto en vez de dejar la lista vacía sin decir por qué.
    if (corte.value === 'turno') corte.value = 'producto'
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo calcular la merma.')
  } finally {
    cargando.value = false
  }
}

// Se baja EL CORTE QUE SE ESTÁ MIRANDO, no un archivo con todo: quien lo abre ya eligió la
// pregunta acá adentro. Se arma en el navegador con lo que ya está en pantalla — pedirle al
// backend un CSV de lo mismo sería otro endpoint que mantener sincronizado.
// EL CSV SÍ LLEVA LOS NÚMEROS SUELTOS. Lo abre alguien que va a analizar, no a leer de un
// vistazo: ahí las columnas separadas sirven, y en la pantalla eran cinco cifras sin sujeto.
function bajarCsv () {
  const cab = [encabezado.value, 'Contexto', 'A costo ($)', 'Falto']
  const filasCsv = filas.value.map(f => [f.titulo, f.contexto, f.ars, f.faltante])
  const csv = [cab, ...filasCsv]
    .map(fila => fila.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(';'))
    .join('\n')
  const url = URL.createObjectURL(new Blob([`﻿${csv}`], { type: 'text/csv;charset=utf-8' }))
  const a = document.createElement('a')
  a.href = url
  a.download = `merma-${corte.value}-${rango.value.desde || 'mes'}.csv`
  a.click()
  URL.revokeObjectURL(url)
}



// Cambiar de sede recalcula: si no, se veían números de la sede anterior que parecen de esta.
watch(() => props.sedeId, () => { merma.value = null; cargar() }, { immediate: true })
</script>
<style scoped>
.mrm__filtros { display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap; margin-bottom: 18px; }
.mrm__campo-inline {
  display: inline-flex; align-items: center; gap: 7px;
  font-size: var(--fs-13); color: var(--c-ink-700);
}
.mrm__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); font-family: var(--font-mono);
  background: #fff; color: var(--c-ink-900);
}
.mrm__input--fecha { width: auto; }

.mrm__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.mrm__nada  { margin: 0 0 6px; font-size: var(--fs-14); color: var(--c-leaf-700); }

/* ── Lista de trabajo ───────────────────────────────────────────────────────── */
/* ── Análisis ───────────────────────────────────────────────────────────────── */
.mrm__kpis { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 24px; }
.mrm__kpi {
  flex: 1; min-width: 150px;
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 16px;
  display: flex; flex-direction: column; gap: 3px;
}
.mrm__kpi-num {
  font-family: var(--font-mono); font-size: var(--fs-24, 24px);
  font-weight: 700; color: var(--c-leaf-800);
}
.mrm__kpi-num small { font-size: var(--fs-14); font-weight: 600; }
.mrm__kpi-lbl { font-size: var(--fs-12); color: var(--c-ink-500); }

.mrm__seccion {
  font-family: var(--font-display); font-size: var(--fs-16); font-weight: 700;
  color: var(--c-leaf-900); margin: 26px 0 2px;
}
.mrm__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }

.mrm__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.mrm__btn--ghost { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
.mrm__btn--mini  { padding: 6px 12px; font-size: var(--fs-13); background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mrm__btn--mini.mrm__btn--ghost { background: #fff; color: var(--c-ink-700); }
/* La excepción, no la acción normal: corregir un conteo cerrado ajusta el inventario. */
.mrm__btn--corregir { margin-left: 6px; }

/* ── El período, en botones ─────────────────────────────────────────────────── */
.mrm__periodos, .mrm__cortes { display: flex; gap: 6px; flex-wrap: wrap; }
.mrm__periodo {
  border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-ink-700);
  border-radius: 999px; padding: 7px 14px; font-size: var(--fs-13); font-weight: 600;
  cursor: pointer;
}
.mrm__periodo.is-on { background: var(--c-leaf-800); color: #fff; border-color: var(--c-leaf-800); }

/* ── ① El veredicto ─────────────────────────────────────────────────────────── */
/* La merma es inevitable y no es culpa de nadie: ámbar para "mirá esto", nunca rojo. */
.mrm__tendencia { display: flex; flex-direction: column; gap: 6px; align-items: flex-end; }
.mrm__barras    { display: flex; align-items: flex-end; gap: 5px; height: 62px; }
.mrm__barra-col { display: flex; flex-direction: column; align-items: center; gap: 4px; height: 100%; justify-content: flex-end; }
.mrm__barra     { width: 16px; background: var(--c-leaf-600); border-radius: 3px 3px 0 0; min-height: 2px; }
.mrm__barra-lbl { font-size: 10px; color: var(--c-ink-500); font-family: var(--font-mono); }
.mrm__tendencia-lbl { font-size: var(--fs-12); color: var(--c-ink-500); }

/* ── ③ El corte ─────────────────────────────────────────────────────────────── */
.mrm__corte {
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  flex-wrap: wrap; margin: 4px 0 8px;
}
@media (max-width: 640px) {
}
/* ── EL ESTADO: UNA LÍNEA, NO UN CUADRO ────────────────────────────────────────
   El titular arranca por el número y la comparación va debajo, en chico. Era un cuadro con
   borde de color que empezaba diciendo que no tenía nada que decir. */
.mrm__estado { padding: 4px 0 16px; }
.mrm__estado-frase { margin: 0; font-size: var(--fs-18, 1.05rem); font-weight: 700; color: var(--c-ink-900); line-height: 1.4; }
.mrm__estado-sub   { margin: 6px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 70ch; line-height: 1.5; }
/* El tono acompaña, no grita: la merma es inevitable y no es culpa de nadie. Rojo no hay. */
.mrm__estado--alerta .mrm__estado-frase { color: var(--c-amber-700, #b45309); }
.mrm__estado--ok     .mrm__estado-frase { color: var(--c-ink-900); }

.mrm__estado-caja { color: var(--c-ink-700); font-weight: 600; }

/* ── LAS FILAS: la plata adelante, el resto en castellano abajo ──────────────── */
.mrm__filas { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.mrm__item  { border-bottom: 1px solid var(--c-slate-100); }
.mrm__item:last-child { border-bottom: 0; }
.mrm__fila {
  display: flex; align-items: baseline; justify-content: space-between; gap: 16px;
  padding: 12px 0; width: 100%;
}
/* La fila que se abre es un botón, pero se ve como las demás: lo que cambia es el chevron. */
.mrm__fila--abrible { appearance: none; border: 0; background: none; font: inherit; text-align: left; cursor: pointer; color: inherit; }
.mrm__fila--abrible:hover .mrm__fila-titulo { text-decoration: underline; text-underline-offset: 3px; }
.mrm__fila-arr { color: var(--c-ink-500); font-size: var(--fs-12); align-self: center; }
.mrm__detalle { padding: 2px 0 14px; }
.mrm__detalle-nota { margin: 0 0 10px; font-size: var(--fs-12); color: var(--c-ink-500); max-width: 72ch; }
.mrm__graficos { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.mrm__fila-txt    { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.mrm__fila-titulo { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mrm__fila-sub    { font-size: var(--fs-12); color: var(--c-ink-500); line-height: 1.45; }
.mrm__fila-num    { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; flex-shrink: 0; }
/* La plata manda: es lo único comparable entre productos y lo que existe siempre. */
.mrm__fila-ars    { font-family: var(--font-mono); font-size: var(--fs-15, .95rem); font-weight: 700; color: var(--c-ink-900); }
.mrm__fila-cant   { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }
</style>
