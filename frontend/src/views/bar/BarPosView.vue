<script setup>
// POS del bar (Bloque 3) — cara operativa. La usa admin/supervisor/dispensador para vender.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'

const store  = useBarStore()
const auth   = useAuthStore()
const router = useRouter()
const toast  = useToast()

const CATS = [
  { value: 'bebida', label: 'Bebidas' },
  { value: 'cocina', label: 'Cocina' },
  { value: 'merch',  label: 'Merch' },
  { value: 'otro',   label: 'Otros' },
]
const catActiva = ref('bebida')
const medioPago = ref('efectivo')

const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))

onMounted(() => store.fetchProductos({ activos: 'true' }))

const productosCat = computed(() => store.activos.filter(p => p.categoria === catActiva.value))
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

async function cobrar() {
  if (!store.carrito.length) return
  try {
    await store.cobrar(medioPago.value)
    toast.success('Venta cobrada')
  } catch {
    toast.error(store.saveError || 'No se pudo cobrar')
  }
}
</script>

<template>
  <div class="pos">
    <header class="pos__head">
      <div>
        <h1>Vender · Bar</h1>
        <span class="pos__who">{{ auth.user?.first_name || 'Vendedor' }}</span>
      </div>
      <RouterLink v-if="esGestion" to="/bar/panel" class="pos__link">Ver panel →</RouterLink>
    </header>

    <div class="pos__body">
      <!-- Grilla de productos -->
      <div class="pos__catalog">
        <div class="pos__tabs">
          <button v-for="c in CATS" :key="c.value" class="pos__tab" :class="{ 'is-on': catActiva === c.value }" @click="catActiva = c.value">{{ c.label }}</button>
        </div>
        <div v-if="store.loading" class="pos__empty">Cargando…</div>
        <div v-else-if="!productosCat.length" class="pos__empty">Sin productos en esta categoría.</div>
        <div v-else class="pos__grid">
          <button
            v-for="p in productosCat" :key="p.id"
            class="prod" :class="{ 'prod--off': p.stock <= 0 }"
            :disabled="p.stock <= 0"
            @click="store.agregar(p)"
          >
            <span class="prod__name">{{ p.nombre }}</span>
            <span class="prod__price">{{ fmt(p.precio_ars) }}</span>
            <span class="prod__stock" :class="{ low: p.stock_bajo }">stock {{ p.stock }}</span>
          </button>
        </div>
      </div>

      <!-- Carrito -->
      <aside class="pos__cart">
        <h2>Pedido</h2>
        <div v-if="!store.carrito.length" class="pos__cart-empty">Tocá un producto para agregarlo.</div>
        <ul v-else class="pos__cart-list">
          <li v-for="l in store.carrito" :key="l.producto.id" class="ci">
            <button class="ci__minus" @click="store.quitar(l.producto.id)" aria-label="Quitar uno">−</button>
            <span class="ci__qty">{{ l.cantidad }}</span>
            <span class="ci__name">{{ l.producto.nombre }}</span>
            <span class="ci__sub">{{ fmt(l.producto.precio_ars * l.cantidad) }}</span>
            <button class="ci__plus" @click="store.agregar(l.producto)" aria-label="Agregar uno">+</button>
          </li>
        </ul>

        <div class="pos__total"><span>Total</span><strong>{{ fmt(store.totalCarrito) }}</strong></div>

        <div class="pos__pay">
          <button v-for="m in ['efectivo','transferencia','mercado_pago']" :key="m"
                  class="pay" :class="{ 'is-on': medioPago === m }" @click="medioPago = m">
            {{ m === 'mercado_pago' ? 'QR / MP' : (m === 'transferencia' ? 'Transfer' : 'Efectivo') }}
          </button>
        </div>

        <button class="pos__cobrar" :disabled="!store.carrito.length || store.saving" @click="cobrar">
          Cobrar {{ fmt(store.totalCarrito) }}
        </button>
        <button v-if="store.carrito.length" class="pos__vaciar" @click="store.vaciar()">Vaciar</button>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.pos { padding: var(--sp-5, 20px); max-width: 1080px; margin: 0 auto; }
