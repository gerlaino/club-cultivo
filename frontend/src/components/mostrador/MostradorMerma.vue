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
      Todavía no hay turnos cerrados en este período.
    </p>

    <template v-else>
      <!-- ══ ① ¿CÓMO VIENE? ════════════════════════════════════════════════════
           Un porcentaje solo no dice nada: 3% puede ser normal fraccionando flor y un
           escándalo en aceite. Acá va el veredicto en castellano, con el mismo criterio que
           dispara el aviso automático — que existía en el job y esta pantalla ignoraba. -->
      <section v-if="veredicto" class="mrm__veredicto" :class="`mrm__veredicto--${tono}`">
        <div class="mrm__ver-texto">
          <p class="mrm__ver-frase">{{ frase }}</p>
          <p v-if="veredicto.motor" class="mrm__ver-motor">
            La está moviendo <b>{{ veredicto.motor.producto }}</b>:
            faltaron {{ fmt(veredicto.motor.faltante) }} {{ veredicto.motor.unidad }}
            (${{ fmt(veredicto.motor.faltante_ars) }}) en la semana.
          </p>
          <p class="mrm__ver-pie">
            En el período elegido: {{ merma.resumen.merma_pct ?? '—' }}% de lo entregado ·
            ${{ fmt(merma.resumen.faltante_ars) }} a costo · {{ merma.resumen.turnos }}
            {{ merma.resumen.turnos === 1 ? 'turno cerrado' : 'turnos cerrados' }}.
          </p>
        </div>

        <!-- LA TENDENCIA, que es lo que contesta "¿viene subiendo?". El total del período no lo
             dice, y hasta ahora la única forma de saberlo era cambiar el rango a mano y
             acordarse del número anterior. Por semana y no por día: un mostrador cierra una o
             dos veces por jornada y en días la mitad de las barras serían cero. -->
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

      <!-- ══ ② LO QUE HAY QUE MIRAR ════════════════════════════════════════════
           Se termina —se mira, se marca y desaparece—; lo de abajo se consulta. Mezclados, la
           lista de trabajo quedaba enterrada entre tres tablas y no se hacía nunca. -->
      <h2 class="mrm__seccion">
        Para mirar
        <span v-if="pendientes.length" class="mrm__contador">{{ pendientes.length }}</span>
      </h2>
      <template v-if="pendientes.length">
        <p class="mrm__seccion-sub">
          Turnos donde pasó algo que conviene mirar. No es una lista de sospechosos: se mira, se
          marca y se archiva.
        </p>
        <ul class="mrm__pendientes">
          <li v-for="t in pendientes" :key="t.id" class="mrm__pendiente">
            <div class="mrm__pendiente-info">
              <span class="mrm__pendiente-quien">
                {{ t.atendio || t.cerrado_por || 'Alguien' }}
                <em class="mrm__pendiente-cuando">· {{ fecha(t.cerrado_at) }}</em>
              </span>
              <span class="mrm__pendiente-motivos">
                <span v-for="m in t.motivos_revision" :key="m" class="mrm__pill" :class="`mrm__pill--${PILL[m]}`">
                  {{ MOTIVO[m] }}
                </span>
                <span v-if="t.faltante > 0" class="mrm__pendiente-num">
                  faltaron {{ fmt(t.faltante) }} · ${{ fmt(t.faltante_ars) }}
                </span>
              </span>
              <span v-if="t.motivos.length" class="mrm__pendiente-motivo">{{ t.motivos.join(' · ') }}</span>
            </div>
            <div class="mrm__pendiente-acc">
              <button class="mrm__btn mrm__btn--mini" @click="revisar(t)">Ya lo miré</button>
              <button class="mrm__btn mrm__btn--mini mrm__btn--ghost" @click="corrigiendo = t">
                Corregir conteo
              </button>
            </div>
          </li>
        </ul>
      </template>
      <p v-else class="mrm__nada">Nada pendiente de mirar en este período.</p>

      <!-- ══ ③ ¿DÓNDE SE VA? ═══════════════════════════════════════════════════
           UNA tabla con un corte a la vez, no tres apiladas con las mismas columnas: había que
           elegir cuál mirar antes de saber qué se estaba buscando. -->
      <h2 class="mrm__seccion">Dónde se va</h2>
      <div class="mrm__corte">
        <div class="mrm__cortes">
          <button v-for="c in cortes" :key="c.id" class="mrm__periodo"
                  :class="{ 'is-on': corte === c.id }" @click="corte = c.id">{{ c.label }}</button>
        </div>
        <button class="mrm__btn mrm__btn--mini mrm__btn--ghost" @click="bajarCsv">Bajar CSV</button>
      </div>
      <p class="mrm__seccion-sub">{{ cortes.find(c => c.id === corte)?.nota }}</p>

      <div class="mrm__table-wrap">
        <table class="mrm__table tabla-cards">
          <thead>
            <tr>
              <th>{{ encabezado }}</th>
              <th class="mrm__th-num">%</th>
              <th v-if="conPromedio" class="mrm__th-num">vs promedio</th>
              <th class="mrm__th-num">Faltó</th>
              <th class="mrm__th-num">A costo</th>
              <th class="mrm__th-num">Entregado</th>
              <th v-if="corte === 'turno'" class="mrm__th-acc"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="f in filas" :key="f.clave">
              <td :data-col="encabezado">
                <div class="mrm__prod">{{ f.titulo }}</div>
                <div v-if="f.meta" class="mrm__prod-meta">
                  <span class="mrm__td-mut">{{ f.meta }}</span>
                  <span v-for="m in f.chips" :key="m" class="mrm__pill" :class="`mrm__pill--${PILL[m] || 'info'}`">
                    {{ MOTIVO[m] || m }}
                  </span>
                </div>
              </td>
              <!-- El % primero y con peso: es el número que manda. Un ranking por gramos siempre
                   encabeza con lo que más se vende y no dice nada. -->
              <td class="mrm__td-num" data-col="%"><span class="mrm__pct">{{ f.pct ?? '—' }}%</span></td>
              <!-- EL NÚMERO QUE DICE DÓNDE AJUSTAR: contra el promedio del mismo mostrador en el
                   mismo período. Un porcentaje solo mide cuánto se vendió tanto como cuánto se
                   perdió. En puntos y no en veces: "el doble" de 0,2% no es nada. -->
              <td v-if="conPromedio" class="mrm__td-num" data-col="vs promedio">
                <span v-if="f.contra == null" class="mrm__td-mut">—</span>
                <span v-else class="mrm__delta" :class="claseDelta(f)">
                  {{ f.contra > 0 ? '+' : '' }}{{ fmt(f.contra) }} pts
                </span>
              </td>
              <td class="mrm__td-num mrm__td-mut" data-col="Faltó">{{ fmt(f.faltante) }} {{ f.unidad }}</td>
              <td class="mrm__td-num mrm__td-mut" data-col="A costo">${{ fmt(f.ars) }}</td>
              <td class="mrm__td-num mrm__td-mut" data-col="Entregado">{{ fmt(f.dispensado) }} {{ f.unidad }}</td>
              <td v-if="corte === 'turno'" class="mrm__td-acc" data-col="">
                <span v-if="f.turno.revisado" class="mrm__pill mrm__pill--ok">Visto</span>
                <button v-else class="mrm__btn mrm__btn--mini" @click="revisar(f.turno)">Ya lo miré</button>
                <button class="mrm__btn mrm__btn--mini mrm__btn--ghost mrm__btn--corregir"
                        @click="corrigiendo = f.turno">Corregir conteo</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <CorregirConteo v-if="corrigiendo" :sede-id="sedeId" :turno="corrigiendo"
                    @cerrar="corrigiendo = null" @corregido="cargar" />
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
import CorregirConteo from './CorregirConteo.vue'
import { getMermaMostrador, revisarTurnoMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

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
const corrigiendo   = ref(null)
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

// Las razones por las que un turno entra a la lista, con el nombre que usa la gente. Un renglón
// que no dice qué mirar obliga a abrirlo para descubrir que no era nada — y una razón sin
// etiqueta acá se dibuja como un chip vacío, que es peor todavía.
const MOTIVO = { faltante: 'Faltó producto', sobrante: 'Contó de más — no se cargó al inventario',
                 corregido: 'Se corrigió al abrir',
                 mesa_movida: 'Se movió la mesa durante el turno',
                 // Del corte por persona: la letra chica que evita leer mal el número de al lado.
                 pocos_turnos: 'Pocos turnos: todavía no alcanza para concluir',
                 cerro_otro: 'Algún turno lo cerró otra persona' }
const PILL   = { faltante: 'warn', sobrante: 'warn', corregido: 'info', mesa_movida: 'info',
                 pocos_turnos: 'info', cerro_otro: 'info' }

// Se pinta sólo cuando hay con qué concluir: un +8 pts de una persona con un turno es ruido, y
// pintarlo de ámbar lo convierte en una acusación fundada en nada.
function claseDelta (f) {
  if (!f.chips || f.chips.includes('pocos_turnos')) return 'is-mudo'
  if (f.contra > 0) return 'is-alto'
  return 'is-bajo'
}

// Lo que todavía no miró nadie Y tiene algo para mirar.
const pendientes = computed(() =>
  (merma.value?.por_turno || []).filter(t => !t.revisado && t.motivos_revision?.length)
)

const veredicto = computed(() => merma.value?.veredicto || null)
const serie     = computed(() => merma.value?.serie || [])

// El tono acompaña, no grita: la merma es inevitable y no es culpa de nadie. Rojo no hay.
const tono = computed(() => ({ subio: 'alerta', normal: 'ok' })[veredicto.value?.estado] || 'mudo')

// LA FRASE. Es lo primero que se lee y tiene que contestar sola "¿estoy bien o mal?".
const frase = computed(() => {
  const v = veredicto.value
  if (!v) return ''
  const semanas = v.semanas_previas || 8
  switch (v.estado) {
    case 'subio':
      return `La merma subió a ${v.pct}% esta semana, contra ${v.pct_previo}% de las últimas ` +
             `${semanas} semanas. Conviene mirar qué la está moviendo.`
    case 'normal':
      return `${v.pct}% esta semana: como viene siempre acá (${v.pct_previo}% en las últimas ` +
             `${semanas} semanas).`
    case 'poco_volumen':
      return `Esta semana se entregó poco (${fmt(v.dispensado)}). Con ese volumen el porcentaje ` +
             'no dice nada: cualquier gramo se ve enorme.'
    case 'sin_historia':
      return 'Todavía no hay con qué comparar: hacen falta unas semanas de turnos cerrados para ' +
             'saber qué es lo normal en este mostrador.'
    default:
      return 'No hubo cierres esta semana, así que no hay nada nuevo que comparar.'
  }
})

// La barra más alta es el peor porcentaje de la serie: comparar contra un máximo fijo dejaría
// todas las semanas planas en una organización prolija, que es la mayoría.
const topeSerie = computed(() =>
  Math.max(...serie.value.map(s => Number(s.merma_pct) || 0), 0.1)
)
const alto = (s) => `${Math.max(((Number(s.merma_pct) || 0) / topeSerie.value) * 100, 3)}%`

const cortes = computed(() => [
  { id: 'producto', label: 'Por producto',
    nota: 'Ordenado por porcentaje, no por cantidad: lo que más se vende siempre encabeza un ' +
          'ranking de gramos y eso no dice nada.' },
  ...(merma.value?.por_sede?.length
    ? [{ id: 'sede', label: 'Por sede',
         nota: 'Si en una se pierde el triple que en otra con el mismo producto, el problema no ' +
               'es la merma: es algo de esa sede, y hasta que no se ponen al lado no se ve.' }]
    : []),
  { id: 'persona', label: 'Por persona',
    nota: 'Cada uno contra el promedio del período en este mostrador, no contra un número suelto: ' +
          'quien más volumen mueve encabeza siempre un ranking pelado, y quien fracciona flor ' +
          'pierde más que quien entrega prerolls. Con menos de 3 turnos no alcanza para concluir.' },
  { id: 'turno', label: 'Turno por turno',
    nota: 'Cada cierre, del más reciente al más viejo. Es donde se corrige un conteo mal cargado.' },
])

const encabezado = computed(() =>
  ({ producto: 'Producto', sede: 'Sede', turno: 'Cerró', persona: 'Atendió' })[corte.value]
)

// Sólo el corte por persona muestra la comparación contra el promedio: en los otros, comparar
// una sede contra el promedio de todas las sedes sería compararla contra sí misma.
const conPromedio = computed(() => corte.value === 'persona')

// Las tres vistas se normalizan a la MISMA fila: si cada corte armara su tabla, volveríamos a
// tener tres tablas que se contradicen en las columnas.
const filas = computed(() => {
  const m = merma.value
  if (!m) return []
  if (corte.value === 'sede') {
    return (m.por_sede || []).map(s => ({
      clave: `s${s.sede_id}`, titulo: s.sede, meta: `${s.turnos} turnos`, chips: [],
      pct: s.merma_pct, faltante: s.faltante, ars: s.faltante_ars, dispensado: s.dispensado,
      unidad: '',
    }))
  }
  if (corte.value === 'persona') {
    return (m.por_persona || []).map(p => ({
      clave: `u${p.usuario_id}`, titulo: p.persona,
      meta: `${p.turnos} ${p.turnos === 1 ? 'turno' : 'turnos'}`,
      chips: [
        ...(p.suficientes ? [] : ['pocos_turnos']),
        ...(p.cerro_otro ? ['cerro_otro'] : []),
      ],
      pct: p.merma_pct, contra: p.contra_promedio, faltante: p.faltante, ars: p.faltante_ars,
      dispensado: p.dispensado, unidad: '',
    }))
  }
  if (corte.value === 'turno') {
    return (m.por_turno || []).map(t => ({
      clave: `t${t.id}`, titulo: fecha(t.cerrado_at), meta: t.cerrado_por,
      chips: t.motivos_revision || [],
      pct: t.merma_pct, faltante: t.faltante, ars: t.faltante_ars, dispensado: t.dispensado,
      unidad: '', turno: t,
    }))
  }
  return (m.por_producto || []).map(p => ({
    clave: `p${p.producto}`, titulo: p.producto, meta: `${p.turnos} turnos`, chips: [],
    pct: p.merma_pct, faltante: p.faltante, ars: p.faltante_ars, dispensado: p.dispensado,
    unidad: p.unidad,
  }))
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
    emit('sin-revisar', data.sin_revisar ?? 0)
    // El backend contesta con el rango que efectivamente usó: los campos lo muestran.
    if (data.rango) rango.value = { desde: data.rango.desde, hasta: data.rango.hasta }
    if (corte.value === 'sede' && !data.por_sede?.length) corte.value = 'producto'
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo calcular la merma.')
  } finally {
    cargando.value = false
  }
}

// Se baja EL CORTE QUE SE ESTÁ MIRANDO, no un archivo con todo: quien lo abre ya eligió la
// pregunta acá adentro. Se arma en el navegador con lo que ya está en pantalla — pedirle al
// backend un CSV de lo mismo sería otro endpoint que mantener sincronizado.
function bajarCsv () {
  const cab = [encabezado.value, 'Detalle', '%',
               ...(conPromedio.value ? ['vs promedio (pts)'] : []),
               'Falto', 'A costo ($)', 'Entregado']
  const filasCsv = filas.value.map(f => [
    f.titulo, f.meta || '', f.pct ?? '',
    ...(conPromedio.value ? [f.contra ?? ''] : []),
    f.faltante, f.ars, f.dispensado,
  ])
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

async function revisar (t) {
  try {
    await revisarTurnoMostrador(props.sedeId, t.id)
    t.revisado = true
    emit('sin-revisar', pendientes.value.length)
  } catch { toast.error('No se pudo marcar como revisado.') }
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
.mrm__pendientes { list-style: none; margin: 0 0 8px; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.mrm__pendiente {
  display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap;
  background: #fff; border: 1px solid var(--c-amber-100); border-left: 3px solid var(--c-amber-500);
  border-radius: 11px; padding: 13px 16px;
}
.mrm__pendiente-info   { display: flex; flex-direction: column; gap: 5px; min-width: 0; }
.mrm__pendiente-quien  { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mrm__pendiente-cuando { font-style: normal; font-weight: 400; color: var(--c-ink-500); }
.mrm__pendiente-motivos { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
.mrm__pendiente-num    { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }
.mrm__pendiente-motivo { font-size: var(--fs-12); color: var(--c-ink-500); }
.mrm__pendiente-acc    { display: flex; gap: 8px; flex-shrink: 0; }

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
.mrm__seccion-sub { margin: 0 0 12px; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }

.mrm__table-wrap {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 14px; overflow-x: auto;
}
.mrm__table { width: 100%; border-collapse: collapse; }
.mrm__table th {
  text-align: left; font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
  padding: 13px 16px; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.mrm__table td { padding: 14px 16px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.mrm__table tbody tr:last-child td { border-bottom: 0; }

.mrm__th-num, .mrm__td-num { text-align: right; }
.mrm__th-acc, .mrm__td-acc { text-align: right; white-space: nowrap; }
.mrm__td-mut { color: var(--c-ink-500); font-size: var(--fs-13); font-family: var(--font-mono); }
.mrm__prod { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mrm__prod-meta { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px; }
.mrm__pct { font-family: var(--font-mono); font-weight: 600; color: var(--c-ink-900); }
.mrm__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }

.mrm__pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.mrm__pill--ok   { background: var(--c-leaf-100);  color: var(--c-leaf-700); }
.mrm__pill--warn { background: var(--c-amber-100); color: var(--c-amber-500); }
.mrm__pill--info { background: var(--c-sky-100);   color: var(--c-sky-600); }

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
.mrm__veredicto {
  display: flex; gap: 20px; align-items: center; justify-content: space-between; flex-wrap: wrap;
  background: #fff; border: 1px solid var(--c-slate-200); border-left: 4px solid var(--c-slate-300);
  border-radius: 14px; padding: 18px 20px; margin-bottom: 6px;
}
/* La merma es inevitable y no es culpa de nadie: ámbar para "mirá esto", nunca rojo. */
.mrm__veredicto--alerta { border-left-color: var(--c-amber-500); background: var(--c-amber-50, #FFFBEB); }
.mrm__veredicto--ok     { border-left-color: var(--c-leaf-600); }
.mrm__veredicto--mudo   { border-left-color: var(--c-slate-300); }
.mrm__ver-texto  { min-width: 0; flex: 1 1 320px; }
.mrm__ver-frase  { margin: 0; font-size: var(--fs-16); font-weight: 600; color: var(--c-ink-900); line-height: 1.45; }
.mrm__ver-motor  { margin: 7px 0 0; font-size: var(--fs-14); color: var(--c-ink-700); }
.mrm__ver-pie    { margin: 9px 0 0; font-size: var(--fs-12); color: var(--c-ink-500); font-family: var(--font-mono); }

.mrm__tendencia { display: flex; flex-direction: column; gap: 6px; align-items: flex-end; }
.mrm__barras    { display: flex; align-items: flex-end; gap: 5px; height: 62px; }
.mrm__barra-col { display: flex; flex-direction: column; align-items: center; gap: 4px; height: 100%; justify-content: flex-end; }
.mrm__barra     { width: 16px; background: var(--c-leaf-600); border-radius: 3px 3px 0 0; min-height: 2px; }
.mrm__barra-lbl { font-size: 10px; color: var(--c-ink-500); font-family: var(--font-mono); }
.mrm__tendencia-lbl { font-size: var(--fs-12); color: var(--c-ink-500); }

.mrm__delta { font-family: var(--font-mono); font-weight: 600; }
.mrm__delta.is-alto { color: var(--c-amber-500); }
.mrm__delta.is-bajo { color: var(--c-leaf-600); }
.mrm__delta.is-mudo { color: var(--c-ink-500); font-weight: 400; }

/* ── ③ El corte ─────────────────────────────────────────────────────────────── */
.mrm__corte {
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  flex-wrap: wrap; margin: 4px 0 8px;
}
.mrm__contador {
  display: inline-block; margin-left: 7px; padding: 1px 9px; border-radius: 999px;
  background: var(--c-amber-100); color: var(--c-amber-500);
  font-size: var(--fs-13); font-weight: 700; font-family: var(--font-mono);
}

@media (max-width: 640px) {
  .mrm__pendiente { flex-direction: column; align-items: stretch; }
}
</style>
