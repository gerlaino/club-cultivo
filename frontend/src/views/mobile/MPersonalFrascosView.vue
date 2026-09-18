<template>
  <div class="mpf">
    <header class="mpf__header">
      <h1 class="mpf__title">Frascos</h1>
      <p class="mpf__sub">Lo que cosechaste y cuánto queda.</p>
    </header>

    <div v-if="cargando" class="mpf__loading"><i class="bi bi-arrow-repeat mpf__spin"></i> Cargando…</div>

    <template v-else>
      <!-- Lo que está entre la cosecha y el frasco. Pesar es lo que crea el stock. -->
      <section v-if="porPesar.length" class="mpf__section">
        <h2 class="mpf__section-title">Por pesar</h2>
        <div class="mpf__list">
          <RouterLink v-for="l in porPesar" :key="l.id"
                      :to="l.estado === 'en_manicura' ? `/m/mnc/lotes/${l.id}` : `/m/lote-m/${l.id}`" class="mpf__card mpf__card--pesar">
            <span class="mpf__card-ico"><i class="bi" :class="icono(l.estado)"></i></span>
            <span class="mpf__card-txt">
              <span class="mpf__card-nombre">{{ l.genetica?.nombre || l.strain || l.codigo }}</span>
              <span class="mpf__card-sub">{{ l.codigo }} · {{ meta(l.estado).label }}<template v-if="l.dias_en_estado != null"> · día {{ l.dias_en_estado + 1 }}</template></span>
            </span>
            <span class="mpf__card-cta">{{ l.estado === 'en_manicura' ? 'Pesar' : 'Ver' }} <i class="bi bi-chevron-right"></i></span>
          </RouterLink>
        </div>
      </section>

      <section class="mpf__section">
        <h2 class="mpf__section-title">En el frasco</h2>
        <div v-if="!frascos.length" class="mpf__empty">
          <i class="bi bi-archive"></i>
          <p class="mpf__empty-title">Todavía no hay nada enfrascado</p>
          <p class="mpf__empty-hint">Cuando coseches y peses un lote, aparece acá con sus gramos.</p>
        </div>
        <div v-else class="mpf__list">
          <div v-for="s in frascos" :key="s.id" class="mpf__card">
            <span class="mpf__card-ico"><i class="bi bi-archive"></i></span>
            <span class="mpf__card-txt">
              <span class="mpf__card-nombre">{{ s.genetica_nombre || s.lote?.genetica?.nombre || s.nombre_producto || s.numero_lote_producto }}</span>
              <span class="mpf__card-sub">{{ s.numero_lote_producto || `#${s.id}` }}<template v-if="s.lote_codigo"> · {{ s.lote_codigo }}</template><template v-if="s.forma_producto"> · {{ formaLabel(s.forma_producto) }}</template></span>
            </span>
            <span class="mpf__card-cant">
              <span class="mpf__cant-num">{{ fmt(s.cantidad) }}</span>
              <span class="mpf__cant-u">{{ s.unidad || 'g' }}</span>
            </span>
            <button type="button" class="mpf__consumir" @click="abrirConsumo(s)">Consumí</button>
          </div>
        </div>
      </section>

      <section v-if="agotados.length" class="mpf__section">
        <h2 class="mpf__section-title">Terminados</h2>
        <div class="mpf__list">
          <div v-for="s in agotados" :key="s.id" class="mpf__card mpf__card--off">
            <span class="mpf__card-ico"><i class="bi bi-archive"></i></span>
            <span class="mpf__card-txt">
              <span class="mpf__card-nombre">{{ s.genetica_nombre || s.lote?.genetica?.nombre || s.numero_lote_producto }}</span>
              <span class="mpf__card-sub">{{ s.numero_lote_producto || `#${s.id}` }} · empezó con {{ fmt(s.cantidad_inicial) }} {{ s.unidad || 'g' }}</span>
            </span>
          </div>
        </div>
      </section>
    </template>

    <!-- Consumo propio: cuánto sacaste del frasco. -->
    <MobileSheet v-model="sheet" :title="consumo.stock ? `Consumí de ${consumo.stock.genetica_nombre || consumo.stock.numero_lote_producto || 'este frasco'}` : ''">
      <form v-if="consumo.stock" class="mpf__form" @submit.prevent="confirmarConsumo">
        <p class="mpf__form-hint">Quedan <b>{{ fmt(consumo.stock.cantidad) }} {{ consumo.stock.unidad || 'g' }}</b>.</p>
        <label class="mpf__field">
          <span class="mpf__label">Cuánto</span>
          <span class="mpf__input-row">
            <input v-model.number="consumo.cantidad" type="number" inputmode="decimal" step="0.1" min="0.1"
                   :max="consumo.stock.cantidad" class="mpf__input mpf__input--num" placeholder="0" autofocus />
            <span class="mpf__input-u">{{ consumo.stock.unidad || 'g' }}</span>
          </span>
        </label>
        <label class="mpf__field">
          <span class="mpf__label">Cuándo</span>
          <input v-model="consumo.fecha" type="date" class="mpf__input" :max="hoy" />
        </label>
        <label class="mpf__field">
          <span class="mpf__label">Nota <span class="mpf__opt">(opcional)</span></span>
          <input v-model.trim="consumo.nota" type="text" class="mpf__input" placeholder="Para dormir, con amigos…" maxlength="120" />
        </label>
        <p v-if="consumo.error" class="mpf__error">{{ consumo.error }}</p>
        <p class="mpf__resumen" v-if="consumo.cantidad > 0">
          Salen {{ fmt(consumo.cantidad) }} {{ consumo.stock.unidad || 'g' }}; quedan {{ fmt(Math.max(0, consumo.stock.cantidad - consumo.cantidad)) }}.
        </p>
        <div class="mpf__form-actions">
          <button type="button" class="mpf__btn mpf__btn--ghost" @click="sheet = false">Cancelar</button>
          <button type="submit" class="mpf__btn mpf__btn--primary" :disabled="!(consumo.cantidad > 0) || consumo.guardando">
            {{ consumo.guardando ? 'Guardando…' : 'Anotar' }}
          </button>
        </div>
      </form>
    </MobileSheet>
  </div>
