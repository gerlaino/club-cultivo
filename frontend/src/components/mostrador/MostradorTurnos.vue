<template>
  <div class="trn">
    <div class="trn__hd">
      <!-- Quién es lo dice el backend con la primera carga: hasta entonces no se adivina el texto,
           que un segundo después cambiaba delante del admin. -->
      <p v-if="cargado" class="trn__sub">
        {{ gestiona
           ? 'Tocá un día y se abren sus cierres, con la cuenta a la vista.'
           : 'Los cierres que hiciste vos. Si mañana te preguntan por una diferencia, está acá.' }}
      </p>
      <p v-else class="trn__sub">&nbsp;</p>
      <button v-if="turnos.length || pendientes.length" class="trn__btn trn__btn--mini trn__btn--ghost"
              :disabled="bajando" @click="descargar">
        {{ bajando ? 'Preparando…' : 'Descargar CSV' }}
      </button>
    </div>

    <!-- LA LISTA DE TRABAJO VA ARRIBA DE LA GRILLA, no enterrada en ella. Es una lista que se
         vacía; como puntitos dispersos en tres meses, nadie los caza. Cuando está vacía no ocupa
         lugar. -->
    <div v-if="gestiona && pendientes.length" class="trn__pend">
      <span class="trn__pend-lbl">
        {{ pendientes.length }} {{ pendientes.length === 1 ? 'cierre' : 'cierres' }} para mirar
      </span>
      <button v-for="t in pendientes" :key="t.id" class="trn__pend-btn" type="button" @click="irA(t)">
        {{ diaCorto(t.cerrado_at) }} · {{ veredicto(t).texto.toLowerCase() }}
      </button>
    </div>

    <div class="trn__cal-wrap">
      <!-- ══ EL CALENDARIO: fechas, no tarjetas (idea de Germán). El estado va en una marca y el
           detalle al lado. Un número por día; el ámbar salta solo y no hay nada que leer hasta
           que tocás. ══ -->
      <div class="trn__cal-box">
        <div class="trn__cal-hd">
          <h3 class="trn__cal-titulo">{{ nombreMes }}</h3>
          <div class="trn__cal-nav">
            <button type="button" class="trn__cal-btn" aria-label="Mes anterior" @click="moverMes(-1)">‹</button>
            <button type="button" class="trn__cal-btn" aria-label="Mes siguiente" :disabled="esMesActual" @click="moverMes(1)">›</button>
          </div>
        </div>
        <div class="trn__cal" role="grid" :aria-label="`Cierres de ${nombreMes}`" :aria-busy="String(cargando)">
          <span v-for="(d, i) in DOW" :key="i" class="trn__dow" aria-hidden="true">{{ d }}</span>
          <template v-for="c in celdas" :key="c.clave">
            <span v-if="c.vacia" class="trn__dia trn__dia--vacia"></span>
            <button v-else type="button" class="trn__dia"
                    :class="{ 'is-off': !c.cierres.length, 'is-warn': c.warn, 'is-sel': c.clave === seleccionado,
                              'is-hoy': c.hoy, 'is-dos': c.cierres.length > 1 }"
                    :disabled="!c.cierres.length" :aria-label="rotulo(c)" :aria-pressed="String(c.clave === seleccionado)"
                    @click="seleccionado = c.clave">
              {{ c.dia }}<span class="trn__marca"></span>
            </button>
          </template>
        </div>
        <div class="trn__cal-leg">
          <span><i class="trn__leg-ok"></i>se cerró caja</span>
          <span><i class="trn__leg-warn"></i>faltó producto o plata</span>
        </div>
        <p v-if="!cargando && !turnos.length" class="trn__vacio">
          {{ gestiona ? 'Ningún cierre en este mes.' : 'No cerraste ninguna caja en este mes.' }}
        </p>
      </div>

      <!-- ══ EL DÍA, AL LADO. Sus cierres ya desplegados, con sus oraciones y sus botones. No es
           un modal con otro modal adentro: un cierre por día —el caso normal— es una pantalla. ══ -->
      <div class="trn__panel">
        <template v-if="diaElegido">
          <h3 class="trn__panel-titulo">{{ diaElegido.nombre }}</h3>
          <p class="trn__panel-sub">
            {{ diaElegido.cierres.length }} {{ diaElegido.cierres.length === 1 ? 'cierre' : 'cierres' }}
            <template v-if="entregadoDelDia(diaElegido) > 0"> · entregó ${{ fmt(entregadoDelDia(diaElegido)) }}</template>
          </p>

          <article v-for="t in diaElegido.cierres" :key="t.id" class="trn__cierre">
            <div class="trn__cierre-meta">
              <span><span class="trn__hora">{{ horario(t) }}</span> · {{ quien(t) }}</span>
              <span v-if="t.revisado" class="trn__pill trn__pill--ok">Visto</span>
              <span v-else class="trn__pill" :class="veredicto(t).clase">{{ veredicto(t).texto }}</span>
            </div>
            <p v-for="(h, i) in hechosDelCierre(t)" :key="i" class="trn__hecho" :class="`trn__hecho--${h.tono}`"
               v-html="h.texto"></p>

            <!-- SÓLO EL ÚLTIMO SE CORRIGE. Si después se abrió otra caja, se volvió a contar y la
                 diferencia se arregla ahí. Lo decide el backend (`bloqueo_correccion`); acá se
                 DICE, no se esconde el botón sin explicar. -->
            <p v-if="t.puedo_corregir && t.bloqueo_correccion" class="trn__bloqueo">{{ t.bloqueo_correccion.texto }}</p>

            <!-- Quien cerró corrige el suyo (`puedo_corregir`, lo decide el backend): un dedazo no
                 tiene que esperar al admin. «Ya lo miré» sigue siendo de administración. -->
            <div v-if="gestiona || t.puedo_corregir" class="trn__acc">
              <button v-if="gestiona && !t.revisado" class="trn__btn trn__btn--ghost" type="button"
                      :disabled="marcando === t.id" @click="marcarVisto(t)">
                {{ marcando === t.id ? 'Guardando…' : 'Ya lo miré' }}
              </button>
              <button v-if="!t.bloqueo_correccion" class="trn__btn trn__btn--primary" type="button" @click="corrigiendo = t">
                Corregir el conteo
              </button>
              <button v-else-if="t.bloqueo_correccion.motivo === 'visto'" class="trn__btn trn__btn--ghost" type="button" @click="corrigiendo = t">
                Reabrir para revisión
              </button>
            </div>
          </article>
        </template>
        <p v-else-if="cargando" class="trn__vacio">Buscando…</p>
        <p v-else class="trn__vacio">
          {{ turnos.length ? 'Elegí un día del calendario.' : 'Cuando haya cierres, acá se leen día por día.' }}
        </p>
      </div>
    </div>

    <p v-if="!gestiona && turnos.length" class="trn__nota">
      ¿Contaste mal alguno? Avisale a administración: el conteo se corrige desde acá, sin borrar
      nada — se asienta la diferencia.
    </p>

    <CorregirConteo v-if="corrigiendo" :sede-id="sedeId" :turno="corrigiendo" :gestiona="gestiona"
                    @cerrar="corrigiendo = null" @corregido="recargar" @revisado="reflejarVisto" />
  </div>
