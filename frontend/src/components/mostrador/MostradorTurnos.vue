<template>
  <div class="trn">
    <div class="trn__hd">
      <p class="trn__sub">
        {{ gestiona
           ? 'Cada cierre con su conteo y su arqueo, del más nuevo al más viejo.'
           : 'Los cierres que hiciste vos. Si mañana te preguntan por una diferencia, está acá.' }}
      </p>
      <div class="trn__hd-acc">
        <!-- LA LISTA DE TRABAJO ES UN FILTRO DE ESTA LISTA, no otra pantalla.
             «Para mirar» vivía en la solapa de Merma: la misma lista de cierres, filtrada, con
             otro nombre y en el lugar donde se va a ANALIZAR, no a trabajar. Acá es lo que
             siempre fue — un filtro. -->
        <div v-if="gestiona && (sinRevisar || soloPendientes)" class="trn__filtros">
          <button class="trn__filtro" :class="{ 'is-on': !soloPendientes }"
                  @click="filtrar(false)">Todos</button>
          <button class="trn__filtro" :class="{ 'is-on': soloPendientes }"
                  @click="filtrar(true)">
            Para mirar
            <span v-if="sinRevisar" class="trn__filtro-n">{{ sinRevisar }}</span>
          </button>
        </div>
        <span v-if="total" class="trn__total">{{ total }} cierre{{ total === 1 ? '' : 's' }}</span>
        <button v-if="total" class="trn__btn trn__btn--mini trn__btn--ghost"
                :disabled="bajando" @click="descargar">
          {{ bajando ? 'Preparando…' : 'Descargar CSV' }}
        </button>
      </div>
    </div>

    <p v-if="cargando" class="trn__vacio">Buscando…</p>
    <!-- Cada uno con su vacío: al admin decirle "no cerraste ninguno" es contarle algo que
         no es suyo — él no atiende, mira los de los demás. -->
    <p v-else-if="!turnos.length && soloPendientes" class="trn__vacio">
      Nada para mirar: todos los cierres están vistos.
    </p>
    <p v-else-if="!turnos.length" class="trn__vacio">
      {{ gestiona ? 'Todavía no se cerró ninguna caja en esta sede.'
                  : 'Todavía no cerraste ninguna caja acá.' }}
    </p>

    <!-- UNA LÍNEA POR CIERRE, Y SE ABRE LA QUE INTERESA.
         Era una tabla de cinco columnas —CIERRE · ENTREGADO · FALTÓ · CAJA— con «—» en casi todas
         las celdas y el dato accionable ausente: decía «en 1 producto» sin decir cuál. Ahora la
         fila cuenta qué pasó, en oraciones, y el detalle está a un toque. -->
    <div v-else class="trn__lista">
      <div v-for="t in turnos" :key="t.id" class="trn__c" :data-abierta="abiertas.has(t.id)">
        <button class="trn__c-hd" @click="alternar(t.id)">
          <span class="trn__c-txt">
            <span class="trn__c-cuando">{{ cuando(t) }}</span>
            <span class="trn__c-quien">{{ quien(t) }}</span>
          </span>
          <span class="trn__pill" :class="veredicto(t).clase">{{ veredicto(t).texto }}</span>
          <i class="bi bi-chevron-right trn__c-arr"></i>
        </button>

        <div v-if="abiertas.has(t.id)" class="trn__c-body">
          <!-- ① LA MERCADERÍA. Con el producto por su NOMBRE: es lo único con lo que se puede
               ir a buscar algo. -->
          <p v-for="(f, i) in (t.faltaron?.items || [])" :key="`f${i}`" class="trn__f trn__f--warn">
            Faltan <b>{{ fmt(f.cantidad) }} {{ f.unidad }}</b> de <b>{{ f.etiqueta }}</b>.
            <small>
              Sobre la mesa tenía que haber {{ fmt(f.esperado) }} {{ f.unidad }} y al contar
              aparecieron {{ fmt(f.contado) }}. Producir esos {{ fmt(f.cantidad) }} {{ f.unidad }}
              costó ${{ fmt(f.ars) }}.
            </small>
          </p>
          <p v-if="restantes(t.faltaron)" class="trn__f trn__f--warn">
            Y en {{ restantes(t.faltaron) }} producto{{ restantes(t.faltaron) === 1 ? '' : 's' }} más.
          </p>

          <!-- ② LO QUE SE CONTÓ DE MÁS. Es otra cosa y se explica distinto. -->
          <p v-for="(f, i) in (t.sobraron?.items || [])" :key="`s${i}`" class="trn__f trn__f--warn">
            Contó <b>{{ fmt(f.cantidad) }} {{ f.unidad }}</b> de más de <b>{{ f.etiqueta }}</b>.
            <small>
              No se sumaron al inventario: el mostrador descuenta producto, nunca lo carga. Si de
              verdad hay {{ fmt(f.cantidad) }} {{ f.unidad }} más, los sube administración desde
              el depósito.
            </small>
          </p>

          <p v-if="todoEnOrden(t)" class="trn__f trn__f--ok">
            Contó {{ t.productos }} producto{{ t.productos === 1 ? '' : 's' }} y estaba todo.
            <template v-if="t.dispensado_ars > 0">Entregó ${{ fmt(t.dispensado_ars) }}.</template>
          </p>

          <!-- ③ LA PLATA, con la cuenta hecha. «$130.000, faltó $20.000» no se puede comprobar. -->
          <p v-if="t.caja" class="trn__f" :class="t.caja.diferencia_ars ? 'trn__f--warn' : 'trn__f--ok'">
            En la caja había <b>${{ fmt(t.caja.contado_ars) }}</b><template v-if="t.caja.diferencia_ars">
              — <b>${{ fmt(Math.abs(t.caja.diferencia_ars)) }}
              {{ t.caja.diferencia_ars < 0 ? 'menos' : 'más' }}</b> de lo que tenía que haber</template
            ><template v-else>, lo que tenía que haber</template>.
            <small v-if="t.caja.fondo_ars != null">
              Empezó con ${{ fmt(t.caja.fondo_ars) }} de fondo; tenía que haber
              ${{ fmt(t.caja.esperado_ars) }}.
            </small>
          </p>

          <!-- ④ LO DEMÁS, en oraciones. Antes eran chips y un «+2 más» que escondía el resto. -->
          <p v-for="m in otrosMotivos(t)" :key="m" class="trn__f">{{ MOTIVO_FRASE[m] }}</p>

          <p v-if="t.revisado" class="trn__visto">Ya está mirado.</p>
          <div v-else-if="gestiona" class="trn__c-acc">
            <button class="trn__btn" :class="pideAtencion(t) ? 'trn__btn--primary' : 'trn__btn--ghost'"
                    @click="corrigiendo = t">Corregir lo que se contó</button>
            <button v-if="pideAtencion(t)" class="trn__btn trn__btn--ghost"
                    @click="marcarVisto(t)">Está bien, ya lo miré</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Paginado: sólo aparece cuando hay más de una página, y dice en cuál está. -->
    <div v-if="paginas > 1" class="trn__pag">
      <button class="trn__btn trn__btn--mini trn__btn--ghost" :disabled="pagina === 1"
              @click="irA(pagina - 1)">Anterior</button>
      <span class="trn__pag-txt">Página {{ pagina }} de {{ paginas }}</span>
      <button class="trn__btn trn__btn--mini trn__btn--ghost" :disabled="pagina === paginas"
              @click="irA(pagina + 1)">Siguiente</button>
    </div>

    <p v-if="!gestiona && turnos.length" class="trn__nota">
      ¿Contaste mal alguno? Avisale a administración: el conteo se corrige desde acá, sin borrar
      nada — se asienta la diferencia.
    </p>

    <CorregirConteo v-if="corrigiendo" :sede-id="sedeId" :turno="corrigiendo"
                    @cerrar="corrigiendo = null" @corregido="cargar" />
  </div>
