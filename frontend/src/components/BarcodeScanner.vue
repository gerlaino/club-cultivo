<script setup>
// Lector de código de barras por cámara (celular, tablet o webcam de escritorio).
// Usa @zxing/browser (1D EAN/UPC/Code-128 + 2D). Emite 'decoded' con el código en cada lectura
// (con anti-rebote para no repetir el mismo código en un loop) y 'close' al cerrar.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { BrowserMultiFormatReader } from '@zxing/browser'

const props = defineProps({
  titulo:   { type: String, default: 'Escaneá el código' },
  // Si true, cierra solo tras la primera lectura (modo "cargar un dato"). Si false, sigue
  // leyendo (modo POS: escanear varios productos seguidos).
  unaVez:   { type: Boolean, default: false },
})
const emit = defineEmits(['decoded', 'close'])

const video = ref(null)
const error = ref('')
let reader = null
let controls = null
let ultimo = { code: '', t: 0 }

onMounted(async () => {
  try {
    reader = new BrowserMultiFormatReader()
    controls = await reader.decodeFromConstraints(
      { video: { facingMode: 'environment' } }, // preferí la cámara trasera en el celu
      video.value,
      (result) => {
        if (!result) return
        const code = String(result.getText()).trim()
        const now = Date.now()
        // Anti-rebote: la cámara decodifica en loop; no re-emitir el mismo código en <1.5s.
        if (code === ultimo.code && now - ultimo.t < 1500) return
        ultimo = { code, t: now }
        emit('decoded', code)
        if (props.unaVez) cerrar()
      }
    )
  } catch (e) {
    error.value = e?.name === 'NotAllowedError' || e?.name === 'NotFoundError'
      ? 'No hay cámara disponible o falta permiso para usarla.'
      : 'No se pudo abrir la cámara.'
  }
})

function cerrar() {
  try { controls?.stop() } catch { /* noop */ }
  emit('close')
}
onBeforeUnmount(() => { try { controls?.stop() } catch { /* noop */ } })
</script>

<template>
  <div class="bcs" @click.self="cerrar">
    <div class="bcs__box">
      <div class="bcs__head">
        <span class="bcs__title">{{ titulo }}</span>
        <button class="bcs__x" @click="cerrar" aria-label="Cerrar">×</button>
      </div>
      <div class="bcs__viewport">
        <video ref="video" class="bcs__video" muted playsinline></video>
        <div v-if="!error" class="bcs__frame"><span></span><span></span><span></span><span></span></div>
        <div v-if="error" class="bcs__error">{{ error }}</div>
      </div>
      <p class="bcs__hint">Apuntá al código de barras del producto. Sirve con la cámara del celu, tablet o una webcam.</p>
    </div>
  </div>
</template>

<style scoped>
.bcs { position: fixed; inset: 0; background: rgb(15 23 42 / .75); backdrop-filter: blur(3px); display: grid; place-items: center; z-index: 1200; padding: 1rem; }
.bcs__box { background: var(--c-slate-900); border-radius: 16px; width: 100%; max-width: 420px; overflow: hidden; box-shadow: 0 20px 50px rgb(0 0 0 / .4); }
.bcs__head { display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; color: #fff; }
.bcs__title { font-size: .95rem; font-weight: 700; }
.bcs__x { background: none; border: none; color: var(--c-slate-300); font-size: 1.6rem; line-height: 1; cursor: pointer; padding: 0 .3rem; }
.bcs__x:hover { color: #fff; }
.bcs__viewport { position: relative; aspect-ratio: 4 / 3; background: #000; display: grid; place-items: center; }
.bcs__video { width: 100%; height: 100%; object-fit: cover; }
.bcs__frame { position: absolute; inset: 18% 12%; pointer-events: none; }
.bcs__frame span { position: absolute; width: 26px; height: 26px; border: 3px solid #22c55e; }
.bcs__frame span:nth-child(1) { top: 0; left: 0; border-right: none; border-bottom: none; }
.bcs__frame span:nth-child(2) { top: 0; right: 0; border-left: none; border-bottom: none; }
.bcs__frame span:nth-child(3) { bottom: 0; left: 0; border-right: none; border-top: none; }
.bcs__frame span:nth-child(4) { bottom: 0; right: 0; border-left: none; border-top: none; }
.bcs__error { position: absolute; inset: 0; display: grid; place-items: center; text-align: center; color: #fca5a5; font-size: .88rem; padding: 1.5rem; }
.bcs__hint { color: var(--c-slate-400); font-size: .76rem; margin: 0; padding: .8rem 1.1rem 1rem; line-height: 1.45; }
</style>
