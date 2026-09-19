<template>
  <div class="mpf">
    <header class="mpf__header">
      <h1 class="mpf__title">Stock</h1>
      <p class="mpf__sub">Lo que cosechaste y cuánto queda. Para producir hash, aceite o prerolls, abrí el frasco.</p>
    </header>

    <div v-if="f.cargando.value" class="mpf__loading"><i class="bi bi-arrow-repeat mpf__spin"></i> Cargando…</div>

    <template v-else>
      <!-- Lo que está entre la cosecha y el frasco. Pesar es lo que crea el stock. -->
      <section v-if="f.porPesar.value.length" class="mpf__section">
        <h2 class="mpf__section-title">Por pesar</h2>
        <div class="mpf__list">
          <RouterLink v-for="l in f.porPesar.value" :key="l.id"
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
        <div v-if="!f.frascos.value.length" class="mpf__empty">
          <i class="bi bi-archive"></i>
          <p class="mpf__empty-title">Todavía no hay nada enfrascado</p>
          <p class="mpf__empty-hint">Cuando coseches y peses un lote, aparece acá con sus gramos.</p>
        </div>
        <div v-else class="mpf__list">
          <div v-for="s in f.frascos.value" :key="s.id" class="mpf__card">
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

      <section v-if="f.agotados.value.length" class="mpf__section">
        <h2 class="mpf__section-title">Terminados</h2>
        <div class="mpf__list">
          <div v-for="s in f.agotados.value.slice(0, 10)" :key="s.id" class="mpf__card mpf__card--off">
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
    <MobileSheet v-model="sheet" :title="f.consumo.stock ? `Consumí de ${f.consumo.stock.genetica_nombre || f.consumo.stock.numero_lote_producto || 'este frasco'}` : ''">
      <ConsumoForm v-if="f.consumo.stock" :consumo="f.consumo" :hoy="f.hoy" @guardar="confirmarConsumo" @cancelar="sheet = false" />
    </MobileSheet>
  </div>
</template>

<script setup>
// Los frascos del cultivador de casa, en el teléfono. El estado vive en `useFrascosPersonal`
// (compartido con el escritorio); acá sólo la presentación.
import { ref, onMounted } from 'vue'
import { useFrascosPersonal, formaLabel, fmt } from '../../composables/useFrascosPersonal.js'
import { useToast } from '../../composables/useToast.js'
import { ESTADO_META } from '../../lib/loteHelpers.js'
import MobileSheet from '../../components/mobile/MobileSheet.vue'
import ConsumoForm from '../../components/personal/ConsumoForm.vue'

const f     = useFrascosPersonal()
const toast = useToast()

function meta(estado) { return ESTADO_META[estado] || { label: estado } }
// Íconos por estado del lote (Bootstrap Icons, no emoji: el emoji depende de la fuente del
// teléfono y en algunos aparece como un cuadrado).
const ICONO_ESTADO = {
  enraizado: 'bi-droplet', vegetativo: 'bi-flower3', floracion: 'bi-flower1', cosecha: 'bi-scissors',
  en_manicura: 'bi-scissors', curado: 'bi-archive', finalizado: 'bi-check2-circle',
}
function icono(estado) { return ICONO_ESTADO[estado] || 'bi-box-seam' }

const sheet = ref(false)
function abrirConsumo(s) { f.prepararConsumo(s); sheet.value = true }
async function confirmarConsumo() {
  const data = await f.confirmarConsumo()
  if (data) {
    sheet.value = false
    toast.success(`Anotado: ${fmt(f.consumo.cantidad)} ${data.unidad || 'g'}`)
  }
}

onMounted(() => f.cargar())
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

</style>