</template>

<script setup>
// LOS TURNOS QUE YA CERRARON.
//
// El que atiende cerraba su turno y no tenía dónde mirarlo después: si al día siguiente le
// preguntan por una diferencia, no tenía con qué. Administración ve todos; él ve LOS SUYOS —el
// backend filtra, no la pantalla.
import { ref, watch } from 'vue'
import CorregirConteo from './CorregirConteo.vue'
import { listTurnosMostrador, descargarTurnosMostrador, revisarTurnoMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ sedeId: { type: Number, default: null } })

const toast    = useToast()
const turnos   = ref([])
const gestiona = ref(false)
const cargando = ref(false)
const corrigiendo = ref(null)
// Paginado del BACKEND: un mostrador con un año de arqueos son cientos de turnos, y traerlos
// todos para mostrar veinte es hacer esperar a alguien que está atendiendo.
const pagina   = ref(1)
const paginas  = ref(1)
const total    = ref(0)
const bajando  = ref(false)
const soloPendientes = ref(false)
const sinRevisar     = ref(0)
const emit = defineEmits(['sin-revisar'])

// POR QUÉ UN CIERRE PIDE UNA MIRADA, con el nombre que usa la gente.
//
// Salió de la solapa de Merma junto con la lista. Y en castellano: «Contó de más — no se cargó al
// inventario» describía la implementación, no lo que pasó.
const MOTIVO = {
  faltante:    'Falta producto',
  sobrante:    'Contó de más',
  corregido:   'Se corrigió al abrir',
  mesa_movida: 'Se movió la mesa',
}
// Los motivos que NO son la mercadería van como oración al pie, no como chip: un «+2 más»
// esconde justo lo que hay que leer.
const MOTIVO_FRASE = {
  corregido:   'Al abrir corrigió lo que había sobre la mesa.',
  mesa_movida: 'Mientras la caja estuvo abierta, administración movió lo que había sobre la mesa.',
}
const TONO = { faltante: 'warn', sobrante: 'warn', corregido: 'info', mesa_movida: 'info' }

