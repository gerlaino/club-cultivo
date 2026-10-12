<template>
  <!-- CÓMO CRECIÓ: las fotos de una planta pasando una tras otra (11-oct-2026). Con una sola foto
       no hay nada que ver pasar, así que no se dibuja. Debajo, el día de vida y la fase de ese día:
       es lo que hace que una secuencia de fotos se lea como un crecimiento. -->
  <section v-if="fotos.length > 1" class="ldf">
    <header class="ldf__cab">
      <h2 class="ldf__t">Cómo creció</h2>
      <span class="ldf__n">{{ i + 1 }} de {{ fotos.length }}</span>
    </header>
    <div class="ldf__marco">
      <img :src="actual.url" :alt="`Día ${actual.dia ?? ''}`" class="ldf__img" />
    </div>
    <p class="ldf__pie">
      <strong>{{ actual.dia ? `Día ${actual.dia}` : fechaCorta(actual.fecha) }}</strong>
      <span v-if="actual.fase_label"> · {{ actual.fase_label }}</span>
      <span> · {{ fechaCorta(actual.fecha) }}</span>
      <span v-if="actual.de_todas" class="ldf__todas">foto del espacio</span>
    </p>
    <p v-if="actual.nota" class="ldf__nota">{{ actual.nota }}</p>
    <div class="ldf__controles">
      <button type="button" class="ldf__play" :aria-label="reproduciendo ? 'Pausar' : 'Ver pasar'" @click="alternar">
        <i class="bi" :class="reproduciendo ? 'bi-pause-fill' : 'bi-play-fill'" aria-hidden="true"></i>
      </button>
      <input v-model.number="i" type="range" min="0" :max="fotos.length - 1" step="1" class="ldf__barra" aria-label="Foto" @input="pausar" />
    </div>
  </section>
</template>

<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { getLineaFotosPlanta } from '../../lib/api'

const props = defineProps({ plantId: { type: [Number, String], required: true } })

const fotos = ref([])
const i = ref(0)
const reproduciendo = ref(false)
let timer = null

async function cargar() {
  try { fotos.value = (await getLineaFotosPlanta(props.plantId)).data || [] } catch { fotos.value = [] }
  i.value = Math.max(0, fotos.value.length - 1)
}
watch(() => props.plantId, cargar, { immediate: true })

const actual = computed(() => fotos.value[i.value] || {})
const fechaCorta = (iso) => (iso ? new Date(`${iso}T12:00:00`).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : '')

function pausar() { reproduciendo.value = false; clearInterval(timer) }
function alternar() {
  if (reproduciendo.value) return pausar()
  if (i.value >= fotos.value.length - 1) i.value = 0
  reproduciendo.value = true
  timer = setInterval(() => {
    if (i.value >= fotos.value.length - 1) return pausar()
    i.value++
  }, 900)
}
onUnmounted(pausar)
// La próxima foto se pide antes de que toque, para que no parpadee al pasar.
watch(i, (n) => { const sig = fotos.value[n + 1]; if (sig) new Image().src = sig.url })
</script>

<style scoped>
.ldf { display: flex; flex-direction: column; gap: var(--sp-2); padding: var(--sp-4); border: 1px solid var(--c-leaf-100); border-radius: 14px; background: var(--c-paper); }
.ldf__cab { display: flex; align-items: baseline; justify-content: space-between; }
.ldf__t { margin: 0; font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); }
.ldf__n { font-size: var(--fs-12); color: var(--c-ink-700); }
.ldf__marco { border-radius: 10px; overflow: hidden; background: var(--c-leaf-50); aspect-ratio: 4 / 3; display: flex; align-items: center; justify-content: center; }
.ldf__img { width: 100%; height: 100%; object-fit: contain; }
.ldf__pie { margin: 0; font-size: var(--fs-14); color: var(--c-ink-700); display: flex; flex-wrap: wrap; align-items: center; gap: 4px; }
.ldf__pie strong { color: var(--c-ink-900); }
.ldf__todas { margin-left: auto; font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 999px; background: var(--c-leaf-100); color: var(--c-leaf-800); }
.ldf__nota { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); font-style: italic; }
.ldf__controles { display: flex; align-items: center; gap: var(--sp-3); }
.ldf__play { width: 40px; height: 40px; flex-shrink: 0; border: 0; border-radius: 50%; background: var(--c-leaf-800); color: var(--c-paper); font-size: 1.2rem; display: flex; align-items: center; justify-content: center; cursor: pointer; }
.ldf__barra { flex: 1; accent-color: var(--c-leaf-800); }
</style>
