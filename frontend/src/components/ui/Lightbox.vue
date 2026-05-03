<script setup>
import { onMounted, onUnmounted, watch } from 'vue'

const props = defineProps({
  images: { type: Array, required: true },  // Array<{ src, alt? }>
  index:  { type: Number, default: 0 },
  open:   { type: Boolean, default: false },
})
const emit = defineEmits(['close', 'update:index'])

function prev() {
  emit('update:index', (props.index - 1 + props.images.length) % props.images.length)
}
function next() {
  emit('update:index', (props.index + 1) % props.images.length)
}
function close() { emit('close') }

function onKey(e) {
  if (!props.open) return
  if (e.key === 'Escape')     close()
  if (e.key === 'ArrowLeft')  prev()
  if (e.key === 'ArrowRight') next()
}

// Lock scroll when open
watch(() => props.open, (v) => {
  document.body.style.overflow = v ? 'hidden' : ''
})

onMounted(()  => document.addEventListener('keydown', onKey))
onUnmounted(() => {
  document.removeEventListener('keydown', onKey)
  document.body.style.overflow = ''
})
</script>

<template>
  <Teleport to="body">
    <Transition name="lb">
      <div
        v-if="open && images.length"
        class="lb"
        role="dialog"
        aria-modal="true"
        aria-label="Galería de fotos"
        @click.self="close"
      >
        <button class="lb__close" @click="close" aria-label="Cerrar">
          <i class="bi bi-x-lg"></i>
        </button>

        <button
          v-if="images.length > 1"
          class="lb__nav lb__nav--prev"
          @click="prev"
          aria-label="Foto anterior"
        >
          <i class="bi bi-chevron-left"></i>
        </button>

        <div class="lb__img-wrap">
          <img
            :src="images[index]?.src"
            :alt="images[index]?.alt || ''"
            class="lb__img"
          />
          <div v-if="images.length > 1" class="lb__counter" aria-live="polite">
            {{ index + 1 }} / {{ images.length }}
          </div>
        </div>

        <button
          v-if="images.length > 1"
          class="lb__nav lb__nav--next"
          @click="next"
          aria-label="Foto siguiente"
        >
          <i class="bi bi-chevron-right"></i>
        </button>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.lb {
  position: fixed; inset: 0; z-index: 9999;
  background: rgba(0,0,0,.93);
  display: flex; align-items: center; justify-content: center;
}
.lb__close {
  position: absolute; top: 1rem; right: 1rem;
  background: rgba(255,255,255,.15); border: none; color: white;
  width: 40px; height: 40px; border-radius: 50%; font-size: 1rem;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: background .15s;
  z-index: 1;
}
.lb__close:hover { background: rgba(255,255,255,.3); }
.lb__nav {
  position: absolute; top: 50%; transform: translateY(-50%);
  background: rgba(255,255,255,.15); border: none; color: white;
  width: 44px; height: 44px; border-radius: 50%; font-size: 1.1rem;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: background .15s; z-index: 1;
}
.lb__nav:hover { background: rgba(255,255,255,.3); }
.lb__nav--prev { left: 1rem; }
.lb__nav--next { right: 1rem; }
.lb__img-wrap  { max-width: min(90vw, 900px); max-height: 80vh; position: relative; }
.lb__img       { max-width: 100%; max-height: 80vh; border-radius: .5rem; object-fit: contain; display: block; }
.lb__counter   {
  position: absolute; bottom: -1.75rem; left: 50%; transform: translateX(-50%);
  color: rgba(255,255,255,.6); font-size: .8rem; white-space: nowrap;
}

.lb-enter-active, .lb-leave-active { transition: opacity .15s ease; }
.lb-enter-from,   .lb-leave-to     { opacity: 0; }
</style>
