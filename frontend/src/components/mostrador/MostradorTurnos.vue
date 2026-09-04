<template>
  <div class="trn">
    <div class="trn__hd">
      <p class="trn__sub">
        {{ gestiona
           ? 'Cada cierre con su conteo y su arqueo, del más nuevo al más viejo.'
           : 'Los turnos que atendiste vos. Si mañana te preguntan por una diferencia, está acá.' }}
      </p>
      <div class="trn__hd-acc">
        <span v-if="total" class="trn__total">{{ total }} cierre{{ total === 1 ? '' : 's' }}</span>
        <button v-if="total" class="trn__btn trn__btn--mini trn__btn--ghost"
                :disabled="bajando" @click="descargar">
          {{ bajando ? 'Preparando…' : 'Descargar CSV' }}
        </button>
      </div>
    </div>

    <p v-if="cargando" class="trn__vacio">Buscando…</p>
    <!-- Cada uno con su vacío: al admin decirle "no cerraste ningún turno" es contarle algo que
         no es suyo — él no atiende, mira los de los demás. -->
    <p v-else-if="!turnos.length" class="trn__vacio">
      {{ gestiona ? 'Todavía no cerró ningún turno en esta sede.'
                  : 'Todavía no cerraste ningún turno acá.' }}
    </p>

    <div v-else class="trn__table-wrap">
      <table class="trn__table tabla-cards">
        <thead>
          <tr>
            <th>Turno</th>
            <th class="trn__th-num">Entregado</th>
            <th class="trn__th-num">Faltó</th>
            <th class="trn__th-num">Caja</th>
            <th class="trn__th-acc"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in turnos" :key="t.id">
            <td data-col="Turno">
              <div class="trn__cuando">{{ fecha(t.cerrado_at) }} · {{ hora(t.abierto_at) }}–{{ hora(t.cerrado_at) }}</div>
              <div class="trn__meta">
                <span class="trn__mut">{{ t.atendio || t.cerrado_por }}</span>
                <span class="trn__mut">· {{ t.productos }} producto{{ t.productos === 1 ? '' : 's' }}</span>
                <span v-if="t.revisado" class="trn__pill trn__pill--ok">Visto</span>
              </div>
            </td>
            <td class="trn__td-num trn__mut" data-col="Entregado">{{ fmt(t.dispensado) }}</td>
            <td class="trn__td-num" data-col="Faltó">
              <template v-if="t.faltante > 0">
                <span class="trn__num">{{ fmt(t.faltante) }}</span>
                <span class="trn__unidad">${{ fmt(t.faltante_ars) }}</span>
              </template>
              <span v-else class="trn__ok">cuadró</span>
            </td>
            <td class="trn__td-num" data-col="Caja">
              <template v-if="t.efectivo_contado_ars !== null">
                <span class="trn__num">${{ fmt(t.efectivo_contado_ars) }}</span>
                <span v-if="t.diferencia_caja_ars" class="trn__unidad">
                  {{ t.diferencia_caja_ars > 0 ? '+' : '' }}${{ fmt(t.diferencia_caja_ars) }}
                </span>
              </template>
              <span v-else class="trn__mut">—</span>
            </td>
            <td class="trn__td-acc" data-col="">
              <!-- Corregir un conteo ajusta el inventario real: sólo administración. El que
                   atendió ve su turno para poder mostrarlo, no para reescribirlo. -->
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
import { listTurnosMostrador, descargarTurnosMostrador } from '../../lib/api.js'
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

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')
const hora  = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '')

async function cargar () {
  if (!props.sedeId) return
  cargando.value = true
  try {
    const { data } = await listTurnosMostrador(props.sedeId, { pagina: pagina.value })
    turnos.value   = data.turnos || []
    gestiona.value = !!data.gestiona
    paginas.value  = data.paginas || 1
    total.value    = data.total ?? turnos.value.length
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron cargar los turnos.')
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
.trn__num    { font-family: var(--font-mono); font-weight: 600; color: var(--c-ink-900); }
.trn__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }
.trn__ok     { font-size: var(--fs-13); color: var(--c-leaf-600); }

.trn__pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.trn__pill--ok { background: var(--c-leaf-100); color: var(--c-leaf-700); }

.trn__btn {
  border-radius: 9px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.trn__btn--mini  { padding: 6px 12px; font-size: var(--fs-13); }
.trn__btn--ghost { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
</style>
