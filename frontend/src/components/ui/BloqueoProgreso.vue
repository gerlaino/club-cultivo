<script setup>
// Bloqueo modal de la pantalla mientras corre un trabajo largo (generar N etiquetas QR). Tapa TODO:
// no se puede tocar nada mientras se genera, ni cambiar el filtro, ni disparar la tanda de nuevo.
// Sin esto, cambiar el filtro a mitad de la generación imprimía una hoja que no era la que pediste.
import { watch, onUnmounted } from 'vue'

const props = defineProps({
  visible: { type: Boolean, default: false },
  titulo:  { type: String,  default: 'Generando…' },
  hechas:  { type: Number,  default: 0 },
  total:   { type: Number,  default: 0 },
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
        @keydown.capture="tragarTeclas"
        @click.stop.prevent
        @contextmenu.prevent
      >
        <div class="blq__card">
          <div class="blq__spin" aria-hidden="true"></div>
          <p class="blq__tit">{{ titulo }}</p>
          <p v-if="total" class="blq__num">{{ hechas }} de {{ total }}</p>
          <div v-if="total" class="blq__bar">
            <div class="blq__bar-fill" :style="{ width: `${Math.round((hechas / total) * 100)}%` }"></div>
          </div>
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
  width: 300px; max-width: calc(100vw - 32px);
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-2);
  padding: var(--sp-6) var(--sp-5);
  background: #fff; border-radius: var(--r-xl); box-shadow: var(--sh-3);
  text-align: center; font-family: var(--font-ui);
}
.blq__spin {
  width: 34px; height: 34px; border-radius: 50%;
  border: 3px solid var(--c-leaf-100); border-top-color: var(--c-leaf-700);
  animation: blq-spin .7s linear infinite;
}
@keyframes blq-spin { to { transform: rotate(360deg); } }

.blq__tit { margin: var(--sp-2) 0 0; font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.blq__num { margin: 0; font-family: var(--font-mono); font-size: var(--fs-13); color: var(--c-ink-500); }
.blq__bar { width: 100%; height: 5px; border-radius: var(--r-pill); background: var(--c-ink-100); overflow: hidden; }
.blq__bar-fill { height: 100%; background: var(--c-leaf-700); border-radius: var(--r-pill); transition: width var(--t-fast); }
.blq__hint { margin: var(--sp-1) 0 0; font-size: var(--fs-12); color: var(--c-ink-500); line-height: var(--lh-base); }
</style>
