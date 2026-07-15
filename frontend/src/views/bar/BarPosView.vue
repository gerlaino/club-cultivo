<script setup>
// POS de un bar concreto (Capa 1) — cara operativa. Estilo alineado a ContabilidadView.
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import { listEventosBar } from '../../lib/api.js'

const store  = useBarStore()
const auth   = useAuthStore()
const route  = useRoute()
const toast  = useToast()
const barId  = route.params.barId

const CATS = [
  { value: 'bebida', label: 'Bebidas' },
  { value: 'cocina', label: 'Cocina' },
  { value: 'merch',  label: 'Merch' },
  { value: 'otro',   label: 'Otros' },
]
const catActiva = ref('bebida')
const medioPago = ref('efectivo')
// Atribuir la venta a un evento en curso: descuenta lo reservado y suma al P&L del evento.
const eventos   = ref([])
const eventoSel = ref(null)
const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))

onMounted(() => {
  store.fetchProductos(barId, { activos: 'true' })
  listEventosBar(barId)
    .then(r => { eventos.value = (r.data || []).filter(e => ['en_venta', 'en_curso'].includes(e.estado)) })
    .catch(() => {})
})

const productosCat = computed(() => store.activos.filter(p => p.categoria === catActiva.value))
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

async function cobrar() {
  if (!store.carrito.length) return
  try { await store.cobrar(barId, medioPago.value, eventoSel.value); toast.success('Venta cobrada') }
  catch { toast.error(store.saveError || 'No se pudo cobrar') }
}
</script>

<template>
  <div class="cv">
    <div class="cv__header">
      <div class="cv__header-left">
        <h1 class="cv__title">Vender · {{ store.barActual?.nombre || 'Salón' }}</h1>
        <p class="cv__sub">{{ auth.user?.first_name || 'Vendedor' }}</p>
      </div>
      <div class="cv__header-right">
        <RouterLink to="/bar" class="cv__btn-ghost">Salón</RouterLink>
        <RouterLink v-if="esGestion" :to="`/bar/${barId}/panel`" class="cv__btn-ghost">Panel</RouterLink>
      </div>
    </div>

    <div class="cv__pos">
      <div class="cv__pos-catalog">
        <div class="cv__pos-tabs">
          <button v-for="c in CATS" :key="c.value" class="cv__sede-btn" :class="{ 'cv__sede-btn--active': catActiva === c.value }" @click="catActiva = c.value">{{ c.label }}</button>
        </div>
        <div v-if="store.loading" class="cv__empty-sm" style="padding:2rem 0;">Cargando…</div>
        <div v-else-if="!productosCat.length" class="cv__empty-sm" style="padding:2rem 0;">Sin productos en esta categoría.</div>
        <div v-else class="cv__prod-grid">
          <button v-for="p in productosCat" :key="p.id" class="cv__prod" :class="{ 'cv__prod--off': p.stock <= 0 }" :disabled="p.stock <= 0" @click="store.agregar(p)">
            <span class="cv__prod-name">{{ p.nombre }}</span>
            <span class="cv__prod-price">{{ fmt(p.precio_ars) }}</span>
            <span class="cv__prod-stock" :class="{ 'cv__td-red': p.stock_bajo }">stock {{ p.stock }}</span>
          </button>
        </div>
      </div>

      <aside class="cv__cart">
        <div class="cv__card-header"><span class="cv__card-title">Pedido</span></div>
        <div class="cv__cart-body">
          <div v-if="!store.carrito.length" class="cv__empty-sm">Tocá un producto para agregarlo.</div>
          <ul v-else class="cv__cart-list">
            <li v-for="l in store.carrito" :key="l.producto.id" class="cv__ci">
              <button class="cv__ci-btn" @click="store.quitar(l.producto.id)" aria-label="Quitar uno">−</button>
              <span class="cv__ci-qty">{{ l.cantidad }}</span>
              <span class="cv__ci-name">{{ l.producto.nombre }}</span>
              <span class="cv__ci-sub cv__num">{{ fmt(l.producto.precio_ars * l.cantidad) }}</span>
              <button class="cv__ci-btn" @click="store.agregar(l.producto)" aria-label="Agregar uno">+</button>
            </li>
          </ul>
          <div class="cv__cart-total"><span>Total</span><strong class="cv__num">{{ fmt(store.totalCarrito) }}</strong></div>
          <label v-if="eventos.length" class="cv__evento">
            <span class="cv__evento-lbl">🎉 Evento</span>
            <select v-model="eventoSel" class="cv__evento-sel">
              <option :value="null">Sin evento</option>
              <option v-for="ev in eventos" :key="ev.id" :value="ev.id">{{ ev.nombre }}</option>
            </select>
          </label>
          <div class="cv__pay">
            <button v-for="m in ['efectivo','transferencia','mercado_pago']" :key="m" class="cv__sede-btn" :class="{ 'cv__sede-btn--active': medioPago === m }" @click="medioPago = m">
              {{ m === 'mercado_pago' ? 'QR / MP' : (m === 'transferencia' ? 'Transfer' : 'Efectivo') }}
            </button>
          </div>
          <button class="cv__btn-primary cv__btn-block" :disabled="!store.carrito.length || store.saving" @click="cobrar">Cobrar {{ fmt(store.totalCarrito) }}</button>
          <button v-if="store.carrito.length" class="cv__link cv__link--center" @click="store.vaciar()">Vaciar</button>
        </div>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.cv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; color: #0f172a; }