</template>

<script setup>
// LOS CIERRES, EN UN CALENDARIO (sep-2026, idea de Germán).
//
// Era una lista agrupada por día. La pregunta del admin es «¿cómo fue el martes?», y una grilla
// del mes la contesta para todos los días a la vez: con cada día marcado se ve el PATRÓN —si
// falta los viernes, si empezó el día que cambió el turno, si es un goteo o un día suelto—. Eso
// la lista no lo mostraba ni scrolleando. Y buscar una fecha es tocarla.
//
// Administración ve todos; el que atiende ve LOS SUYOS —el backend filtra, no la pantalla.
import { ref, computed, watch } from 'vue'
import CorregirConteo from './CorregirConteo.vue'
import { listTurnosMostrador, revisarTurnoMostrador, descargarTurnosMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { hechosDelCierre } from '../../lib/hechosDelCierre.js'
import { hoyISO } from '../../utils/dates.js'

const props = defineProps({ sedeId: { type: Number, default: null } })
const emit = defineEmits(['sin-revisar'])

const toast    = useToast()
const turnos   = ref([])        // los del mes que se mira
const pendientes = ref([])      // «para mirar», de cualquier mes
const gestiona = ref(false)
const cargando = ref(false)
const cargado  = ref(false)
const bajando  = ref(false)
const marcando = ref(null)
const corrigiendo = ref(null)
const seleccionado = ref(null)  // clave del día elegido: 'YYYY-M-D'

// El mes que se mira, como primer día en hora LOCAL. `toISOString()` es UTC y de noche da
// mañana: todo lo que diga «hoy» acá sale de los componentes locales.
const hoy = new Date()
const mes = ref(new Date(hoy.getFullYear(), hoy.getMonth(), 1))
const esMesActual = computed(() =>
  mes.value.getFullYear() === hoy.getFullYear() && mes.value.getMonth() === hoy.getMonth())
const mesParam = computed(() => `${mes.value.getFullYear()}-${String(mes.value.getMonth() + 1).padStart(2, '0')}`)

const DOW   = ['L', 'M', 'M', 'J', 'V', 'S', 'D']
const DIAS  = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
               'septiembre', 'octubre', 'noviembre', 'diciembre']
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)
const nombreMes = computed(() => `${cap(MESES[mes.value.getMonth()])} ${mes.value.getFullYear()}`)

