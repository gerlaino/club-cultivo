<script setup>
// Comprobante de venta del bar — NO válido como factura. Ticket imprimible (ancho tipo térmica),
// con el detalle de lo vendido. Imprime con window.print(): el @media print (no scoped) deja
// visible solo el ticket y oculta el resto de la app.
import { computed } from 'vue'

const props = defineProps({
  ticket: { type: Object, required: true }, // { nro, items:[{nombre,cantidad,precio}], total, medio, fecha }
  bar:    { type: String, default: 'Buffet' },
  club:   { type: String, default: '' },
  logo:   { type: String, default: '' },
})
const emit = defineEmits(['close'])

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const MEDIO_LABEL = { efectivo: 'Efectivo', transferencia: 'Transferencia', mercado_pago: 'QR / Mercado Pago', regalo: 'Regalo' }
const fechaTxt = computed(() => {
  const d = props.ticket.fecha instanceof Date ? props.ticket.fecha : new Date(props.ticket.fecha)
  return d.toLocaleDateString('es-AR') + ' ' + d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
})
function imprimir() { window.print() }
</script>

<template>
  <div class="tk-ov tk-noprint-bg" @click.self="emit('close')">
    <div class="tk-wrap">
      <!-- Ticket (lo único que se imprime) -->
      <div class="tk-print-area">
        <div class="tk">
          <img v-if="logo" :src="logo" class="tk__logo" alt="" />
          <div class="tk__club">{{ club || bar }}</div>
          <div class="tk__bar">🍸 {{ bar }}</div>
          <div class="tk__meta">{{ fechaTxt }}<span v-if="ticket.nro"> · Nº {{ ticket.nro }}</span></div>

          <div class="tk__sep"></div>

          <div v-for="(it, i) in ticket.items" :key="i" class="tk__line">
            <div class="tk__line-top">
              <span class="tk__q">{{ it.cantidad }}×</span>
              <span class="tk__n">{{ it.nombre }}</span>
              <span class="tk__s">{{ fmt(it.precio * it.cantidad) }}</span>
            </div>
            <div class="tk__line-unit">{{ fmt(it.precio) }} c/u</div>
          </div>

          <div class="tk__sep"></div>

          <div class="tk__total">
            <span>TOTAL</span><span>{{ fmt(ticket.total) }}</span>
          </div>
          <div class="tk__medio">{{ MEDIO_LABEL[ticket.medio] || ticket.medio }}</div>

          <div class="tk__sep tk__sep--dot"></div>
          <div class="tk__legal">COMPROBANTE NO VÁLIDO COMO FACTURA</div>
          <div class="tk__thanks">¡Gracias! 🌿</div>
        </div>
      </div>

      <!-- Acciones (no se imprimen) -->
      <div class="tk-actions tk-noprint">
        <button class="tk-btn" @click="emit('close')">Cerrar</button>
        <button class="tk-btn tk-btn--primary" @click="imprimir">🖨️ Imprimir</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tk-ov { position: fixed; inset: 0; background: rgb(15 23 42 / .55); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1200; padding: 1rem; }
.tk-wrap { display: flex; flex-direction: column; gap: .75rem; align-items: center; }
.tk-print-area { background: #fff; border-radius: 10px; box-shadow: 0 20px 50px rgb(15 23 42 / .3); }
.tk { width: 280px; padding: 1.1rem 1.1rem 1.3rem; font-family: 'Courier New', monospace; color: #111; }
.tk__logo { display: block; max-height: 46px; margin: 0 auto .5rem; }
.tk__club { text-align: center; font-weight: 800; font-size: 1rem; letter-spacing: .02em; }
.tk__bar { text-align: center; font-size: .82rem; margin-top: .1rem; }
.tk__meta { text-align: center; font-size: .72rem; color: #444; margin-top: .3rem; }
.tk__sep { border-top: 1px dashed #333; margin: .7rem 0; }
.tk__sep--dot { border-top-style: dotted; }
.tk__line { margin-bottom: .5rem; }
.tk__line-top { display: flex; gap: .4rem; font-size: .82rem; }
.tk__q { font-weight: 700; }
.tk__n { flex: 1; }
.tk__s { font-weight: 700; font-variant-numeric: tabular-nums; }
.tk__line-unit { font-size: .68rem; color: #666; padding-left: 1.6rem; }
.tk__total { display: flex; justify-content: space-between; font-size: 1.05rem; font-weight: 800; letter-spacing: .02em; }
.tk__medio { text-align: right; font-size: .75rem; color: #444; margin-top: .15rem; }
.tk__legal { text-align: center; font-size: .68rem; font-weight: 700; letter-spacing: .04em; color: #111; }
.tk__thanks { text-align: center; font-size: .78rem; margin-top: .4rem; }

.tk-actions { display: flex; gap: .5rem; }
.tk-btn { background: #fff; color: var(--c-slate-700); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem 1.1rem; font-size: .88rem; font-weight: 650; cursor: pointer; }
.tk-btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.tk-btn--primary:hover { background: #144a18; }
</style>

<style>
/* NO scoped: al imprimir, dejamos visible solo el ticket y ocultamos el resto de la app. */
@media print {
  body { visibility: hidden !important; }
  .tk-print-area, .tk-print-area * { visibility: visible !important; }
  .tk-print-area { position: absolute; left: 0; top: 0; box-shadow: none !important; border-radius: 0 !important; }
  .tk-ov { background: none !important; backdrop-filter: none !important; padding: 0 !important; }
  .tk-noprint { display: none !important; }
}
</style>