.cv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.cv__title { font-size: 1.5rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.03em; }
.cv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.cv__header-right { display: flex; gap: .5rem; }
.cv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 10px; font-size: .84rem; font-weight: 500; cursor: pointer; text-decoration: none; }
.cv__btn-ghost:hover { border-color: #cbd5e1; color: #334155; }
.cv__btn-primary { background: #1b5e20; color: #fff; border: none; padding: .75rem 1.25rem; border-radius: 10px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .5; cursor: default; }
.cv__btn-block { width: 100%; }

.cv__pos { display: grid; grid-template-columns: 1fr 320px; gap: 1rem; align-items: start; }
@media (max-width: 780px) { .cv__pos { grid-template-columns: 1fr; } }
.cv__pos-tabs { display: flex; gap: .4rem; margin-bottom: 1rem; flex-wrap: wrap; }
.cv__sede-btn { padding: 7px 14px; border: 1.5px solid #e2e8f0; border-radius: 8px; background: #fff; font-size: 13px; color: #64748b; font-weight: 500; cursor: pointer; }
.cv__sede-btn--active { border-color: #1b5e20; background: rgba(27,94,32,.07); color: #1b5e20; }

.cv__prod-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: .6rem; }
.cv__prod { display: flex; flex-direction: column; gap: .2rem; align-items: flex-start; background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: .9rem; cursor: pointer; text-align: left; transition: border-color .12s; }
.cv__prod:hover { border-color: #1b5e20; }
.cv__prod--off { opacity: .45; cursor: not-allowed; }
.cv__prod-name { font-weight: 600; color: #0f172a; font-size: .9rem; }
.cv__prod-price { font-weight: 800; color: #1b5e20; }
.cv__prod-stock { font-size: .72rem; color: #94a3b8; }
.cv__td-red { color: #dc2626; }
.cv__empty-sm { color: #94a3b8; font-size: .82rem; text-align: center; padding: 1rem 0; }

.cv__cart { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; position: sticky; top: 1rem; }
.cv__card-header { padding: .9rem 1.1rem; border-bottom: 1px solid #f1f5f9; }
.cv__card-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.cv__cart-body { padding: 1rem 1.1rem 1.1rem; }
.cv__cart-list { list-style: none; margin: 0 0 .5rem; padding: 0; display: flex; flex-direction: column; gap: .5rem; }
.cv__ci { display: grid; grid-template-columns: 26px 22px 1fr auto 26px; align-items: center; gap: .5rem; font-size: .86rem; }
.cv__ci-btn { width: 26px; height: 26px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; cursor: pointer; font-weight: 700; color: #334155; line-height: 1; }
.cv__ci-qty { font-weight: 700; text-align: center; color: #0f172a; }
.cv__ci-name { color: #334155; }
.cv__ci-sub { font-weight: 600; color: #0f172a; }
.cv__num { font-variant-numeric: tabular-nums; }
.cv__cart-total { display: flex; justify-content: space-between; align-items: baseline; margin: 1rem 0; padding-top: .9rem; border-top: 1px solid #f1f5f9; }
.cv__cart-total strong { font-size: 1.5rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; }
.cv__evento { display: flex; align-items: center; gap: .5rem; margin-bottom: .6rem; }
.cv__evento-lbl { font-size: .74rem; font-weight: 600; color: #64748b; white-space: nowrap; }
.cv__evento-sel { flex: 1; padding: .4rem .55rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .82rem; background: #fff; color: #0f172a; }
.cv__evento-sel:focus { border-color: #1b5e20; outline: none; }
.cv__pay { display: flex; gap: .35rem; margin-bottom: .9rem; flex-wrap: wrap; }
.cv__pay .cv__sede-btn { flex: 1; padding: 7px 4px; font-size: 12px; text-align: center; }
.cv__link { background: none; border: none; color: #94a3b8; font-size: .82rem; font-weight: 500; cursor: pointer; }
.cv__link--center { display: block; width: 100%; text-align: center; margin-top: .5rem; }
.cv__link:hover { color: #64748b; }
</style>
