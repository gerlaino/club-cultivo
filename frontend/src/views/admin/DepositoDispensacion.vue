<script setup>
// Depósito de Dispensación (solo lectura): la flor seca y sus derivados (modelo Stock). NO se
// edita acá — el stock entra por Cosecha/Manicura y sale por Dispensación. Esta vista lo trae a
// la pantalla de Depósito para verlo junto a los demás. Respeta el filtro de sede del padre.
//
// LA MISMA TABLA QUE LA PANTALLA DE STOCK (`TablaInventarioStock`), con las mismas columnas y el
// mismo endpoint (`/stocks/inventario`): eran dos tablas del mismo stock que decían cosas
// distintas, y ésta calculaba «En depósito» en el navegador. Los KPIs también vienen del backend
// —con la tabla paginada, sumar las filas daría sólo lo de la página—.
import { ref, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listStockInventario } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'
import TablaInventarioStock from '../../components/stock/TablaInventarioStock.vue'
import Paginator from '../../components/ui/Paginator.vue'

const props = defineProps({ sedeId: { type: [Number, null], default: null } })

const router  = useRouter()
const auth    = useAuthStore()
// La ficha del stock es sólo del admin: a los demás la fila no los lleva a ningún lado.
const esAdmin = auth.user?.role === 'admin'
const { esPersonal } = useUsoPersonal()

const stocks  = ref([])
const totales = ref({})
const total   = ref(0)
const page    = ref(1)
const perPage = ref(25)
const orden   = ref({ campo: '', dir: 'desc' })
const loading = ref(false)

async function cargar() {
  loading.value = true
  try {
    const params = { page: page.value, per_page: perPage.value }
    if (props.sedeId != null) params.sede_id = props.sedeId
    if (orden.value.campo) { params.orden = orden.value.campo; params.dir = orden.value.dir }
    const { data } = await listStockInventario(params)
    stocks.value  = data?.stocks || []
    totales.value = data?.totales || {}
    total.value   = data?.meta?.total || 0
  } catch { stocks.value = []; totales.value = {}; total.value = 0 }
  finally { loading.value = false }
}
onMounted(cargar)
watch(() => props.sedeId, () => { page.value = 1; cargar() })

function onOrden (o) { orden.value = o; page.value = 1; cargar() }
function onPage (p) { page.value = p; cargar() }
function onPerPage (n) { perPage.value = n; page.value = 1; cargar() }

const fmtG = (n) => Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
</script>

<template>
  <div class="dd">
    <div class="dd__banner">
      <i class="bi bi-lock"></i>
      <span>Solo lectura. La flor entra por <b>Cosecha/Manicura</b> y sale por <b>Dispensación</b> — desde acá no se edita.</span>
    </div>

    <!-- ES UNA PANTALLA DE DEPÓSITO: dice cuánto hay GUARDADO y cuánto está sobre la mesa, por
         separado. El producto que sube al mostrador no se perdió, cambió de lugar. -->
    <div class="dd__summary">
      <div class="dd__kpi">
        <span class="dd__kpi-label">Flor seca en depósito</span>
        <span class="dd__kpi-val">{{ fmtG(totales.en_deposito_g) }} <small>g</small></span>
      </div>
      <div class="dd__kpi">
        <span class="dd__kpi-label">Sobre la mesa</span>
        <span class="dd__kpi-val">{{ fmtG(totales.en_mesa_g) }} <small>g</small></span>
      </div>
      <div class="dd__kpi">
        <span class="dd__kpi-label">Reservada a pacientes</span>
        <span class="dd__kpi-val">{{ fmtG(totales.reservado_g) }} <small>g</small></span>
      </div>
      <div class="dd__kpi">
        <span class="dd__kpi-label">Derivados</span>
        <span class="dd__kpi-val">{{ totales.derivados_items || 0 }} <small>items</small></span>
      </div>
    </div>

    <div v-if="loading" class="dd__empty">Cargando flor…</div>
    <div v-else-if="!stocks.length" class="dd__empty dd__empty--box">
      No hay stock de dispensación en este alcance. La flor aparece acá cuando se cosecha y asigna.
    </div>

    <template v-else>
      <TablaInventarioStock
        :stocks="stocks" :orden="orden" :es-personal="esPersonal" :abrible="esAdmin"
        @update:orden="onOrden" @abrir="s => router.push(`/admin/stock/${s.id}`)"
      />
      <Paginator
        :page="page" :per-page="perPage" :total="total"
        @update:page="onPage" @update:per-page="onPerPage"
      />
    </template>
  </div>
</template>

<style scoped>
.dd { display: flex; flex-direction: column; gap: 1rem; }
.dd__banner { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: var(--c-slate-600); background: var(--c-slate-100); border: 1px solid var(--c-slate-200); border-radius: 10px; padding: .6rem .85rem; line-height: 1.4; }
.dd__banner .bi { color: var(--c-slate-500); }

.dd__summary { display: flex; gap: 2.5rem; background: #fff; border: 1px solid #e8edf2; border-radius: 13px; padding: 1rem 1.4rem; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.dd__kpi { display: flex; flex-direction: column; gap: .15rem; }
.dd__kpi-label { font-size: .64rem; text-transform: uppercase; letter-spacing: .08em; color: var(--c-slate-400); font-weight: 700; }
.dd__kpi-val { font-size: 1.35rem; font-weight: 800; letter-spacing: -.03em; color: var(--c-slate-900); font-variant-numeric: tabular-nums; }
.dd__kpi-val small { font-size: .8rem; font-weight: 600; color: var(--c-slate-400); }


.dd__empty { color: var(--c-slate-400); padding: 2.5rem; text-align: center; font-size: .9rem; }
.dd__empty--box { background: #fbfcfd; border: 1px dashed var(--c-slate-200); border-radius: 14px; }
</style>
