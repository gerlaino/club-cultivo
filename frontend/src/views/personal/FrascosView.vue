<template>
  <div class="fr">
    <header class="fr__header">
      <div>
        <h1 class="fr__title">Frascos</h1>
        <p class="fr__sub">Lo que cosechaste, cuánto queda y lo que fuiste sacando.</p>
      </div>
      <div v-if="Object.keys(f.totalPorUnidad.value).length" class="fr__totales">
        <span v-for="(cant, u) in f.totalPorUnidad.value" :key="u" class="fr__total">
          <b>{{ fmt(cant) }}</b> {{ u }}
        </span>
      </div>
    </header>

    <div v-if="f.cargando.value" class="fr__loading"><DsSpinner :size="18" /> Cargando…</div>
    <template v-else>
      <!-- Lo que está entre la cosecha y el frasco. Pesar es lo que crea el stock. -->
      <section v-if="f.porPesar.value.length" class="fr__section">
        <h2 class="fr__section-title">Por pesar</h2>
        <div class="fr__pesar">
          <RouterLink v-for="l in f.porPesar.value" :key="l.id" :to="`/lotes/${l.id}`" class="fr__pesar-card">
            <span class="fr__pesar-nombre">{{ l.genetica?.nombre || l.strain || l.codigo }}</span>
            <span class="fr__pesar-sub">{{ l.codigo }} · {{ ESTADO_META[l.estado]?.label || l.estado }}<template v-if="l.dias_en_estado != null"> · día {{ l.dias_en_estado + 1 }}</template></span>
            <span class="fr__pesar-cta">{{ l.estado === 'en_manicura' ? 'Pesar y enfrascar →' : 'Ver lote →' }}</span>
          </RouterLink>
        </div>
      </section>

      <section class="fr__section">
        <h2 class="fr__section-title">En el frasco</h2>
        <DsEmpty v-if="!f.frascos.value.length" title="Todavía no hay nada enfrascado"
                 description="Cuando coseches y peses un lote, aparece acá con sus gramos." />
        <table v-else class="fr__table">
          <thead>
            <tr><th>Frasco</th><th>Genética</th><th>Lote</th><th>Qué es</th><th>Enfrascado</th><th class="fr__num">Al inicio</th><th class="fr__num">Queda</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="s in f.frascos.value" :key="s.id">
              <td class="fr__mono">{{ s.numero_lote_producto || `#${s.id}` }}</td>
              <td class="fr__strong">{{ s.genetica_nombre || s.lote?.genetica?.nombre || '—' }}</td>
              <td class="fr__mono">{{ s.lote_codigo || '—' }}</td>
              <td>{{ formaLabel(s.forma_producto) }}</td>
              <td>{{ fecha(s.fecha_elaboracion) }}</td>
              <td class="fr__num">{{ s.cantidad_inicial != null ? `${fmt(s.cantidad_inicial)} ${s.unidad || 'g'}` : '—' }}</td>
              <td class="fr__num fr__queda">{{ fmt(s.cantidad) }} {{ s.unidad || 'g' }}</td>
              <td class="fr__acciones">
                <button type="button" class="fr__btn-sec" @click="verHistorial(s)">Historial</button>
                <button type="button" class="fr__btn" @click="abrirConsumo(s)">Consumí</button>
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section v-if="f.agotados.value.length" class="fr__section">
        <h2 class="fr__section-title">Terminados</h2>
        <table class="fr__table fr__table--off">
          <thead><tr><th>Frasco</th><th>Genética</th><th>Lote</th><th>Qué es</th><th class="fr__num">Tuvo</th><th></th></tr></thead>
          <tbody>
            <tr v-for="s in f.agotados.value" :key="s.id">
              <td class="fr__mono">{{ s.numero_lote_producto || `#${s.id}` }}</td>
              <td>{{ s.genetica_nombre || s.lote?.genetica?.nombre || '—' }}</td>
              <td class="fr__mono">{{ s.lote_codigo || '—' }}</td>
              <td>{{ formaLabel(s.forma_producto) }}</td>
              <td class="fr__num">{{ s.cantidad_inicial != null ? `${fmt(s.cantidad_inicial)} ${s.unidad || 'g'}` : '—' }}</td>
              <td class="fr__acciones"><button type="button" class="fr__btn-sec" @click="verHistorial(s)">Historial</button></td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>

    <Teleport to="body">
      <!-- Consumo -->
      <div v-if="modalConsumo" v-modal="() => modalConsumo = false" class="fr__overlay">
        <div class="fr__modal" role="dialog" aria-modal="true">
          <div class="fr__modal-head">
            <h2 class="fr__modal-title">Consumí de {{ f.consumo.stock?.genetica_nombre || f.consumo.stock?.numero_lote_producto || 'este frasco' }}</h2>
            <button type="button" class="fr__icon" aria-label="Cerrar" @click="modalConsumo = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <ConsumoForm v-if="f.consumo.stock" :consumo="f.consumo" :hoy="f.hoy" @guardar="confirmarConsumo" @cancelar="modalConsumo = false" />
        </div>
      </div>

      <!-- Historial de un frasco -->
      <div v-if="modalHist" v-modal="() => modalHist = false" class="fr__overlay">
        <div class="fr__modal" role="dialog" aria-modal="true">
          <div class="fr__modal-head">
            <h2 class="fr__modal-title">{{ hist.stock?.genetica_nombre || hist.stock?.numero_lote_producto }} · lo que pasó</h2>
            <button type="button" class="fr__icon" aria-label="Cerrar" @click="modalHist = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div v-if="hist.cargando" class="fr__loading"><DsSpinner :size="16" /> Cargando…</div>
          <ul v-else-if="hist.items.length" class="fr__hist">
            <li v-for="m in hist.items" :key="m.id" class="fr__hist-item">
              <span class="fr__hist-fecha">{{ fecha(m.fecha || m.created_at) }}</span>
              <span class="fr__hist-txt">{{ verbo(m) }}<span v-if="m.notas && m.tipo === 'consumo' && m.notas !== 'Consumo propio'" class="fr__hist-nota"> — {{ m.notas }}</span></span>
              <span class="fr__hist-g" :class="{ 'fr__hist-g--in': m.gramos > 0 }">{{ m.gramos > 0 ? '+' : '' }}{{ fmt(m.gramos) }} {{ hist.stock?.unidad || 'g' }}</span>
            </li>
          </ul>
          <p v-else class="fr__hist-vacio">Todavía no salió nada de este frasco.</p>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
