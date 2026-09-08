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

    <div v-else class="trn__table-wrap">
      <table class="trn__table tabla-cards">
        <thead>
          <tr>
            <th>Cierre</th>
            <th class="trn__th-num">Entregado</th>
            <th class="trn__th-num">Faltó</th>
            <th class="trn__th-num">Caja</th>
            <th class="trn__th-acc"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in turnos" :key="t.id">
            <td data-col="Cierre">
              <div class="trn__cuando">{{ fecha(t.cerrado_at) }} · {{ hora(t.abierto_at) }}–{{ hora(t.cerrado_at) }}</div>
              <div class="trn__meta">
                <span class="trn__mut">{{ t.atendio || t.cerrado_por }}</span>
                <span class="trn__mut">· {{ t.productos }} producto{{ t.productos === 1 ? '' : 's' }}</span>
                <span v-if="t.revisado" class="trn__pill trn__pill--ok">Visto</span>
              </div>
              <!-- POR QUÉ HAY QUE MIRARLO. Sin esto hay que abrir el cierre para descubrir que no
                   era nada. Uno solo, el que manda: tres chips juntos obligan a leer los tres
                   para saber cuál importa, y el resto se ve entrando al cierre. -->
              <div v-if="motivoPrincipal(t)" class="trn__meta">
                <span class="trn__pill" :class="`trn__pill--${TONO[motivoPrincipal(t)] || 'info'}`">
                  {{ MOTIVO[motivoPrincipal(t)] }}
                </span>
                <span v-if="(t.motivos_revision || []).length > 1" class="trn__mut">
                  +{{ t.motivos_revision.length - 1 }} más
                </span>
              </div>
            </td>
            <!-- EN PLATA, no en cantidad. Sumar gramos de flor con unidades de preroll da un
                 número que no significa nada: "faltó 23" era 23 g más 4 prerolls, y no se podía
                 ni saber de qué hablaba ni comparar un turno con otro. Los pesos sí se suman. -->
            <td class="trn__td-num" data-col="Entregado">
              <span v-if="t.dispensado_ars > 0" class="trn__num">${{ fmt(t.dispensado_ars) }}</span>
              <span v-else class="trn__nada">—</span>
            </td>
            <td class="trn__td-num" data-col="Faltó">
              <template v-if="t.faltante > 0">
                <span class="trn__num">${{ fmt(t.faltante_ars) }}</span>
                <span class="trn__pie">
                  en {{ t.productos_con_faltante }} producto{{ t.productos_con_faltante === 1 ? '' : 's' }}
                </span>
              </template>
              <span v-else class="trn__ok">cuadró</span>
            </td>
            <td class="trn__td-num" data-col="Caja">
              <template v-if="t.efectivo_contado_ars !== null">
                <span class="trn__num">${{ fmt(t.efectivo_contado_ars) }}</span>
                <!-- Qué ES el segundo número. Suelto al lado del contado se leía como el costo de
                     algo: son dos cifras pegadas sin decir cuál es cuál. -->
                <span v-if="t.diferencia_caja_ars" class="trn__pie">
                  {{ t.diferencia_caja_ars > 0 ? 'sobró' : 'faltó' }}
                  ${{ fmt(Math.abs(t.diferencia_caja_ars)) }}
                </span>
              </template>
              <span v-else class="trn__mut">—</span>
            </td>
            <td class="trn__td-acc" data-col="">
              <!-- Corregir un conteo ajusta el inventario real: sólo administración. El que
                   atendió ve su turno para poder mostrarlo, no para reescribirlo. -->
              <button v-if="gestiona && !t.revisado && motivoPrincipal(t)"
                      class="trn__btn trn__btn--mini" @click="marcarVisto(t)">Ya lo miré</button>
              <button v-if="gestiona" class="trn__btn trn__btn--mini trn__btn--ghost"
                      @click="corrigiendo = t">Corregir conteo</button>
            </td>
          </tr>
        </tbody>
      </table>
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
  faltante:    'Faltó producto',
  sobrante:    'Contó más de lo que había',
  corregido:   'Se corrigió al abrir',
  mesa_movida: 'Se movió la mesa con la caja abierta',
}
const TONO = { faltante: 'warn', sobrante: 'warn', corregido: 'info', mesa_movida: 'info' }
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
</style>