// POR QUÉ UN CIERRE PIDE UNA MIRADA, con el nombre que usa la gente. La plata primero: es lo
// que un admin quiere que le griten. Los ids salen del MISMO `Mostradores::MotivosDeRevision`
// que el badge — si la pantalla decidiera por su cuenta, un día el badge diría 2 y acá otra cosa.
const MOTIVO = {
  faltante:    'Falta producto',
  sobrante:    'Contó de más',
  corregido:   'Se corrigió al abrir',
  mesa_movida: 'Se movió la mesa',
}
const PRIORIDAD = ['caja', 'faltante', 'sobrante', 'mesa_movida', 'corregido']
const motivoPrincipal = (t) => PRIORIDAD.find(m => (t.motivos_revision || []).includes(m)) || null

function veredicto (t) {
  const m = motivoPrincipal(t)
  if (m === 'caja') {
    const d = Number(t.caja?.diferencia_ars) || 0
    return { texto: d < 0 ? 'Falta plata' : 'Sobra plata', clase: 'trn__pill--warn' }
  }
  if (m === 'faltante') return { texto: 'Falta producto', clase: 'trn__pill--warn' }
  if (m === 'sobrante') return { texto: 'Contó de más',   clase: 'trn__pill--warn' }
  if (m)                return { texto: MOTIVO[m],        clase: 'trn__pill--info' }
  return { texto: 'Sin novedad', clase: 'trn__pill--ok' }
}
// Lo que pinta el día de ámbar: faltó producto o plata. Lo demás es contexto, no marca.
const pideMirada = (t) => ['caja', 'faltante', 'sobrante'].includes(motivoPrincipal(t))

// ── LA GRILLA ──────────────────────────────────────────────────────────────────────────────
// Se agrupa por el día del CIERRE: una caja que cruzó la medianoche cuenta en el día que cerró,
// que es cuando se contó y cuando se asentó la diferencia.
const claveDe = (d) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
const porDia = computed(() => {
  const mapa = new Map()
  for (const t of turnos.value) {
    if (!t.cerrado_at) continue
    const c = new Date(t.cerrado_at)
    const k = claveDe(c)
    if (!mapa.has(k)) {
      mapa.set(k, { clave: k, fecha: c, nombre: cap(`${DIAS[c.getDay()]} ${c.getDate()} de ${MESES[c.getMonth()]}`), cierres: [] })
    }
    mapa.get(k).cierres.push(t)
  }
  // Dentro del día, del más temprano al más tarde: se lee como pasó.
  for (const d of mapa.values()) d.cierres.sort((a, b) => (a.cerrado_at < b.cerrado_at ? -1 : 1))
  return mapa
})