const abiertas = ref(new Set())
function alternar (id) {
  const s = new Set(abiertas.value)
  s.has(id) ? s.delete(id) : s.add(id)
  abiertas.value = s
}

const DIAS  = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
               'septiembre', 'octubre', 'noviembre', 'diciembre']

// CUÁNDO FUE, SIN QUE PAREZCA IMPOSIBLE.
//
// Decía «5/9 · 14:02–12:03», que se lee como que cerró antes de abrir: era una caja que cruzó la
// medianoche y sólo se mostraba la fecha del CIERRE. Una fila imposible te hace desconfiar de
// toda la tabla. Cuando abrió otro día, se dice.
function cuando (t) {
  const a = t.abierto_at ? new Date(t.abierto_at) : null
  const c = t.cerrado_at ? new Date(t.cerrado_at) : null
  if (!c) return '—'
  const dia = `${DIAS[c.getDay()]} ${c.getDate()} de ${MESES[c.getMonth()]}`
  return dia.charAt(0).toUpperCase() + dia.slice(1)
}

function quien (t) {
  const a = t.abierto_at ? new Date(t.abierto_at) : null
  const c = t.cerrado_at ? new Date(t.cerrado_at) : null
  const otroDia = a && c && a.toDateString() !== c.toDateString()
  const cierre = otroDia ? `${hora(t.cerrado_at)} del ${DIAS[c.getDay()]}` : hora(t.cerrado_at)

  // Es normal que abra el admin a la mañana y cierre contando quien atendió todo el día: cuando
  // son dos personas se nombran las dos, y si no alcanza con una.
  if (t.atendio && t.cerrado_por && t.atendio !== t.cerrado_por) {
    return `Abrió ${t.atendio} ${hora(t.abierto_at)} · cerró ${t.cerrado_por} ${cierre}`
  }
  return `${t.atendio || t.cerrado_por || 'Alguien'}, de ${hora(t.abierto_at)} a ${cierre}`
}

// El veredicto de la fila: lo que se lee sin abrir nada.
function veredicto (t) {
  const m = motivoPrincipal(t)
  if (m === 'faltante') return { texto: 'Falta producto', clase: 'trn__pill--warn' }
  if (m === 'sobrante') return { texto: 'Contó de más',   clase: 'trn__pill--warn' }
  if (m)                return { texto: MOTIVO[m],        clase: 'trn__pill--info' }
  return { texto: 'Sin novedad', clase: 'trn__pill--ok' }
}