.pos__head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-4, 16px); }
.pos__head h1 { font-size: var(--fs-22, 22px); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.pos__who { font-size: var(--fs-13, 13px); color: var(--c-ink-400); }
.pos__link { font-size: var(--fs-14, 14px); color: var(--c-leaf-700, #2f6b3d); text-decoration: none; font-weight: 600; }

.pos__body { display: grid; grid-template-columns: 1fr 300px; gap: var(--sp-4, 16px); align-items: start; }
@media (max-width: 780px) { .pos__body { grid-template-columns: 1fr; } }

.pos__tabs { display: flex; gap: 6px; margin-bottom: var(--sp-3, 12px); flex-wrap: wrap; }
.pos__tab { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-600); border-radius: 999px; padding: 6px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.pos__tab.is-on { background: var(--c-ink-900); border-color: var(--c-ink-900); color: #fff; }

.pos__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; }
.prod { display: flex; flex-direction: column; gap: 3px; align-items: flex-start; background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: 14px 13px; cursor: pointer; text-align: left; }
.prod:hover { border-color: var(--c-leaf-700, #2f6b3d); }
.prod--off { opacity: .45; cursor: not-allowed; }
.prod__name { font-weight: 600; color: var(--c-ink-900); font-size: var(--fs-14, 14px); }
.prod__price { font-weight: 700; color: var(--c-leaf-700, #2f6b3d); font-variant-numeric: tabular-nums; }
.prod__stock { font-size: var(--fs-11, 11px); color: var(--c-ink-400); }
.prod__stock.low { color: var(--c-rust-600, #b23b2e); }
.pos__empty { color: var(--c-ink-400); padding: var(--sp-6, 24px); text-align: center; }

.pos__cart { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); position: sticky; top: 16px; }
.pos__cart h2 { font-size: var(--fs-14, 14px); text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-400); margin: 0 0 var(--sp-3, 12px); }
.pos__cart-empty { color: var(--c-ink-400); font-size: var(--fs-13, 13px); padding: var(--sp-4, 16px) 0; }
.pos__cart-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.ci { display: grid; grid-template-columns: 24px 20px 1fr auto 24px; align-items: center; gap: 8px; font-size: var(--fs-14, 14px); }
.ci__minus, .ci__plus { width: 24px; height: 24px; border-radius: 6px; border: 1px solid var(--c-ink-200); background: var(--c-ink-50, #f6f7f5); cursor: pointer; font-weight: 700; color: var(--c-ink-700); line-height: 1; }
.ci__qty { font-weight: 700; text-align: center; color: var(--c-ink-900); }
.ci__name { color: var(--c-ink-700); }
.ci__sub { font-variant-numeric: tabular-nums; color: var(--c-ink-900); font-weight: 600; }

.pos__total { display: flex; justify-content: space-between; align-items: baseline; margin: var(--sp-4, 16px) 0; padding-top: var(--sp-3, 12px); border-top: 1px solid var(--c-ink-100); }
.pos__total strong { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); }
.pos__pay { display: flex; gap: 6px; margin-bottom: var(--sp-3, 12px); flex-wrap: wrap; }
.pay { flex: 1; border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-600); border-radius: var(--r-sm, 8px); padding: 7px 4px; font-size: var(--fs-12, 12px); font-weight: 600; cursor: pointer; }
.pay.is-on { background: var(--c-leaf-50, #e7f0e5); border-color: var(--c-leaf-700, #2f6b3d); color: var(--c-leaf-700, #2f6b3d); }
.pos__cobrar { width: 100%; background: var(--c-leaf-700, #2f6b3d); color: #fff; border: none; border-radius: var(--r-md, 10px); padding: 13px; font-size: var(--fs-15, 15px); font-weight: 700; cursor: pointer; }
.pos__cobrar:disabled { opacity: .5; cursor: default; }
.pos__vaciar { width: 100%; background: none; border: none; color: var(--c-ink-400); font-size: var(--fs-13, 13px); cursor: pointer; margin-top: 8px; }
</style>
