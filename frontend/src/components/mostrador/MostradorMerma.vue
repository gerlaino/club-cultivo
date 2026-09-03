<template>
  <div class="mrm">
    <div class="mrm__filtros">
      <label class="mrm__campo-inline">Desde
        <input v-model="rango.desde" type="date" class="mrm__input mrm__input--fecha" />
      </label>
      <label class="mrm__campo-inline">Hasta
        <input v-model="rango.hasta" type="date" class="mrm__input mrm__input--fecha" />
      </label>
      <!-- Comparar sedes es LA pregunta que encuentra el cuello de botella: si en una se pierde
           el triple que en otra con el mismo producto, el problema no es la merma. -->
      <label v-if="variasSedes" class="mrm__campo-inline">
        <input v-model="todasLasSedes" type="checkbox" /> Todas las sedes
      </label>
      <button class="mrm__btn mrm__btn--ghost" @click="cargar">Ver</button>
    </div>

    <p v-if="cargando" class="mrm__vacio">Calculando…</p>
    <p v-else-if="!merma || !merma.resumen.turnos" class="mrm__vacio">
      Todavía no hay turnos cerrados en este período.
    </p>

    <template v-else>
      <!-- ══ LO QUE HAY QUE MIRAR ═══════════════════════════════════════════════
           Va primero y separado del análisis: son dos cosas distintas. Esto se termina
           —se mira, se marca y desaparece—; lo de abajo se consulta. Mezclados, la lista
           de trabajo quedaba enterrada entre tres tablas de estudio y no se hacía nunca. -->
      <template v-if="pendientes.length">
        <h2 class="mrm__seccion">Para mirar</h2>
        <p class="mrm__seccion-sub">
          Turnos que pasó algo que conviene mirar. No es una lista de sospechosos: se mira, se
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

      <!-- ══ EL ANÁLISIS ════════════════════════════════════════════════════════ -->
      <h2 class="mrm__seccion">Cómo viene</h2>
      <div class="mrm__kpis">
        <div class="mrm__kpi">
          <span class="mrm__kpi-num">{{ merma.resumen.merma_pct ?? '—' }}<small>%</small></span>
          <span class="mrm__kpi-lbl">de lo entregado</span>
        </div>
        <div class="mrm__kpi">
          <span class="mrm__kpi-num">${{ fmt(merma.resumen.faltante_ars) }}</span>
          <span class="mrm__kpi-lbl">a costo, en el período</span>
        </div>
        <div class="mrm__kpi">
          <span class="mrm__kpi-num">{{ merma.resumen.turnos }}</span>
          <span class="mrm__kpi-lbl">turnos cerrados</span>
        </div>
      </div>

      <template v-if="merma.por_sede?.length">
        <h2 class="mrm__seccion">Sede por sede</h2>
        <p class="mrm__seccion-sub">
          Si en una se pierde el triple que en otra con el mismo producto, el problema no es la
          merma: es algo de esa sede, y hasta que no se ponen al lado no se ve.
        </p>
        <div class="mrm__table-wrap">
          <table class="mrm__table tabla-cards">
            <thead>
              <tr>
                <th>Sede</th>
                <th class="mrm__th-num">Turnos</th>
                <th class="mrm__th-num">Entregado</th>
                <th class="mrm__th-num">Faltó</th>
                <th class="mrm__th-num">%</th>
                <th class="mrm__th-num">A costo</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in merma.por_sede" :key="s.sede_id">
                <td data-col="Sede"><div class="mrm__prod">{{ s.sede }}</div></td>
                <td class="mrm__td-num mrm__td-mut" data-col="Turnos">{{ s.turnos }}</td>
                <td class="mrm__td-num mrm__td-mut" data-col="Entregado">{{ fmt(s.dispensado) }}</td>
                <td class="mrm__td-num mrm__td-mut" data-col="Faltó">{{ fmt(s.faltante) }}</td>
                <td class="mrm__td-num" data-col="%"><span class="mrm__pct">{{ s.merma_pct ?? '—' }}%</span></td>
                <td class="mrm__td-num mrm__td-mut" data-col="A costo">${{ fmt(s.faltante_ars) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>

      <h2 class="mrm__seccion">Por producto</h2>
      <p class="mrm__seccion-sub">
        Ordenado por porcentaje, no por cantidad: lo que más se vende siempre encabeza un ranking
        de gramos y eso no dice nada.
      </p>
      <div class="mrm__table-wrap">
        <table class="mrm__table tabla-cards">
          <thead>
            <tr>
              <th>Producto</th>
              <th class="mrm__th-num">Entregado</th>
              <th class="mrm__th-num">Faltó</th>
              <th class="mrm__th-num">%</th>
              <th class="mrm__th-num">A costo</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in merma.por_producto" :key="p.producto">
              <td data-col="Producto"><div class="mrm__prod">{{ p.producto }}</div></td>
              <td class="mrm__td-num mrm__td-mut" data-col="Entregado">{{ fmt(p.dispensado) }} {{ p.unidad }}</td>
              <td class="mrm__td-num mrm__td-mut" data-col="Faltó">{{ fmt(p.faltante) }} {{ p.unidad }}</td>
              <td class="mrm__td-num" data-col="%"><span class="mrm__pct">{{ p.merma_pct ?? '—' }}%</span></td>
              <td class="mrm__td-num mrm__td-mut" data-col="A costo">${{ fmt(p.faltante_ars) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2 class="mrm__seccion">Turno por turno</h2>
      <div class="mrm__table-wrap">
        <table class="mrm__table tabla-cards">
          <thead>
            <tr>
              <th>Cerró</th>
              <th class="mrm__th-num">Entregado</th>
              <th class="mrm__th-num">Faltó</th>
              <th>Motivo</th>
              <th class="mrm__th-acc"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in merma.por_turno" :key="t.id">
              <td data-col="Cerró">
                <div class="mrm__prod">{{ fecha(t.cerrado_at) }}</div>
                <div class="mrm__prod-meta">
                  <span class="mrm__td-mut">{{ t.cerrado_por }}</span>
                  <!-- El plural de "corrección" PIERDE el acento: pegarle "es" da
                       "correcciónes". Misma trampa que organización → organizaciones. -->
                  <span v-if="t.correcciones" class="mrm__pill mrm__pill--info">
                    {{ t.correcciones }} {{ t.correcciones > 1 ? 'correcciones' : 'corrección' }} al abrir
                  </span>
                </div>
              </td>
              <td class="mrm__td-num mrm__td-mut" data-col="Entregado">{{ fmt(t.dispensado) }}</td>
              <td class="mrm__td-num" data-col="Faltó">
                <span class="mrm__pct">{{ fmt(t.faltante) }}</span>
                <span class="mrm__unidad">${{ fmt(t.faltante_ars) }}</span>
              </td>
              <td class="mrm__td-mut" data-col="Motivo">{{ t.motivos.join(' · ') || '—' }}</td>
              <td class="mrm__td-acc" data-col="">
                <span v-if="t.revisado" class="mrm__pill mrm__pill--ok">Visto</span>
                <button v-else class="mrm__btn mrm__btn--mini" @click="revisar(t)">Ya lo miré</button>
                <button class="mrm__btn mrm__btn--mini mrm__btn--ghost mrm__btn--corregir"
                        @click="corrigiendo = t">Corregir conteo</button>
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
// La pantalla hace DOS cosas y por eso están separadas: arriba la lista de trabajo (turnos que
// piden una mirada, que se terminan) y abajo el análisis (que se consulta). Mezcladas, la lista
// de trabajo quedaba enterrada entre tres tablas y no se hacía nunca.
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
// El rango arranca VACÍO y lo completa el backend con el mes en curso en SU zona horaria.
//
// Antes lo calculaba acá con `toISOString()`, que da la fecha en UTC: con el navegador en una
// zona y Rails en Buenos Aires, entre las 21:00 y las 00:00 el rango pedía un mañana donde
// todavía no había cerrado nadie, y la solapa se veía vacía justo en el horario en que se cierra
// el mostrador. El cliente no tiene por qué adivinar qué día es en el servidor.
const rango = ref({ desde: '', hasta: '' })

// Las tres razones por las que un turno entra a la lista, con el nombre que usa la gente. Un
// renglón que no dice qué mirar obliga a abrirlo para descubrir que no era nada — y una razón sin
// etiqueta acá se dibuja como un chip vacío, que es peor todavía.
const MOTIVO = { faltante: 'Faltó producto', corregido: 'Se corrigió al abrir',
                 mesa_movida: 'Se movió la mesa durante el turno' }
const PILL   = { faltante: 'warn', corregido: 'info', mesa_movida: 'info' }

// Lo que todavía no miró nadie Y tiene algo para mirar.
const pendientes = computed(() =>
  (merma.value?.por_turno || []).filter(t => !t.revisado && t.motivos_revision?.length)
)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

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
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo calcular la merma.')
  } finally {
    cargando.value = false
  }
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

@media (max-width: 640px) {
  .mrm__pendiente { flex-direction: column; align-items: stretch; }
}
</style>