const pideAtencion = (t) => !!motivoPrincipal(t)
const restantes    = (d) => Math.max(0, (d?.total || 0) - (d?.items?.length || 0))
const todoEnOrden  = (t) => !(t.faltaron?.total) && !(t.sobraron?.total)
// Los que ya se contaron arriba no se repiten: la mercadería tiene su propia oración.
const otrosMotivos = (t) => (t.motivos_revision || []).filter(m => MOTIVO_FRASE[m])
// EL QUE MANDA, no los tres. Un faltante es lo que se sale a buscar; que se haya corregido al
// abrir es contexto. Tres chips en una fila obligan a leer los tres para saber cuál importa.
const PRIORIDAD = ['faltante', 'sobrante', 'mesa_movida', 'corregido']
const motivoPrincipal = (t) =>
  PRIORIDAD.find(m => (t.motivos_revision || []).includes(m)) || null

function filtrar (soloPend) {
  soloPendientes.value = soloPend
  pagina.value = 1
  cargar()
}

// Se marca y se archiva: no es una lista de sospechosos. Se saca de la lista en el acto en vez de
// esperar la recarga — con el filtro puesto, ver la fila quedarse ahí se lee como que no anduvo.
async function marcarVisto (t) {
  try {
    await revisarTurnoMostrador(props.sedeId, t.id)
    t.revisado = true
    sinRevisar.value = Math.max(0, sinRevisar.value - 1)
    emit('sin-revisar', sinRevisar.value)
    if (soloPendientes.value) turnos.value = turnos.value.filter(x => x.id !== t.id)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo marcar como visto.')
  }
}

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')
const hora  = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '')

async function cargar () {
  if (!props.sedeId) return
  cargando.value = true
  try {
    const params = { pagina: pagina.value }
    if (soloPendientes.value) params.sin_revisar = 1
    const { data } = await listTurnosMostrador(props.sedeId, params)
    turnos.value   = data.turnos || []
    gestiona.value = !!data.gestiona
    paginas.value  = data.paginas || 1
    total.value    = data.total ?? turnos.value.length
    sinRevisar.value = data.sin_revisar ?? 0
    emit('sin-revisar', sinRevisar.value)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron cargar los cierres.')
  } finally {
    cargando.value = false
  }
}

function irA (n) {
  if (n < 1 || n > paginas.value || n === pagina.value) return
  pagina.value = n
  cargar()
}

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
    a.download = nombre || `arqueos-${new Date().toISOString().slice(0, 10)}.csv`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
  } catch {
    toast.error('No se pudo descargar el historial.')
  } finally { bajando.value = false }
}

// Cambiar de sede vuelve a la primera página: quedarse en la 4 de un mostrador que tiene 2 es
// mostrar una lista vacía sin explicar por qué.
watch(() => props.sedeId, () => { pagina.value = 1; cargar() }, { immediate: true })
</script>

<style scoped>
.trn__hd {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 12px; flex-wrap: wrap; margin-bottom: 14px;
}
.trn__hd-acc { display: flex; align-items: center; gap: 10px; }
.trn__total  { font-size: var(--fs-13); color: var(--c-ink-500); font-family: var(--font-mono); }
.trn__sub   { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }

.trn__pag {
  display: flex; align-items: center; justify-content: center; gap: 14px; margin-top: 14px;
}
.trn__pag-txt { font-size: var(--fs-13); color: var(--c-ink-500); }
.trn__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.trn__nota  { margin: 12px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }

