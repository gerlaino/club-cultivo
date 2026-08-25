<template>
  <div class="msc">
    <video ref="videoEl" class="msc__video" playsinline muted></video>

    <div v-modal="salir" class="msc__overlay">
      <header class="msc__top">
        <button class="msc__icon" @click="salir" aria-label="Cerrar"><i class="bi bi-x-lg"></i></button>
        <span class="msc__title">Escanear QR</span>
        <button v-if="hasTorch" class="msc__icon" @click="toggleTorch" aria-label="Linterna">
          <i class="bi" :class="torchOn ? 'bi-lightning-charge-fill' : 'bi-lightning-charge'"></i>
        </button>
        <span v-else class="msc__icon msc__icon--ghost"></span>
      </header>

      <div class="msc__window-wrap">
        <div class="msc__window">
          <span class="msc__corner msc__corner--tl"></span>
          <span class="msc__corner msc__corner--tr"></span>
          <span class="msc__corner msc__corner--bl"></span>
          <span class="msc__corner msc__corner--br"></span>
          <div v-if="estado === 'activo'" class="msc__scanline"></div>
        </div>
        <p class="msc__hint">{{ estado === 'error' ? mensaje : 'Centrá el QR dentro del recuadro' }}</p>

        <!-- Con un QR que no es de la app, el cartel quedaba solo y sin salida: la cámara seguía
             encendida y no había cómo volver. -->
        <div v-if="estado === 'error'" class="msc__recovery">
          <button class="msc__btn msc__btn--ghost" @click="reintentar">
            <i class="bi bi-arrow-clockwise"></i> Reintentar
          </button>
          <button class="msc__btn" @click="irAlInicio">
            <i class="bi bi-house"></i> Volver al inicio
          </button>
        </div>
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
import { useAuthStore } from '../../stores/auth'
import QrScanner from 'qr-scanner'

const router = useRouter()
const videoEl = ref(null)
const estado  = ref('cargando')
const mensaje = ref('')
const manualOpen = ref(false)
const codigoManual = ref('')
const hasTorch = ref(false)
const torchOn  = ref(false)

let scanner = null
let navegado = false

const PREFIJOS = ['/p/', '/l/', '/s/', '/g/', '/c/']

function resolverDestino(texto) {
  let path = texto
  try { path = new URL(texto).pathname } catch { /* puede ser solo el código */ }
  if (PREFIJOS.some(p => path.startsWith(p))) return path
  if (!path.includes('/')) return `/p/${path}`
  return null
}

function navegarA(texto) {
  if (navegado) return
  const destino = resolverDestino(texto)
  if (!destino) { mensaje.value = 'QR no reconocido'; estado.value = 'error'; return }
  navegado = true
  detener()

  // Un CARNET escaneado desde el mostrador no lleva a la página pública del carnet: lleva al
  // paciente, listo para dispensarle. La página pública es para el socio, no para quien atiende.
  const carnet = destino.match(/^\/c\/(.+)$/)
  if (carnet && useAuthStore().user?.role === 'dispensador') {
    router.replace(`/m/dispensar?carnet=${encodeURIComponent(carnet[1])}`)
    return
  }
  router.push(destino)
}

function irManual() { if (codigoManual.value) navegarA(codigoManual.value) }

async function toggleTorch() {
  if (!scanner) return
  try { await scanner.toggleFlash(); torchOn.value = !torchOn.value } catch {}
}

function detener() {
  try { scanner?.stop(); scanner?.destroy() } catch {}
  scanner = null
}
// `router.back()` no sirve si se entró directo (tab "Escanear", link, PWA recién abierta): no hay
// atrás y la pantalla queda trabada. Se cae al home del rol.
function salir() {
  detener()
  if (window.history.length > 1) router.back()
  else irAlInicio()
}

const HOME_POR_ROL = {
  admin: '/m/admin/home', supervisor: '/m/admin/home', cultivador: '/m/cultivador/sedes',
  manicura: '/m/manicura/pesar', delivery: '/m/delivery/despachos', dispensador: '/m/dispensar',
}
function irAlInicio() {
  detener()
  router.replace(HOME_POR_ROL[useAuthStore().user?.role] || '/')
}

function reintentar() {
  mensaje.value = ''
  estado.value  = 'activo'
  navegado      = false
}