</template>

<script setup>
// Los frascos del cultivador de casa: lo cosechado, cuánto queda y lo que sacó para él.
// El stock es el mismo `Stock` de una organización; lo distinto es la salida —consumo propio,
// que en una organización no existe porque lo trazable sale sólo por dispensación.
import { ref, computed, reactive, onMounted } from 'vue'
// `historial`: la lista completa. El listado por defecto trae sólo lo asignado a una sede, y un
// frasco recién pesado puede estar todavía sin sede: acá tiene que verse igual.
import { listStocksHistorial, listLotes, consumirStock } from '../../lib/api'
import { useToast } from '../../composables/useToast.js'
import { hoyISO } from '../../utils/dates.js'
import { ESTADO_META } from '../../lib/loteHelpers.js'
import MobileSheet from '../../components/mobile/MobileSheet.vue'

const toast    = useToast()
const cargando = ref(true)
const stocks   = ref([])
const lotes    = ref([])
const hoy      = hoyISO()

const frascos  = computed(() => stocks.value.filter(s => Number(s.cantidad) > 0 && s.estado !== 'agotado'))
const agotados = computed(() => stocks.value.filter(s => !(Number(s.cantidad) > 0) || s.estado === 'agotado').slice(0, 10))
const porPesar = computed(() => lotes.value.filter(l => ['cosecha', 'en_manicura'].includes(l.estado)))

function meta(estado) { return ESTADO_META[estado] || { label: estado } }
// Íconos por estado del lote (Bootstrap Icons, no emoji: el emoji depende de la fuente del
// teléfono y en algunos aparece como un cuadrado).
const ICONO_ESTADO = {
  enraizado: 'bi-droplet', vegetativo: 'bi-flower3', floracion: 'bi-flower1', cosecha: 'bi-scissors',
  en_manicura: 'bi-scissors', curado: 'bi-archive', finalizado: 'bi-check2-circle',
}
function icono(estado) { return ICONO_ESTADO[estado] || 'bi-box-seam' }

function fmt(n) { const v = Number(n || 0); return Number.isInteger(v) ? String(v) : v.toFixed(1) }
const FORMAS = { flor: 'Flor', flor_seca: 'Flor seca', preroll: 'Prerolls', aceite: 'Aceite', hash: 'Hash', prensado: 'Prensado', comestible: 'Comestible', capsula: 'Cápsulas' }
function formaLabel(f) { return FORMAS[f] || f }

// ── Consumo ──
const sheet   = ref(false)
const consumo = reactive({ stock: null, cantidad: null, fecha: hoy, nota: '', error: null, guardando: false })

function abrirConsumo(s) {
  Object.assign(consumo, { stock: s, cantidad: null, fecha: hoy, nota: '', error: null, guardando: false })
  sheet.value = true
}

async function confirmarConsumo() {
  if (!(consumo.cantidad > 0)) return
  consumo.guardando = true
  consumo.error = null
  try {
    const { data } = await consumirStock(consumo.stock.id, { cantidad: consumo.cantidad, fecha: consumo.fecha, nota: consumo.nota })
    const i = stocks.value.findIndex(s => s.id === data.id)
    if (i >= 0) stocks.value[i] = data
    sheet.value = false
    toast.success(`Anotado: ${fmt(consumo.cantidad)} ${data.unidad || 'g'}`)
  } catch (e) {
    consumo.error = e?.response?.data?.error || 'No se pudo anotar'
  } finally { consumo.guardando = false }
}

