<script setup>
// Panel de un bar concreto (Capa 1) — cara analítica: resultado del mes + dashboard + config.
// Estilo alineado a ContabilidadView (paleta slate + verde marca #1b5e20, tipografía Inter).
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const store = useBarStore()
const auth  = useAuthStore()
const route = useRoute()
const toast = useToast()
const { confirm } = useConfirm()
const barId = route.params.barId

const CATS = ['bebida', 'cocina', 'merch', 'otro']
const esAdmin = computed(() => auth.user?.role === 'admin')
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

onMounted(() => { store.fetchDashboard(barId); store.fetchProductos(barId) })

const d = computed(() => store.dashboard)

const prodForm = ref(null)
function nuevoProducto() { prodForm.value = { nombre: '', categoria: 'bebida', precio_ars: null, costo_ars: null, stock: 0, stock_minimo: 0 } }
function editarProducto(p) { prodForm.value = { id: p.id, nombre: p.nombre, categoria: p.categoria, precio_ars: p.precio_ars, costo_ars: p.costo_ars, stock: p.stock, stock_minimo: p.stock_minimo } }
async function guardarProducto() {
  const f = prodForm.value
  if (!f.nombre?.trim() || !(f.precio_ars > 0)) { toast.warning('Nombre y precio son obligatorios'); return }
  const payload = { nombre: f.nombre.trim(), categoria: f.categoria, precio_ars: f.precio_ars, costo_ars: f.costo_ars || null, stock: f.stock || 0, stock_minimo: f.stock_minimo || 0 }
  try {
    if (f.id) await store.actualizarProducto(barId, f.id, payload)
    else      await store.crearProducto(barId, payload)
    toast.success('Producto guardado'); prodForm.value = null
  } catch { toast.error(store.saveError) }
}
async function reponer(p) {
  const cant = Number(prompt(`¿Cuántas unidades de "${p.nombre}" ingresan?`, '1'))
  if (!cant || cant <= 0) return
  try { await store.reponer(barId, p.id, cant); toast.success('Stock repuesto') }
  catch { toast.error(store.saveError) }
}
async function borrarProducto(p) {
  if (!(await confirm({ title: 'Eliminar producto', message: `¿Eliminar "${p.nombre}"? Se recupera desde la papelera.`, variant: 'danger' }))) return
  try { await store.eliminarProducto(barId, p.id); toast.success('Producto eliminado') }
  catch { toast.error('No se pudo eliminar') }
}
</script>