const celdas = computed(() => {
  const y = mes.value.getFullYear(), m = mes.value.getMonth()
  const primero = new Date(y, m, 1)
  const dias = new Date(y, m + 1, 0).getDate()
  // Lunes primero: getDay() da 0 para el domingo.
  const huecos = (primero.getDay() + 6) % 7
  const out = []
  for (let i = 0; i < huecos; i++) out.push({ clave: `v${i}`, vacia: true })
  for (let d = 1; d <= dias; d++) {
    const fecha = new Date(y, m, d)
    const k = claveDe(fecha)
    const cierres = porDia.value.get(k)?.cierres || []
    out.push({ clave: k, dia: d, cierres, warn: cierres.some(pideMirada), hoy: k === claveDe(hoy) })
  }
  return out
})

const diaElegido = computed(() => (seleccionado.value && porDia.value.get(seleccionado.value)) || null)
const entregadoDelDia = (d) => d.cierres.reduce((a, t) => a + (Number(t.dispensado_ars) || 0), 0)

function rotulo (c) {
  if (!c.cierres.length) return `${c.dia}, sin caja`
  const n = c.cierres.length > 1 ? `${c.cierres.length} cierres` : '1 cierre'
  return `${c.dia}, ${n}, ${c.warn ? 'faltó producto o plata' : 'no faltó nada'}`
}

// El día más reciente con cierres arranca elegido: es el que se viene a mirar.
watch(porDia, (mapa) => {
  if (seleccionado.value && mapa.has(seleccionado.value)) return
  const dias = [...mapa.values()].sort((a, b) => a.fecha - b.fecha)
  seleccionado.value = dias.length ? dias[dias.length - 1].clave : null
})

// ── CUÁNDO Y QUIÉN ─────────────────────────────────────────────────────────────────────────
const fmt  = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '')
const diaCorto = (iso) => {
  const d = new Date(iso)
  return `${cap(DIAS[d.getDay()].slice(0, 3))} ${d.getDate()}/${d.getMonth() + 1}`
}

// CUÁNDO FUE, SIN QUE PAREZCA IMPOSIBLE. «14:02 → 12:03» se leía como que cerró antes de abrir:
// era una caja que cruzó la medianoche. Cuando abrió otro día, se dice.
function horario (t) {
  const a = t.abierto_at ? new Date(t.abierto_at) : null
  const c = t.cerrado_at ? new Date(t.cerrado_at) : null
  if (!c) return '—'
  const otroDia = a && a.toDateString() !== c.toDateString()
  return `${otroDia ? `${DIAS[a.getDay()]} ` : ''}${hora(t.abierto_at)} → ${hora(t.cerrado_at)}`
}

// Quién atendió. Es normal que abra el admin a la mañana y cierre contando quien atendió todo el
// día: cuando son dos personas se nombran las dos.
function quien (t) {
  if (t.atendio && t.cerrado_por && t.atendio !== t.cerrado_por) return `abrió ${t.atendio}, cerró ${t.cerrado_por}`
  return t.atendio || t.cerrado_por || 'Alguien'
}

// ── ACCIONES ───────────────────────────────────────────────────────────────────────────────
// Ir a un cierre desde «para mirar»: si es de otro mes, se cambia el mes y se lo elige al llegar.
let irAlLlegar = null
function irA (t) {
  const c = new Date(t.cerrado_at)
  const k = claveDe(c)
  if (c.getFullYear() === mes.value.getFullYear() && c.getMonth() === mes.value.getMonth()) {
    seleccionado.value = k
  } else {
    irAlLlegar = k
    mes.value = new Date(c.getFullYear(), c.getMonth(), 1)
  }
}

function moverMes (delta) {
  mes.value = new Date(mes.value.getFullYear(), mes.value.getMonth() + delta, 1)
}

// SE MARCA Y SE ARCHIVA: no es una lista de sospechosos. El gesto tiene que ser liviano —la
// lista está para vaciarse— y se refleja sin esperar la recarga.
async function marcarVisto (t) {
  marcando.value = t.id
  try {
    await revisarTurnoMostrador(props.sedeId, t.id)
    reflejarVisto({ id: t.id, revisado: true })
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo marcar.')
  } finally { marcando.value = null }
}