// Los frascos del cultivador de casa, en el escritorio. Reemplaza a Stock —sedes, mostrador,
// «por asignar», stock externo— por la única pregunta que él tiene: qué cosechó, cuánto queda y
// qué fue sacando. Mismo estado que la solapa del teléfono (`useFrascosPersonal`).
import { ref, reactive, onMounted } from 'vue'
import { useFrascosPersonal, formaLabel, fmt } from '../../composables/useFrascosPersonal.js'
import { useToast } from '../../composables/useToast.js'
import { ESTADO_META } from '../../lib/loteHelpers.js'
import ConsumoForm from '../../components/personal/ConsumoForm.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import DsEmpty from '../../design-system/components/EmptyState.vue'

const f     = useFrascosPersonal()
const toast = useToast()
const modalConsumo = ref(false)
const modalHist    = ref(false)

function abrirConsumo(s) { f.prepararConsumo(s); modalConsumo.value = true }
async function confirmarConsumo() {
  const data = await f.confirmarConsumo()
  if (data) {
    modalConsumo.value = false
    toast.success(`Anotado: ${fmt(f.consumo.cantidad)} ${data.unidad || 'g'}`)
  }
}

const hist = reactive({ stock: null, items: [], cargando: false })
async function verHistorial(s) {
  Object.assign(hist, { stock: s, items: [], cargando: true })
  modalHist.value = true
  try { hist.items = await f.movimientosDe(s) } catch { hist.items = [] } finally { hist.cargando = false }
}