onMounted(async () => {
  try {
    const [st, lt] = await Promise.allSettled([listStocksHistorial(), listLotes()])
    if (st.status === 'fulfilled') stocks.value = st.value.data || []
    if (lt.status === 'fulfilled') lotes.value  = lt.value.data || []
  } finally { cargando.value = false }
})
</script>

<style scoped>
.mpf { padding: 0 0 1.5rem; }
.mpf__header { padding: 1rem 1rem .5rem; }
.mpf__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mpf__sub { margin: .15rem 0 0; font-size: .8rem; color: var(--c-slate-500); }
.mpf__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mpf__spin { animation: mpf-spin .8s linear infinite; }
@keyframes mpf-spin { to { transform: rotate(360deg); } }

.mpf__section { padding: .9rem 1rem 0; }
.mpf__section-title { margin: 0 0 .55rem; font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-ink-500, #6b7280); }
.mpf__list { display: flex; flex-direction: column; gap: .45rem; }
.mpf__card {
  display: flex; align-items: center; gap: .7rem; padding: .7rem .8rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; text-decoration: none; color: inherit;
}
.mpf__card--pesar { border-color: #fde68a; background: #fffdf5; }
.mpf__card--off { opacity: .6; }
.mpf__card-ico { width: 38px; height: 38px; border-radius: 11px; display: grid; place-items: center; font-size: 1.1rem; flex-shrink: 0; background: var(--c-leaf-50, #F4F8F5); color: var(--c-leaf-700, #2D7D46); }
.mpf__card-txt { display: flex; flex-direction: column; gap: .1rem; min-width: 0; flex: 1; }
.mpf__card-nombre { font-size: .9rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpf__card-sub { font-size: .74rem; color: var(--c-ink-500, #6b7280); }
.mpf__card-cta { font-size: .8rem; font-weight: 700; color: #92400e; white-space: nowrap; }
.mpf__card-cant { display: flex; align-items: baseline; gap: .15rem; flex-shrink: 0; }
.mpf__cant-num { font-family: var(--font-display, sans-serif); font-size: 1.25rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); }
.mpf__cant-u { font-size: .74rem; color: var(--c-ink-500, #6b7280); }
.mpf__consumir {
  flex-shrink: 0; padding: .45rem .7rem; border-radius: 10px; border: none;
  background: var(--c-leaf-800, #1A3D2E); color: #fff; font-size: .78rem; font-weight: 700;
}
.mpf__consumir:active { transform: scale(.96); }

.mpf__empty { display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: 2.2rem 1rem; text-align: center; color: var(--c-slate-500); background: #fff; border: 1px dashed var(--c-leaf-200, #cfe0d6); border-radius: 14px; }
.mpf__empty i { font-size: 2rem; color: var(--c-leaf-500, #5A8A72); }
.mpf__empty-title { margin: .3rem 0 0; font-size: .92rem; font-weight: 700; color: var(--c-slate-900); }
.mpf__empty-hint { margin: 0; font-size: .8rem; }

/* Sheet */
.mpf__form { display: flex; flex-direction: column; gap: .8rem; padding-bottom: .5rem; }
.mpf__form-hint { margin: 0; font-size: .85rem; color: var(--c-slate-600); }
.mpf__field { display: flex; flex-direction: column; gap: .3rem; }
.mpf__label { font-size: .76rem; font-weight: 700; color: var(--c-slate-600); text-transform: uppercase; letter-spacing: .04em; }
.mpf__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.mpf__input { width: 100%; padding: .7rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; font: inherit; font-size: 1rem; background: #fff; }
.mpf__input:focus { outline: none; border-color: var(--c-leaf-500, #5A8A72); }
.mpf__input-row { display: flex; align-items: center; gap: .5rem; }
.mpf__input--num { font-size: 1.6rem; font-weight: 700; text-align: right; }
.mpf__input-u { font-size: 1rem; font-weight: 600; color: var(--c-slate-500); }
.mpf__error { margin: 0; font-size: .82rem; color: #b91c1c; }
.mpf__resumen { margin: 0; font-size: .85rem; color: var(--c-slate-700); }
.mpf__form-actions { display: flex; gap: .5rem; }
.mpf__btn { flex: 1; padding: .8rem; border-radius: 12px; font-size: .95rem; font-weight: 700; border: none; }
.mpf__btn--ghost { background: var(--c-slate-100); color: var(--c-slate-700); }
.mpf__btn--primary { background: var(--c-leaf-800, #1A3D2E); color: #fff; }
.mpf__btn--primary:disabled { opacity: .5; }
</style>