<template>
  <div class="cv">
    <div class="cv__header">
      <div class="cv__header-left">
        <h1 class="cv__title">{{ store.barActual?.nombre || 'Bar' }}</h1>
        <p class="cv__sub">{{ store.barActual?.sede?.nombre }} · pulso del bar y productos</p>
      </div>
      <div class="cv__header-right">
        <RouterLink to="/bar" class="cv__btn-ghost">Bares</RouterLink>
        <RouterLink :to="`/bar/${barId}/eventos`" class="cv__btn-ghost">Eventos</RouterLink>
        <RouterLink :to="`/bar/${barId}/vender`" class="cv__btn-primary">Vender</RouterLink>
      </div>
    </div>

    <template v-if="d">
      <!-- Resultado del mes + KPIs -->
      <div class="cv__kpis">
        <div class="cv__kpi cv__kpi--hero">
          <span class="cv__kpi-label">Resultado del mes</span>
          <span class="cv__kpi-val" :class="d.resultado_mes.resultado >= 0 ? 'cv__kpi-val--green' : 'cv__kpi-val--red'">{{ fmt(d.resultado_mes.resultado) }}</span>
          <span class="cv__kpi-foot">ingresos {{ fmt(d.resultado_mes.ingresos) }} · egresos {{ fmt(d.resultado_mes.egresos) }}</span>
          <span class="cv__kpi-bar" :style="{ background: d.resultado_mes.resultado >= 0 ? '#15803d' : '#dc2626' }"></span>
        </div>
        <div class="cv__kpi">
          <span class="cv__kpi-label">Ventas de hoy</span>
          <span class="cv__kpi-val">{{ fmt(d.hoy.total) }}</span>
          <span class="cv__kpi-foot">{{ d.hoy.tickets }} tickets · prom. {{ fmt(d.hoy.ticket_promedio) }}</span>
        </div>
        <div class="cv__kpi">
          <span class="cv__kpi-label">En caja hoy</span>
          <span class="cv__kpi-val">{{ fmt(d.hoy.total) }}</span>
          <span class="cv__kpi-foot">{{ Object.entries(d.hoy.por_medio_pago || {}).map(([m, v]) => `${m} ${fmt(v)}`).join(' · ') || 'sin ventas' }}</span>
        </div>
      </div>

      <div class="cv__grid2">
        <div class="cv__card">
          <div class="cv__card-header"><span class="cv__card-title">Top de hoy</span></div>
          <div class="cv__card-body">
            <div v-if="!d.top_productos?.length" class="cv__empty-sm">Todavía no hubo ventas hoy.</div>
            <ul v-else class="cv__rank">
              <li v-for="(t, i) in d.top_productos" :key="t.nombre"><span class="cv__rank-n">{{ i + 1 }}</span><span class="cv__rank-name">{{ t.nombre }}</span><span class="cv__rank-qty">{{ t.cantidad }}</span></li>
            </ul>
          </div>
        </div>
        <div class="cv__card">
          <div class="cv__card-header"><span class="cv__card-title">Reponer pronto</span></div>
          <div class="cv__card-body">
            <div v-if="!d.reponer?.length" class="cv__empty-sm">Todo con stock suficiente.</div>
            <ul v-else class="cv__repo">
              <li v-for="r in d.reponer" :key="r.id"><span>{{ r.nombre }}</span><span class="cv__repo-low">{{ r.stock }} / mín {{ r.minimo }}</span></li>
            </ul>
          </div>
        </div>
      </div>
    </template>
    <div v-else class="cv__empty-sm" style="padding:3rem 0;">Cargando…</div>

    <!-- Productos (admin) -->
    <div v-if="esAdmin" class="cv__card cv__card--mt">
      <div class="cv__card-header cv__card-header--flex">
        <span class="cv__card-title">Productos</span>
        <button class="cv__btn-primary cv__btn-primary--sm" @click="nuevoProducto">+ Producto</button>
      </div>

      <div v-if="prodForm" class="cv__form-row">
        <input v-model.trim="prodForm.nombre" class="cv__filtro-input" placeholder="Nombre" maxlength="50" />
        <select v-model="prodForm.categoria" class="cv__filtro-input"><option v-for="c in CATS" :key="c" :value="c">{{ c }}</option></select>
        <input v-model.number="prodForm.precio_ars" type="number" min="0" step="any" class="cv__filtro-input cv__filtro-input--sm" placeholder="Precio" />
        <input v-model.number="prodForm.costo_ars" type="number" min="0" step="any" class="cv__filtro-input cv__filtro-input--sm" placeholder="Costo" />
        <input v-model.number="prodForm.stock" type="number" min="0" step="any" class="cv__filtro-input cv__filtro-input--sm" placeholder="Stock" />
        <input v-model.number="prodForm.stock_minimo" type="number" min="0" step="any" class="cv__filtro-input cv__filtro-input--sm" placeholder="Mín" />
        <div class="cv__form-actions">
          <button class="cv__btn-ghost" @click="prodForm = null">Cancelar</button>
          <button class="cv__btn-primary" :disabled="store.saving" @click="guardarProducto">Guardar</button>
        </div>
      </div>

      <div class="cv__table-wrap">
        <table class="cv__table">
          <thead><tr><th>Producto</th><th>Categoría</th><th class="cv__ta-r">Precio</th><th class="cv__ta-r">Margen</th><th class="cv__ta-r">Stock</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in store.productos" :key="p.id" :class="{ 'cv__tr-off': !p.activo }">
              <td class="cv__td-strong">{{ p.nombre }}</td>
              <td class="cv__td-muted">{{ p.categoria }}</td>
              <td class="cv__ta-r cv__num">{{ fmt(p.precio_ars) }}</td>
              <td class="cv__ta-r cv__td-muted">{{ p.margen_pct != null ? p.margen_pct + '%' : '—' }}</td>
              <td class="cv__ta-r cv__num" :class="{ 'cv__td-red': p.stock_bajo }">{{ p.stock }}</td>
              <td class="cv__ta-r cv__acts">
                <button class="cv__link" @click="reponer(p)">Reponer</button>
                <button class="cv__link" @click="editarProducto(p)">Editar</button>
                <button class="cv__link cv__link--danger" @click="borrarProducto(p)">Borrar</button>
              </td>
            </tr>
            <tr v-if="!store.productos.length"><td colspan="6" class="cv__empty-sm">Sin productos. Creá el primero.</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Kit alineado a ContabilidadView (paleta slate + verde marca). Tipografía Inter (heredada). */