function reflejarVisto ({ id, revisado }) {
  const t = turnos.value.find(x => x.id === id)
  if (t) {
    t.revisado = revisado
    // Visto congela la corrección (con llave): el panel lo dice sin volver a pedir.
    if (revisado && !t.bloqueo_correccion) {
      t.bloqueo_correccion = { motivo: 'visto', texto: 'Este cierre ya se miró. Para corregirlo hay que reabrirlo para revisión.' }
    }
    if (!revisado && t.bloqueo_correccion?.motivo === 'visto') t.bloqueo_correccion = null
  }
  if (revisado) pendientes.value = pendientes.value.filter(x => x.id !== id)
  emit('sin-revisar', pendientes.value.length)
  if (!revisado) recargar()
}

async function cargar () {
  if (!props.sedeId) return
  cargando.value = true
  try {
    const { data } = await listTurnosMostrador(props.sedeId, { mes: mesParam.value })
    turnos.value   = data.turnos || []
    gestiona.value = !!data.gestiona
    cargado.value  = true
    if (irAlLlegar) { seleccionado.value = irAlLlegar; irAlLlegar = null }
    if (gestiona.value) {
      const p = await listTurnosMostrador(props.sedeId, { sin_revisar: 1 })
      pendientes.value = p.data.turnos || []
      emit('sin-revisar', p.data.sin_revisar ?? pendientes.value.length)
    } else {
      pendientes.value = []
    }
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron cargar los cierres.')
  } finally {
    cargando.value = false
  }
}
const recargar = () => cargar()

// Se arma el archivo en el backend y se baja acá. El nombre lo pone el servidor (sede + fecha):
// tres archivos "arqueos.csv" en la carpeta de descargas no le sirven a nadie.
async function descargar () {
  bajando.value = true
  try {
    const res  = await descargarTurnosMostrador(props.sedeId)
    const nombre = /filename="?([^"]+)"?/.exec(res.headers['content-disposition'] || '')?.[1]
    const url  = URL.createObjectURL(new Blob([res.data], { type: 'text/csv;charset=utf-8' }))
    const a    = document.createElement('a')
    a.href = url
    a.download = nombre || `arqueos-${hoyISO()}.csv`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
  } catch {
    toast.error('No se pudo descargar el historial.')
  } finally { bajando.value = false }
}

// Cambiar de sede vuelve al mes actual: octubre de Norte no es octubre de Centro.
watch(() => props.sedeId, () => {
  mes.value = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  seleccionado.value = null
  cargar()
}, { immediate: true })
watch(mes, () => { seleccionado.value = null; cargar() })
</script>

