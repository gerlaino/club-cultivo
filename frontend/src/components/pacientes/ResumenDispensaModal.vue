<template>
  <Teleport to="body">
    <!-- No se cierra tocando afuera: es donde se cuenta plata (regla de la app). -->
    <div v-if="abierto" v-modal="() => $emit('elegir', 'volver')" class="rdm__overlay" role="dialog" aria-modal="true" aria-labelledby="rdm-titulo">
      <div class="rdm">
        <header class="rdm__head">
          <h3 id="rdm-titulo" class="rdm__titulo">Confirmá la dispensa</h3>
          <p class="rdm__pac">{{ resumen.paciente }}</p>
        </header>

        <div class="rdm__body">
          <ul class="rdm__items">
            <li v-for="(it, i) in resumen.productos" :key="i">
              <span class="rdm__prod">
                <strong>{{ it.cantidad }}</strong> {{ it.forma }}
                <small v-if="it.genetica">{{ it.genetica }}</small>
              </span>
              <span class="rdm__monto">{{ fmt(it.subtotal) }}</span>
            </li>
          </ul>

          <dl class="rdm__cuentas">
            <template v-if="resumen.ajuste">
              <dt>Ajuste manual</dt><dd>{{ resumen.ajuste < 0 ? '−' : '+' }} {{ fmt(Math.abs(resumen.ajuste)) }}</dd>
            </template>
            <template v-if="resumen.envio !== null">
              <dt>Envío</dt><dd>{{ resumen.envio === 0 ? 'Bonificado' : fmt(resumen.envio) }}</dd>
            </template>
            <dt class="rdm__total">Total</dt><dd class="rdm__total">{{ resumen.especial || fmt(resumen.total) }}</dd>
          </dl>

          <div v-if="resumen.pagos.length" class="rdm__pagos">
            <p class="rdm__sub">Cómo paga</p>
            <dl class="rdm__cuentas">
              <template v-for="(p, i) in resumen.pagos" :key="i">
                <dt :class="{ 'rdm__destacado': p.destacado }">{{ p.label }}</dt>
                <dd :class="{ 'rdm__destacado': p.destacado }">{{ fmt(p.monto) }}</dd>
              </template>
            </dl>
          </div>

          <p v-if="resumen.envioA" class="rdm__nota">Va por delivery a {{ resumen.envioA }}.</p>
        </div>

        <footer class="rdm__pie">
          <button type="button" class="rdm__btn rdm__btn--volver" @click="$emit('elegir', 'volver')">Volver</button>
          <button type="button" class="rdm__btn rdm__btn--linea" @click="$emit('elegir', 'imprimir')">
            <i class="bi bi-printer"></i> Confirmar e imprimir etiqueta
          </button>
          <button type="button" class="rdm__btn rdm__btn--ok" @click="$emit('elegir', 'confirmar')">Confirmar</button>
        </footer>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
// EL ÚLTIMO PASO ANTES DE DISPENSAR (Germán, 6-oct-2026): lo que se lleva, cuánto sale y cómo lo
// paga —qué va a la cuenta corriente, qué queda a favor—, para mirarlo con el paciente enfrente
// antes de que se mueva stock y plata. «Confirmar e imprimir etiqueta» crea la dispensa e imprime
// la etiqueta del paquete (la de siempre, `useEtiquetaDispensa`: necesita la dispensa creada,
// porque el QR es su pasaporte).
defineProps({
  abierto: { type: Boolean, default: false },
  // { paciente, productos: [{ cantidad, forma, genetica, subtotal }], ajuste, envio (null = sin
  //   envío), envioA, total, especial (texto en lugar del total: regalo / cambio),
  //   pagos: [{ label, monto, destacado }] }
  resumen: { type: Object, required: true },
})
defineEmits(['elegir'])

const fmt = n => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(n || 0)
</script>

<style scoped>
.rdm__overlay { position: fixed; inset: 0; z-index: 1100; display: flex; align-items: center; justify-content: center; padding: 1rem; background: rgba(15, 23, 42, .5); backdrop-filter: blur(2px); }
.rdm { width: 100%; max-width: 540px; max-height: calc(100vh - 2rem); display: flex; flex-direction: column; background: var(--c-paper); border-radius: 16px; box-shadow: 0 24px 60px -20px rgba(15, 23, 42, .45); overflow: hidden; }
.rdm__head { padding: 1.1rem 1.25rem .6rem; border-bottom: 1px solid var(--c-slate-100); }
.rdm__titulo { margin: 0; font-size: 1.05rem; font-weight: 800; color: var(--c-ink-950); }
.rdm__pac { margin: .15rem 0 0; font-size: .9rem; color: var(--c-slate-500); }
.rdm__body { padding: .9rem 1.25rem; overflow-y: auto; display: flex; flex-direction: column; gap: .9rem; }
.rdm__items { list-style: none; margin: 0; padding: 0; display: grid; gap: .45rem; }
.rdm__items li { display: flex; justify-content: space-between; gap: .75rem; font-size: .9rem; color: var(--c-ink-950); }
.rdm__prod small { display: block; font-size: .78rem; color: var(--c-slate-500); }
.rdm__monto { font-variant-numeric: tabular-nums; white-space: nowrap; }
.rdm__cuentas { margin: 0; display: grid; grid-template-columns: 1fr auto; gap: .3rem .75rem; font-size: .88rem; }
.rdm__cuentas dt { color: var(--c-slate-600); }
.rdm__cuentas dd { margin: 0; text-align: right; font-variant-numeric: tabular-nums; color: var(--c-ink-950); }
.rdm__total { padding-top: .45rem; border-top: 1px dashed var(--c-slate-200); font-weight: 800; font-size: 1rem; color: var(--c-ink-950) !important; }
.rdm__pagos { padding: .7rem .85rem; border-radius: 10px; background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100); }
.rdm__sub { margin: 0 0 .4rem; font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-leaf-800); }
.rdm__destacado { font-weight: 700; color: var(--c-amber-500) !important; }
.rdm__nota { margin: 0; font-size: .82rem; color: var(--c-slate-500); }
.rdm__pie { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: .5rem; padding: .85rem 1.25rem 1rem; border-top: 1px solid var(--c-slate-100); }
.rdm__btn { min-height: 40px; padding: 0 1rem; border-radius: 10px; font-weight: 700; font-size: .86rem; cursor: pointer; display: inline-flex; align-items: center; gap: .4rem; }
.rdm__btn--volver { margin-right: auto; border: none; background: transparent; color: var(--c-slate-500); }
.rdm__btn--linea { border: 1.5px solid var(--c-leaf-800); background: transparent; color: var(--c-leaf-800); }
.rdm__btn--ok { border: none; background: var(--c-leaf-800); color: var(--c-paper); }
@media (max-width: 480px) { .rdm__btn { flex: 1 1 100%; justify-content: center; } .rdm__btn--volver { margin-right: 0; order: 3; } }
</style>