.trn__table-wrap {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 14px; overflow-x: auto;
}
.trn__table { width: 100%; border-collapse: collapse; }
.trn__table th {
  text-align: left; font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
  padding: 13px 16px; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.trn__table td { padding: 14px 16px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.trn__table tbody tr:last-child td { border-bottom: 0; }

.trn__th-num, .trn__td-num { text-align: right; }
.trn__th-acc, .trn__td-acc { text-align: right; white-space: nowrap; }

.trn__cuando { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.trn__meta   { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px; align-items: center; }
.trn__mut    { color: var(--c-ink-500); font-size: var(--fs-13); }
/* TODOS los números de la tabla con el mismo estilo. Antes "Entregado" salía en sans y los
   demás en monoespaciada: la misma tabla con dos tipografías para el mismo tipo de dato. */
.trn__td-num { font-family: var(--font-mono); }
.trn__num    { font-family: var(--font-mono); font-weight: 600; color: var(--c-ink-900); display: block; }
.trn__nada   { color: var(--c-ink-500); }
/* Qué es la cifra de arriba, no otra cifra: va debajo y en la tipografía del texto. */
.trn__pie    { display: block; font-family: var(--font-sans); font-size: var(--fs-12); color: var(--c-ink-500); }
.trn__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }
.trn__ok     { font-size: var(--fs-13); color: var(--c-leaf-600); }

.trn__pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.trn__pill--ok   { background: var(--c-leaf-100); color: var(--c-leaf-700); }

/* ── UNA LÍNEA POR CIERRE, y se abre la que interesa ─────────────────────────── */
.trn__lista { display: flex; flex-direction: column; }
.trn__c     { border-top: 1px solid var(--c-slate-100); }
.trn__c:last-child { border-bottom: 1px solid var(--c-slate-100); }
.trn__c-hd  {
  width: 100%; appearance: none; border: 0; background: none; font: inherit; cursor: pointer;
  text-align: left; display: grid; grid-template-columns: minmax(0,1fr) auto 16px;
  align-items: center; gap: 14px; padding: 15px 6px;
}
.trn__c-hd:hover { background: var(--c-slate-50, #f8fafc); }
.trn__c-txt    { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.trn__c-cuando { font-size: var(--fs-15, .95rem); font-weight: 600; color: var(--c-ink-900); }
.trn__c-quien  { font-size: var(--fs-13); color: var(--c-ink-500); }
.trn__c-arr    { color: var(--c-ink-400, #9aa0aa); font-size: var(--fs-12); transition: transform .16s ease; }
.trn__c[data-abierta="true"] .trn__c-arr { transform: rotate(90deg); }
.trn__c-body   { display: flex; flex-direction: column; gap: 12px; padding: 2px 6px 20px; }

/* La oración, con su barra: el color dice qué clase de hecho es, sin gritar. */
.trn__f {
  margin: 0; padding-left: 13px; border-left: 3px solid var(--c-slate-200);
  font-size: var(--fs-14, .9rem); color: var(--c-ink-700); max-width: 74ch; line-height: 1.5;
}
.trn__f b { color: var(--c-ink-900); font-weight: 600; }
.trn__f small { display: block; color: var(--c-ink-500); font-size: var(--fs-13); margin-top: 3px; }
.trn__f--warn { border-left-color: var(--c-amber-500, #f59e0b); }
.trn__f--ok   { border-left-color: var(--c-leaf-600); }
.trn__visto   { margin: 0; padding-left: 13px; font-size: var(--fs-13); color: var(--c-ink-500); }
.trn__c-acc   { display: flex; gap: 9px; flex-wrap: wrap; padding-left: 13px; }
@media (max-width: 520px) {
  .trn__c-hd { grid-template-columns: minmax(0,1fr) auto; }
  .trn__c-arr { display: none; }
}
/* Ámbar y no rojo: una diferencia es un dato que se anota, no una falta que alguien explica. */
.trn__pill--warn { background: var(--c-amber-100, #fef3c7); color: var(--c-amber-700, #b45309); }
.trn__pill--info { background: var(--c-sky-100, #e0f2fe); color: var(--c-sky-600, #0284c7); }

/* El filtro de la lista de trabajo. Dos botones, no un desplegable: son dos estados. */
.trn__filtros { display: inline-flex; gap: 4px; }
.trn__filtro {
  border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-ink-700);
  border-radius: 999px; padding: 4px 12px; font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; display: inline-flex; align-items: center; gap: 6px;
}
.trn__filtro.is-on { background: var(--c-leaf-800, #14532d); color: #fff; border-color: transparent; }
.trn__filtro-n {
  background: var(--c-amber-100, #fef3c7); color: var(--c-amber-700, #b45309);
  border-radius: 999px; padding: 0 6px; font-size: var(--fs-12); font-weight: 700;
}
.trn__filtro.is-on .trn__filtro-n { background: rgba(255,255,255,.22); color: #fff; }

.trn__btn {
  border-radius: 9px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.trn__btn--mini  { padding: 6px 12px; font-size: var(--fs-13); }
.trn__btn--ghost { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
/* La acción principal, sólo cuando el cierre pide algo. En uno sin novedad corregir sigue
   accesible, pero en segundo plano: la fila no tiene que pedir atención. */
.trn__btn--primary { background: var(--c-leaf-800, #14532d); color: #fff; }
.trn__btn--primary:hover { filter: brightness(1.12); }
</style>