onMounted(async () => {
  try {
    if (!(await QrScanner.hasCamera())) throw new Error('no-camera')
    scanner = new QrScanner(videoEl.value, (r) => navegarA(r.data || r), {
      highlightScanRegion: false,
      highlightCodeOutline: false,
      preferredCamera: 'environment',
      maxScansPerSecond: 8,
      // Región de escaneo = el recuadro central (~62% del lado menor), centrada.
      calculateScanRegion: (v) => {
        const lado = Math.round(Math.min(v.videoWidth, v.videoHeight) * 0.62)
        return {
          x: Math.round((v.videoWidth - lado) / 2),
          y: Math.round((v.videoHeight - lado) / 2),
          width: lado, height: lado,
          downScaledWidth: 400, downScaledHeight: 400,
        }
      },
    })
    await scanner.start()
    estado.value = 'activo'
    hasTorch.value = await scanner.hasFlash()
  } catch (e) {
    estado.value = 'error'
    mensaje.value = 'No se pudo acceder a la cámara. Ingresá el código a mano.'
    manualOpen.value = true
  }
})

onBeforeUnmount(detener)
</script>

<style scoped>
.msc { position: fixed; inset: 0; z-index: 1300; background: #000; overflow: hidden; }
.msc__video { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }

.msc__overlay { position: absolute; inset: 0; display: flex; flex-direction: column; }
.msc__top {
  display: flex; align-items: center; justify-content: space-between;
  padding: .7rem .9rem; padding-top: calc(.7rem + env(safe-area-inset-top));
}
.msc__title { color: #fff; font-weight: 700; font-size: 1rem; }
.msc__icon {
  width: 38px; height: 38px; border-radius: 11px;
  background: rgba(255,255,255,.15); border: none; color: #fff;
  display: flex; align-items: center; justify-content: center; font-size: 1.05rem;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}
.msc__icon--ghost { background: transparent; }

.msc__window-wrap { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1.4rem; }
.msc__window {
  position: relative; width: 260px; height: 260px;
  border-radius: 16px;
  /* Oscurece todo alrededor de la ventana (robusto y bien soportado) */
  box-shadow: 0 0 0 100vmax rgba(0,0,0,.6);
}
.msc__corner { position: absolute; width: 26px; height: 26px; border: 3px solid #4ade80; }
.msc__corner--tl { top: 0; left: 0; border-right: none; border-bottom: none; border-radius: 12px 0 0 0; }
.msc__corner--tr { top: 0; right: 0; border-left: none; border-bottom: none; border-radius: 0 12px 0 0; }
.msc__corner--bl { bottom: 0; left: 0; border-right: none; border-top: none; border-radius: 0 0 0 12px; }
.msc__corner--br { bottom: 0; right: 0; border-left: none; border-top: none; border-radius: 0 0 12px 0; }
.msc__scanline {
  position: absolute; left: 8px; right: 8px; top: 8px; height: 2px;
  background: linear-gradient(90deg, transparent, #4ade80, transparent);
  border-radius: 2px;
  animation: scan 2.2s ease-in-out infinite;
}
@keyframes scan { 0%,100% { transform: translateY(0); } 50% { transform: translateY(236px); } }
.msc__hint { color: rgba(255,255,255,.9); font-size: .85rem; text-align: center; max-width: 78%; margin: 0; }

.msc__bottom { padding: 1rem .9rem; padding-bottom: calc(1.2rem + env(safe-area-inset-bottom)); }
.msc__manual-toggle {
  width: 100%; padding: .7rem; border-radius: 12px;
  background: rgba(255,255,255,.14); border: none; color: #fff;
  font-size: .85rem; font-weight: 600; cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: .5rem;
  -webkit-tap-highlight-color: transparent;
}
.msc__manual { display: flex; gap: .5rem; margin-top: .6rem; }
.msc__input { flex: 1; padding: .7rem .9rem; border-radius: 12px; border: none; font-size: .9rem; background: #fff; color: #1a1d1f; }
.msc__go { width: 48px; border-radius: 12px; border: none; background: #2D7D46; color: #fff; font-size: 1.1rem; cursor: pointer; }
.msc__go:disabled { opacity: .5; }
</style>

<style scoped>
.msc__recovery { display: flex; gap: .5rem; justify-content: center; margin-top: .75rem; }
.msc__btn {
  border: none; border-radius: 10px; padding: .6rem 1rem; cursor: pointer;
  background: #fff; color: var(--c-slate-900); font-size: .85rem; font-weight: 600;
  display: inline-flex; align-items: center; gap: .4rem;
}
.msc__btn--ghost { background: rgba(255,255,255,.15); color: #fff; }
</style>