.cv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; color: #0f172a; }

.cv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.75rem; }
.cv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.cv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.cv__header-right { display: flex; gap: .5rem; }

.cv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; text-decoration: none; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .55; cursor: default; }
.cv__btn-primary--sm { padding: .5rem .9rem; font-size: .82rem; }
.cv__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1.1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; text-decoration: none; }
.cv__btn-ghost:hover { border-color: #cbd5e1; color: #334155; }

/* KPIs */
.cv__kpis { display: grid; grid-template-columns: 1.4fr 1fr 1fr; gap: 1rem; margin-bottom: 1rem; }
@media (max-width: 720px) { .cv__kpis { grid-template-columns: 1fr; } }
.cv__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; position: relative; overflow: hidden; display: flex; flex-direction: column; gap: .35rem; }
.cv__kpi-label { font-size: .72rem; color: #64748b; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }
.cv__kpi-val { font-size: 1.4rem; font-weight: 800; letter-spacing: -.03em; color: #0f172a; }
.cv__kpi--hero .cv__kpi-val { font-size: 2rem; }
.cv__kpi-val--green { color: #15803d; } .cv__kpi-val--red { color: #dc2626; }
.cv__kpi-foot { font-size: .74rem; color: #94a3b8; }
.cv__kpi-bar { position: absolute; left: 0; right: 0; bottom: 0; height: 3px; }

/* Cards */
.cv__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 720px) { .cv__grid2 { grid-template-columns: 1fr; } }
.cv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.cv__card--mt { margin-top: 1rem; }
.cv__card-header { padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.cv__card-header--flex { display: flex; align-items: center; justify-content: space-between; }
.cv__card-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.cv__card-body { padding: .5rem 1.25rem 1rem; }
.cv__empty-sm { color: #94a3b8; font-size: .82rem; text-align: center; padding: 1rem 0; }

.cv__rank, .cv__repo { list-style: none; margin: 0; padding: 0; }
.cv__rank li { display: flex; align-items: center; gap: .7rem; padding: .55rem 0; border-bottom: 1px solid #f8fafc; font-size: .85rem; }
.cv__rank li:last-child, .cv__repo li:last-child { border-bottom: none; }
.cv__rank-n { width: 20px; height: 20px; border-radius: 6px; background: #f1f5f9; color: #64748b; font-size: .72rem; font-weight: 700; display: grid; place-items: center; }
.cv__rank-name { flex: 1; color: #334155; }
.cv__rank-qty { font-weight: 700; color: #0f172a; }
.cv__repo li { display: flex; justify-content: space-between; padding: .55rem 0; border-bottom: 1px solid #f8fafc; font-size: .85rem; color: #334155; }
.cv__repo-low { color: #dc2626; font-weight: 600; }

/* Form inline */
.cv__form-row { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; padding: 1rem 1.25rem; background: #fafbfc; border-bottom: 1px solid #f1f5f9; }
.cv__form-actions { display: flex; gap: .5rem; margin-left: auto; }
.cv__filtro-input { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .8rem; font-size: .82rem; color: #0f172a; }
.cv__filtro-input:focus { border-color: #1b5e20; outline: none; }
.cv__filtro-input--sm { width: 92px; }

/* Tabla */
.cv__table-wrap { overflow-x: auto; }
.cv__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.cv__table th { padding: .75rem 1rem; font-size: .7rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid #f1f5f9; background: #fafbfc; text-align: left; }
.cv__table td { padding: .75rem 1rem; border-bottom: 1px solid #f8fafc; color: #334155; }
.cv__table tbody tr:hover td { background: #fafbfc; }
.cv__tr-off td { opacity: .5; }
.cv__ta-r { text-align: right; }
.cv__num { font-variant-numeric: tabular-nums; }
.cv__td-strong { font-weight: 600; color: #0f172a; }
.cv__td-muted { color: #94a3b8; }
.cv__td-red { color: #dc2626; font-weight: 600; }
.cv__acts { white-space: nowrap; }
.cv__link { background: none; border: none; color: #64748b; font-size: .8rem; font-weight: 500; cursor: pointer; padding: .1rem .35rem; }
.cv__link:hover { color: #0f172a; }
.cv__link--danger:hover { color: #dc2626; }
</style>
