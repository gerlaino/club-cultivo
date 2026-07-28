<script setup>
// Bloqueo modal de la pantalla mientras corre un trabajo largo (generar N etiquetas QR). Tapa TODO:
// no se puede tocar nada mientras genera, ni cambiar el filtro, ni disparar la tanda de nuevo.
// Sin esto, cambiar el filtro a mitad de la generación imprimía una hoja que no era la pedida.
//
// El progreso es REAL, no un spinner decorativo: con 800 plantas la diferencia entre "algo gira" y
// "vas 612 de 800, 76%" es saber si hay que esperar o si se colgó. El anillo se llena con el
// porcentaje y el logo va adentro. Si no hay total conocido, el anillo gira (indeterminado).
import { computed, watch, onUnmounted } from 'vue'

const props = defineProps({
  visible: { type: Boolean, default: false },
  titulo:  { type: String,  default: 'Generando…' },
  hechas:  { type: Number,  default: 0 },
  total:   { type: Number,  default: 0 },
  logo:    { type: String,  default: '/logo-ce-icono.png' },
})

const determinado = computed(() => props.total > 0)
const pct = computed(() => {
  if (!determinado.value) return 0
  return Math.min(100, Math.round((props.hechas / props.total) * 100))
})

// El scroll del fondo también se bloquea: si no, el overlay tapa pero la página se sigue moviendo.
watch(() => props.visible, (v) => { document.body.style.overflow = v ? 'hidden' : '' })
onUnmounted(() => { document.body.style.overflow = '' })

// Traga cualquier tecla mientras bloquea (incluido Escape: el trabajo no se puede cancelar a mitad).
function tragarTeclas(e) {
  if (!props.visible) return
  e.stopPropagation()
  e.preventDefault()
}
</script>

<template>
  <Teleport to="body">
    <Transition name="blq-fade">
      <div
        v-if="visible"
        class="blq"
        role="alertdialog"
        aria-live="polite"
        aria-busy="true"
        :aria-valuenow="determinado ? pct : undefined"
        @keydown.capture="tragarTeclas"
        @click.stop.prevent
        @contextmenu.prevent
      >
        <div class="blq__card">
          <div
            class="blq__ring"
            :class="{ 'blq__ring--spin': !determinado }"
            :style="determinado ? { '--pct': pct } : null"
          >
            <div class="blq__hole">
              <img :src="logo" class="blq__logo" alt="" aria-hidden="true" />
            </div>
          </div>

          <p v-if="determinado" class="blq__pct">{{ pct }}<span>%</span></p>
          <p class="blq__tit">{{ titulo }}</p>
          <p v-if="determinado" class="blq__num">{{ hechas }} de {{ total }}</p>
          <p class="blq__hint">No cierres ni toques la pantalla hasta que termine.</p>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.blq {
  position: fixed; inset: 0; z-index: 2000;
  display: flex; align-items: center; justify-content: center;
  background: rgb(15 20 17 / .55); backdrop-filter: blur(2px);
  cursor: progress;
}
.blq-fade-enter-active, .blq-fade-leave-active { transition: opacity var(--t-base); }
.blq-fade-enter-from, .blq-fade-leave-to { opacity: 0; }

.blq__card {
  width: 288px; max-width: calc(100vw - 32px);
  display: flex; flex-direction: column; align-items: center;
  padding: var(--sp-6) var(--sp-5);
  background: #fff; border-radius: var(--r-xl); box-shadow: var(--sh-3);
  text-align: center; font-family: var(--font-ui);
}

/* Anillo de progreso: el relleno es el porcentaje real, no una animación. */
.blq__ring {
  --pct: 0;
  width: 86px; height: 86px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  background: conic-gradient(var(--c-leaf-600) calc(var(--pct) * 1%), var(--c-ink-100) 0);
  transition: background var(--t-fast);
}
.blq__ring--spin {
  background: conic-gradient(var(--c-ink-100) 0 65%, var(--c-leaf-600) 65% 100%);
  animation: blq-spin .8s linear infinite;
}
@keyframes blq-spin { to { transform: rotate(360deg); } }

.blq__hole {
  width: 68px; height: 68px; border-radius: 50%; background: #fff;
  display: flex; align-items: center; justify-content: center;
}
.blq__logo { width: 40px; height: 40px; object-fit: contain; animation: blq-pulse 1.8s ease-in-out infinite; }
@keyframes blq-pulse { 0%, 100% { opacity: .75; } 50% { opacity: 1; } }

.blq__pct {
  margin: var(--sp-3) 0 0;
  font-family: var(--font-mono); font-size: var(--fs-32); font-weight: 700;
  line-height: 1; color: var(--c-ink-900); letter-spacing: -.02em;
}
.blq__pct span { font-size: var(--fs-16); color: var(--c-ink-500); margin-left: 2px; }

.blq__tit  { margin: var(--sp-2) 0 0; font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.blq__num  { margin: 2px 0 0; font-family: var(--font-mono); font-size: var(--fs-13); color: var(--c-ink-500); }
.blq__hint { margin: var(--sp-3) 0 0; font-size: var(--fs-12); color: var(--c-ink-500); line-height: var(--lh-base); }

@media (prefers-reduced-motion: reduce) {
  .blq__logo, .blq__ring--spin { animation: none; }
}
</style>
