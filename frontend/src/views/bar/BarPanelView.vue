<script setup>
// Panel del bar (Bloque 3) — cara analítica del admin: dashboard + config de productos.
import { ref, computed, onMounted } from 'vue'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const store = useBarStore()
const auth  = useAuthStore()
const toast = useToast()
const { confirm } = useConfirm()

const CATS = ['bebida', 'cocina', 'merch', 'otro']
const esAdmin = computed(() => auth.user?.role === 'admin')
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

onMounted(() => { store.fetchDashboard(); store.fetchProductos() })

const d = computed(() => store.dashboard)

// ── Config de productos ───────────────────────────────────────
const prodForm = ref(null)
function nuevoProducto() { prodForm.value = { nombre: '', categoria: 'bebida', precio_ars: null, costo_ars: null, stock: 0, stock_minimo: 0 } }
function editarProducto(p) { prodForm.value = { id: p.id, nombre: p.nombre, categoria: p.categoria, precio_ars: p.precio_ars, costo_ars: p.costo_ars, stock: p.stock, stock_minimo: p.stock_minimo } }
async function guardarProducto() {
  const f = prodForm.value
  if (!f.nombre?.trim() || !(f.precio_ars > 0)) { toast.warning('Nombre y precio son obligatorios'); return }
  const payload = { nombre: f.nombre.trim(), categoria: f.categoria, precio_ars: f.precio_ars, costo_ars: f.costo_ars || null, stock: f.stock || 0, stock_minimo: f.stock_minimo || 0 }
  try {
    if (f.id) await store.actualizarProducto(f.id, payload)
    else      await store.crearProducto(payload)
    toast.success('Producto guardado'); prodForm.value = null
  } catch { toast.error(store.saveError) }
}
async function reponer(p) {
  const cant = Number(prompt(`¿Cuántas unidades de "${p.nombre}" ingresan?`, '1'))
  if (!cant || cant <= 0) return
  try { await store.reponer(p.id, cant); toast.success('Stock repuesto') }
  catch { toast.error(store.saveError) }
}
async function borrarProducto(p) {
  if (!(await confirm({ title: 'Eliminar producto', message: `¿Eliminar "${p.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarProducto(p.id); toast.success('Producto eliminado') }
  catch { toast.error('No se pudo eliminar') }
}
</script>

<template>
  <div class="bp">
    <header class="bp__head">
      <div>
        <h1>Bar · Panel</h1>
        <p>El pulso del bar y la configuración de productos.</p>
      </div>
      <RouterLink to="/bar" class="btn btn--primary">Vender →</RouterLink>
    </header>

    <!-- KPIs -->
    <div v-if="d" class="bp__kpis">
      <div class="kpi"><span>Ventas de hoy</span><strong>{{ fmt(d.hoy.total) }}</strong></div>
      <div class="kpi"><span>Tickets</span><strong>{{ d.hoy.tickets }}</strong><small>prom. {{ fmt(d.hoy.ticket_promedio) }}</small></div>
      <div class="kpi"><span>En caja</span><strong>{{ fmt(d.hoy.total) }}</strong>
        <small>{{ Object.entries(d.hoy.por_medio_pago || {}).map(([m, v]) => `${m}: ${fmt(v)}`).join(' · ') || 'sin ventas' }}</small>
      </div>
    </div>

    <div class="bp__cols">
      <!-- Top productos -->
      <section class="card">
        <h2>Top de hoy</h2>
        <div v-if="!d?.top_productos?.length" class="empty">Todavía no hubo ventas hoy.</div>
        <ul v-else class="rank">
          <li v-for="(t, i) in d.top_productos" :key="t.nombre">
            <span class="rank__n">{{ i + 1 }}</span>
            <span class="rank__name">{{ t.nombre }}</span>
            <span class="rank__qty">{{ t.cantidad }}</span>
          </li>
        </ul>
      </section>

      <!-- Reponer -->
      <section class="card">
        <h2>Reponer pronto</h2>
        <div v-if="!d?.reponer?.length" class="empty">Todo con stock suficiente.</div>
        <ul v-else class="repo">
          <li v-for="r in d.reponer" :key="r.id">
            <span>{{ r.nombre }}</span>
            <span class="repo__low">{{ r.stock }} / mín {{ r.minimo }}</span>
          </li>
        </ul>
      </section>
    </div>

    <!-- Config de productos (admin) -->
    <section v-if="esAdmin" class="card bp__config">
      <div class="card__head">
        <h2>Productos</h2>
        <button class="btn btn--primary" @click="nuevoProducto">+ Producto</button>
      </div>

      <form v-if="prodForm" class="pform" @submit.prevent="guardarProducto">
        <input v-model.trim="prodForm.nombre" class="inp" placeholder="Nombre" maxlength="50" />
        <select v-model="prodForm.categoria" class="inp"><option v-for="c in CATS" :key="c" :value="c">{{ c }}</option></select>
        <input v-model.number="prodForm.precio_ars" type="number" min="0" step="any" class="inp inp--sm" placeholder="Precio" />
        <input v-model.number="prodForm.costo_ars" type="number" min="0" step="any" class="inp inp--sm" placeholder="Costo" />
        <input v-model.number="prodForm.stock" type="number" min="0" step="any" class="inp inp--sm" placeholder="Stock" />
        <input v-model.number="prodForm.stock_minimo" type="number" min="0" step="any" class="inp inp--sm" placeholder="Mín" />
        <div class="pform__actions">
          <button type="button" class="btn" @click="prodForm = null">Cancelar</button>
          <button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button>
        </div>
      </form>

      <table class="tbl">
        <thead><tr><th>Producto</th><th>Cat.</th><th>Precio</th><th>Margen</th><th>Stock</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in store.productos" :key="p.id" :class="{ 'is-off': !p.activo }">
            <td>{{ p.nombre }}</td>
            <td class="mut">{{ p.categoria }}</td>
            <td class="num">{{ fmt(p.precio_ars) }}</td>
            <td class="num mut">{{ p.margen_pct != null ? p.margen_pct + '%' : '—' }}</td>
            <td class="num" :class="{ low: p.stock_bajo }">{{ p.stock }}</td>
            <td class="acts">
              <button class="lnk" @click="reponer(p)">Reponer</button>
              <button class="lnk" @click="editarProducto(p)">Editar</button>
              <button class="lnk lnk--danger" @click="borrarProducto(p)">Borrar</button>
            </td>
          </tr>
          <tr v-if="!store.productos.length"><td colspan="6" class="empty">Sin productos. Creá el primero.</td></tr>
        </tbody>
      </table>
    </section>
  </div>
</template>

<style scoped>
.bp { padding: var(--sp-6, 24px); max-width: 940px; margin: 0 auto; }
.bp__head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--sp-3, 12px); }
.bp__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.bp__head p { color: var(--c-ink-500); margin: 4px 0 0; font-size: var(--fs-14, 14px); }

.bp__kpis { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin: var(--sp-5, 20px) 0; }
@media (max-width: 640px) { .bp__kpis { grid-template-columns: 1fr; } }
.kpi { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: var(--sp-4, 16px); }
.kpi span { font-size: var(--fs-12, 12px); color: var(--c-ink-400); text-transform: uppercase; letter-spacing: .05em; }
.kpi strong { display: block; font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); margin-top: 6px; }
.kpi small { display: block; color: var(--c-ink-400); font-size: var(--fs-12, 12px); margin-top: 3px; }

.bp__cols { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
@media (max-width: 640px) { .bp__cols { grid-template-columns: 1fr; } }
.card { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); }
.card h2 { font-size: var(--fs-16, 16px); font-weight: 650; color: var(--c-ink-900); margin: 0 0 var(--sp-3, 12px); }
.card__head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-3, 12px); }
.card__head h2 { margin: 0; }
.empty { color: var(--c-ink-400); font-size: var(--fs-13, 13px); padding: var(--sp-3, 12px) 0; text-align: center; }

.rank { list-style: none; margin: 0; padding: 0; }
.rank li { display: flex; align-items: center; gap: 10px; padding: 7px 0; border-bottom: 1px solid var(--c-ink-100); font-size: var(--fs-14, 14px); }
.rank li:last-child { border-bottom: none; }
.rank__n { width: 20px; height: 20px; border-radius: 6px; background: var(--c-ink-100); color: var(--c-ink-600); font-size: var(--fs-12, 12px); font-weight: 700; display: grid; place-items: center; }
.rank__name { flex: 1; color: var(--c-ink-800); }
.rank__qty { font-weight: 700; color: var(--c-ink-900); font-variant-numeric: tabular-nums; }
.repo { list-style: none; margin: 0; padding: 0; }
.repo li { display: flex; justify-content: space-between; padding: 7px 0; border-bottom: 1px solid var(--c-ink-100); font-size: var(--fs-14, 14px); }
.repo li:last-child { border-bottom: none; }
.repo__low { color: var(--c-rust-600, #b23b2e); font-weight: 600; font-variant-numeric: tabular-nums; }

.bp__config { margin-top: 12px; }
.pform { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; background: var(--c-ink-50, #f6f7f5); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px); margin-bottom: var(--sp-3, 12px); }
.pform__actions { display: flex; gap: 8px; margin-left: auto; }
.inp { padding: 7px 9px; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: var(--c-ink-900); }
.inp--sm { width: 84px; }

.tbl { width: 100%; border-collapse: collapse; font-size: var(--fs-14, 14px); }
.tbl th { text-align: left; font-size: var(--fs-11, 11px); text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-400); font-weight: 700; padding: 8px 6px; border-bottom: 1px solid var(--c-ink-100); }
.tbl td { padding: 9px 6px; border-bottom: 1px solid var(--c-ink-100); color: var(--c-ink-800); }
.tbl tr.is-off { opacity: .5; }
.tbl .num { text-align: right; font-variant-numeric: tabular-nums; }
.tbl .mut { color: var(--c-ink-400); }
.tbl .low { color: var(--c-rust-600, #b23b2e); font-weight: 600; }
.tbl .acts { text-align: right; white-space: nowrap; }
.lnk { background: none; border: none; color: var(--c-ink-500); font-size: var(--fs-13, 13px); cursor: pointer; padding: 2px 5px; }
.lnk:hover { color: var(--c-ink-900); }
.lnk--danger:hover { color: var(--c-rust-600, #b23b2e); }

.btn { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-800); border-radius: var(--r-sm, 8px); padding: 7px 13px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; text-decoration: none; }
.btn--primary { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