<style scoped>
.trn__hd {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 12px; flex-wrap: wrap; margin-bottom: 14px;
}
.trn__sub   { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }
.trn__vacio { margin: 10px 0 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.trn__nota  { margin: 12px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }

/* ── «Para mirar», arriba de todo ─────────────────────────────────────────── */
.trn__pend {
  display: flex; gap: 8px; align-items: center; flex-wrap: wrap;
  background: var(--c-amber-100, #fef3c7); border-radius: 10px; padding: 9px 12px; margin-bottom: 14px;
}
.trn__pend-lbl { font-size: var(--fs-13); font-weight: 700; color: var(--c-amber-700, #b45309); }
.trn__pend-btn {
  border: 0; background: #fff; border-radius: 8px; padding: 4px 10px;
  font: inherit; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); cursor: pointer;
}
.trn__pend-btn:hover { color: var(--c-ink-900); }

/* ── Calendario a la izquierda, el día a la derecha ───────────────────────── */
.trn__cal-wrap { display: grid; grid-template-columns: 340px minmax(0, 1fr); gap: 22px; align-items: start; }
.trn__cal-box { border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 14px 14px 12px; background: #fff; }
.trn__cal-hd { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px; }
.trn__cal-titulo { margin: 0; font-size: var(--fs-15, .95rem); font-weight: 700; color: var(--c-ink-900); }
.trn__cal-nav { display: flex; gap: 4px; }
.trn__cal-btn {
  border: 1px solid var(--c-slate-200); background: #fff; border-radius: 8px; width: 30px; height: 30px;
  font: inherit; font-size: var(--fs-15, .95rem); cursor: pointer; color: var(--c-ink-700);
}
.trn__cal-btn:disabled { opacity: .4; cursor: default; }
.trn__cal { display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px; }
.trn__dow { font-size: 10px; letter-spacing: .06em; text-transform: uppercase; color: var(--c-ink-500); font-weight: 700; text-align: center; padding: 4px 0 6px; }

/* Un número por día y una marca debajo. El estado es la marca, no un texto. */
.trn__dia {
  position: relative; height: 42px; border: 0; border-radius: 8px; background: transparent;
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px;
  font: inherit; font-weight: 600; font-size: var(--fs-13); color: var(--c-ink-900); cursor: pointer;
}
.trn__dia--vacia { visibility: hidden; }
.trn__dia.is-off { color: var(--c-ink-400, #9aa0aa); font-weight: 400; cursor: default; }
.trn__dia:not(.is-off):hover { background: var(--c-slate-50, #f8fafc); }
.trn__marca { width: 6px; height: 6px; border-radius: 3px; background: var(--c-slate-300); }
.trn__dia.is-off .trn__marca { background: transparent; }
/* Ámbar y no rojo: una diferencia es un dato que se anota, no una falta que alguien explica. */
.trn__dia.is-warn { color: var(--c-amber-700, #b45309); font-weight: 800; }
.trn__dia.is-warn .trn__marca { background: var(--c-amber-500, #d97706); }
.trn__dia.is-dos .trn__marca { width: 14px; }
.trn__dia.is-sel { background: var(--c-leaf-800, #14532d); color: #fff; }
.trn__dia.is-sel .trn__marca { background: #fff; }
.trn__dia.is-hoy::after { content: ''; position: absolute; inset: 3px; border: 1px dashed var(--c-ink-400, #9aa0aa); border-radius: 7px; pointer-events: none; }
.trn__cal-leg { display: flex; gap: 14px; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 10px; flex-wrap: wrap; }
.trn__cal-leg i { display: inline-block; width: 6px; height: 6px; border-radius: 3px; vertical-align: 1px; margin-right: 6px; }
.trn__leg-ok   { background: var(--c-slate-300); }
.trn__leg-warn { background: var(--c-amber-500, #d97706); }

/* El panel del día */
.trn__panel { border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 16px 18px; min-height: 200px; background: #fff; }
.trn__panel-titulo { margin: 0; font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); }
.trn__panel-sub { margin: 2px 0 12px; font-size: var(--fs-13); color: var(--c-ink-500); }
.trn__cierre { border-top: 1px solid var(--c-slate-100); padding: 14px 0 6px; }
.trn__cierre:first-of-type { border-top: 0; padding-top: 0; }
.trn__cierre-meta { display: flex; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; font-size: var(--fs-14); color: var(--c-ink-700); }
.trn__hora { font-family: var(--font-mono); font-size: var(--fs-13); color: var(--c-ink-500); }
.trn__hecho { margin: 0 0 8px; padding: 10px 12px; border-radius: 8px; background: var(--c-slate-50, #f8fafc); font-size: var(--fs-14); color: var(--c-ink-900); line-height: 1.45; }
.trn__hecho--warn { background: var(--c-amber-100, #fef3c7); }
.trn__hecho :deep(small) { display: block; color: var(--c-ink-700); font-size: var(--fs-12); margin-top: 2px; }
.trn__bloqueo { margin: 8px 0 0; font-size: var(--fs-12); color: var(--c-ink-500); border-left: 3px solid var(--c-slate-200); padding-left: 10px; }
.trn__acc { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; flex-wrap: wrap; }

.trn__pill { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-12); font-weight: 600; white-space: nowrap; }
.trn__pill--ok   { background: var(--c-leaf-100); color: var(--c-leaf-700); }
.trn__pill--warn { background: var(--c-amber-100, #fef3c7); color: var(--c-amber-700, #b45309); }
.trn__pill--info { background: var(--c-sky-100, #e0f2fe); color: var(--c-sky-600, #0284c7); }

.trn__btn {
  border-radius: 9px; padding: 9px 16px; font: inherit; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.trn__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
.trn__btn--primary { background: var(--c-leaf-800, #14532d); color: #fff; }
.trn__btn--mini    { padding: 6px 12px; font-size: var(--fs-13); }
.trn__btn:disabled { opacity: .6; cursor: default; }

@media (max-width: 760px) {
  .trn__cal-wrap { grid-template-columns: 1fr; }
}
</style>
