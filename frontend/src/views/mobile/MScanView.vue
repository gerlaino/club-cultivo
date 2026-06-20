<template>
  <div class="msc">
    <video ref="videoEl" class="msc__video" playsinline muted></video>

    <!-- Overlay -->
    <div class="msc__overlay">
      <header class="msc__top">
        <button class="msc__close" @click="salir" aria-label="Cerrar"><i class="bi bi-x-lg"></i></button>
        <span class="msc__title">Escanear QR</span>
        <button class="msc__close" @click="toggleTorch" v-if="hasTorch" aria-label="Linterna">
          <i class="bi" :class="torchOn ? 'bi-lightning-charge-fill' : 'bi-lightning-charge'"></i>
        </button>
        <span v-else style="width:38px"></span>
      </header>

      <div class="msc__frame-wrap">
        <div class="msc__frame">
          <span class="msc__corner msc__corner--tl"></span>
          <span class="msc__corner msc__corner--tr"></span>
          <span class="msc__corner msc__corner--bl"></span>
          <span class="msc__corner msc__corner--br"></span>
        </div>
        <p class="msc__hint">{{ estado === 'error' ? mensaje : 'Apuntá al código QR de la planta, lote o stock' }}</p>
      </div>

      <footer class="msc__bottom">
        <button class="msc__manual-toggle" @click="manualOpen = !manualOpen">
          <i class="bi bi-keyboard"></i> Ingresar código a mano
        </button>
        <form v-if="manualOpen" class="msc__manual" @submit.prevent="irManual">
          <input v-model.trim="codigoManual" class="msc__input" placeholder="Código del QR" autocomplete="off" />
          <button class="msc__go" type="submit" :disabled="!codigoManual"><i class="bi bi-arrow-right"></i></button>
        </form>
      </footer>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import QrScanner from 'qr-scanner'

const router = useRouter()
const videoEl = ref(null)
const estado  = ref('cargando') // cargando | activo | error
const mensaje = ref('')
const manualOpen = ref(false)
const codigoManual = ref('')
const hasTorch = ref(false)
const torchOn  = ref(false)

let scanner = null
let navegado = false

// Prefijos QR válidos → ruta interna de la SPA.
const PREFIJOS = ['/p/', '/l/', '/s/', '/g/', '/c/']

function resolverDestino(texto) {
  let path = texto
  try { path = new URL(texto).pathname } catch { /* no era URL: puede ser solo el código */ }
  if (PREFIJOS.some(p => path.startsWith(p))) return path
  // Si vino un código pelado, lo tratamos como planta por defecto.
  if (!path.includes('/')) return `/p/${path}`
  return null
}

function navegarA(texto) {
  if (navegado) return
  const destino = resolverDestino(texto)
  if (!destino) { mensaje.value = 'QR no reconocido'; estado.value = 'error'; return }
  navegado = true
  detener()
  router.push(destino)
}

function irManual() {
  if (codigoManual.value) navegarA(codigoManual.value)
}

async function toggleTorch() {
  if (!scanner) return
  try { await scanner.toggleFlash(); torchOn.value = !torchOn.value } catch {}
}

function detener() {
  try { scanner?.stop(); scanner?.destroy() } catch {}
  scanner = null
}

function salir() { detener(); router.back() }

onMounted(async () => {
  try {
    if (!(await QrScanner.hasCamera())) throw new Error('Sin cámara disponible')
    scanner = new QrScanner(videoEl.value, (result) => navegarA(result.data || result), {
      highlightScanRegion: false,
      highlightCodeOutline: false,
      preferredCamera: 'environment',
      maxScansPerSecond: 5,
    })
    await scanner.start()
    estado.value = 'activo'
    hasTorch.value = await scanner.hasFlash()
  } catch (e) {
    estado.value = 'error'
    mensaje.value = 'No se pudo acceder a la cámara. Permití el acceso o ingresá el código a mano.'
    manualOpen.value = true
  }
})

onBeforeUnmount(detener)
</script>

<style scoped>
.msc { position: fixed; inset: 0; z-index: 1300; background: #000; }
.msc__video { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.msc__overlay {
  position: absolute; inset: 0;
  display: flex; flex-direction: column;
  background: linear-gradient(180deg, rgba(0,0,0,.55) 0%, transparent 30%, transparent 60%, rgba(0,0,0,.65) 100%);
}
.msc__top {
  display: flex; align-items: center; justify-content: space-between;
  padding: .7rem .9rem; padding-top: calc(.7rem + env(safe-area-inset-top));
}
.msc__title { color: #fff; font-weight: 700; font-size: 1rem; }
.msc__close {
  width: 38px; height: 38px; border-radius: 11px;
  background: rgba(255,255,255,.15); border: none; color: #fff;
  display: flex; align-items: center; justify-content: center; font-size: 1.1rem;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}

.msc__frame-wrap { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1.2rem; }
.msc__frame { position: relative; width: 66vw; max-width: 280px; aspect-ratio: 1; }
.msc__corner { position: absolute; width: 30px; height: 30px; border: 3px solid #4ade80; }
.msc__corner--tl { top: 0; left: 0; border-right: none; border-bottom: none; border-radius: 10px 0 0 0; }
.msc__corner--tr { top: 0; right: 0; border-left: none; border-bottom: none; border-radius: 0 10px 0 0; }
.msc__corner--bl { bottom: 0; left: 0; border-right: none; border-top: none; border-radius: 0 0 0 10px; }
.msc__corner--br { bottom: 0; right: 0; border-left: none; border-top: none; border-radius: 0 0 10px 0; }
.msc__hint { color: rgba(255,255,255,.85); font-size: .85rem; text-align: center; max-width: 75%; margin: 0; }

.msc__bottom { padding: 1rem .9rem; padding-bottom: calc(1.2rem + env(safe-area-inset-bottom)); }
.msc__manual-toggle {
  width: 100%; padding: .7rem; border-radius: 12px;
  background: rgba(255,255,255,.14); border: none; color: #fff;
  font-size: .85rem; font-weight: 600; cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: .5rem;
  -webkit-tap-highlight-color: transparent;
}
.msc__manual { display: flex; gap: .5rem; margin-top: .6rem; }
.msc__input {
  flex: 1; padding: .7rem .9rem; border-radius: 12px; border: none;
  font-size: .9rem; background: #fff; color: #1a1d1f;
}
.msc__go {
  width: 48px; border-radius: 12px; border: none;
  background: #2D7D46; color: #fff; font-size: 1.1rem; cursor: pointer;
}
.msc__go:disabled { opacity: .5; }
</style>