const VERBOS = {
  produccion: 'Entró del pesaje', consumo: 'Consumiste', merma: 'Se perdió', salida: 'Salió',
  ajuste: 'Se corrigió el conteo', transferencia: 'Cambió de lugar', dispensacion: 'Se entregó', consumo_evento: 'Se consumió en un evento',
}
function verbo(m) { return VERBOS[m.tipo] || m.tipo }
function fecha(d) { return d ? new Date(String(d).length === 10 ? d + 'T00:00:00' : d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' }) : '—' }

onMounted(() => f.cargar())
</script>

<style scoped>
.fr { max-width: 1100px; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
.fr__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.25rem; }
.fr__title { margin: 0; font-size: 1.6rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.02em; }
.fr__sub { margin: .25rem 0 0; font-size: .88rem; color: var(--c-slate-500); }
.fr__totales { display: flex; gap: .5rem; }
.fr__total { padding: .55rem .9rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 12px; font-size: .9rem; color: var(--c-slate-600); }
.fr__total b { font-family: var(--font-display, sans-serif); font-size: 1.2rem; color: var(--c-slate-900); }
.fr__loading { display: flex; align-items: center; gap: .5rem; padding: 2rem; color: var(--c-slate-400); font-size: .875rem; }
.fr__section { margin-bottom: 1.5rem; }
.fr__section-title { margin: 0 0 .6rem; font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-slate-500); }

.fr__pesar { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .6rem; }
.fr__pesar-card { display: flex; flex-direction: column; gap: .15rem; padding: .85rem 1rem; background: #fffdf5; border: 1px solid #fde68a; border-radius: 12px; text-decoration: none; }
.fr__pesar-nombre { font-weight: 700; color: var(--c-slate-900); }
.fr__pesar-sub { font-size: .78rem; color: var(--c-slate-500); }
.fr__pesar-cta { margin-top: .3rem; font-size: .8rem; font-weight: 700; color: #92400e; }

.fr__table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
.fr__table th { text-align: left; font-size: .72rem; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--c-slate-500); padding: .7rem .9rem; background: var(--c-slate-50, #f8fafc); border-bottom: 1px solid var(--c-slate-200); }
.fr__table td { padding: .7rem .9rem; font-size: .88rem; color: var(--c-slate-700); border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.fr__table tr:last-child td { border-bottom: none; }
.fr__table--off { opacity: .7; }
.fr__num { text-align: right; }
.fr__queda { font-weight: 800; color: var(--c-slate-900); font-size: 1rem; }
.fr__mono { font-family: ui-monospace, monospace; font-size: .82rem; color: var(--c-slate-500); }
.fr__strong { font-weight: 700; color: var(--c-slate-900); }
.fr__acciones { text-align: right; white-space: nowrap; display: flex; gap: .4rem; justify-content: flex-end; }
.fr__btn { padding: .45rem .8rem; border-radius: 9px; border: none; background: var(--c-leaf-800, #1A3D2E); color: #fff; font-size: .8rem; font-weight: 700; cursor: pointer; }
.fr__btn-sec { padding: .45rem .8rem; border-radius: 9px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); font-size: .8rem; font-weight: 600; cursor: pointer; }
.fr__icon { width: 32px; height: 32px; border-radius: 8px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-600); cursor: pointer; }

.fr__overlay { position: fixed; inset: 0; background: rgba(15, 23, 42, .45); display: flex; align-items: center; justify-content: center; padding: 1rem; z-index: 1000; }
.fr__modal { width: 100%; max-width: 480px; background: #fff; border-radius: 16px; padding: 1.25rem 1.25rem 1rem; box-shadow: 0 20px 60px rgba(0,0,0,.25); max-height: 92vh; overflow: auto; }
.fr__modal-head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; margin-bottom: 1rem; }
.fr__modal-title { margin: 0; font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); }
.fr__hist { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.fr__hist-item { display: grid; grid-template-columns: 7.5rem 1fr auto; gap: .6rem; align-items: baseline; padding: .55rem 0; border-bottom: 1px solid var(--c-slate-100); font-size: .88rem; }
.fr__hist-item:last-child { border-bottom: none; }
.fr__hist-fecha { font-family: ui-monospace, monospace; font-size: .78rem; color: var(--c-slate-500); }
.fr__hist-txt { color: var(--c-slate-800); }
.fr__hist-nota { color: var(--c-slate-500); }
.fr__hist-g { font-weight: 700; color: #b91c1c; white-space: nowrap; }
.fr__hist-g--in { color: #15803d; }
.fr__hist-vacio { margin: 0; font-size: .88rem; color: var(--c-slate-500); }
</style>
