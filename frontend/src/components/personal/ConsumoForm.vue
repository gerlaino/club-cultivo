<template>
  <!-- Cuánto sacaste del frasco. Teléfono (hoja) y escritorio (modal) usan el mismo. -->
  <form class="cf" @submit.prevent="$emit('guardar')">
    <p class="cf__hint">Quedan <b>{{ fmt(c.stock.cantidad) }} {{ c.stock.unidad || 'g' }}</b>.</p>
    <label class="cf__field">
      <span class="cf__label">Cuánto</span>
      <span class="cf__input-row">
        <input v-model.number="c.cantidad" type="number" inputmode="decimal" step="0.1" min="0.1"
               :max="c.stock.cantidad" class="cf__input cf__input--num" placeholder="0" autofocus />
        <span class="cf__input-u">{{ c.stock.unidad || 'g' }}</span>
      </span>
    </label>
    <label class="cf__field">
      <span class="cf__label">Cuándo</span>
      <input v-model="c.fecha" type="date" class="cf__input" :max="hoy" />
    </label>
    <label class="cf__field">
      <span class="cf__label">Nota <span class="cf__opt">(opcional)</span></span>
      <input v-model.trim="c.nota" type="text" class="cf__input" placeholder="Para dormir, con amigos…" maxlength="120" />
    </label>
    <p v-if="c.error" class="cf__error">{{ c.error }}</p>
    <p v-if="c.cantidad > 0" class="cf__resumen">
      Salen {{ fmt(c.cantidad) }} {{ c.stock.unidad || 'g' }}; quedan {{ fmt(Math.max(0, c.stock.cantidad - c.cantidad)) }}.
    </p>
    <div class="cf__actions">
      <button type="button" class="cf__btn cf__btn--ghost" @click="$emit('cancelar')">Cancelar</button>
      <button type="submit" class="cf__btn cf__btn--primary" :disabled="!(c.cantidad > 0) || c.guardando">
        {{ c.guardando ? 'Guardando…' : 'Anotar' }}
      </button>
    </div>
  </form>
</template>

<script setup>
import { fmt } from '../../composables/useFrascosPersonal.js'

const props = defineProps({
  consumo: { type: Object, required: true },
  hoy:     { type: String, required: true },
})
defineEmits(['guardar', 'cancelar'])
// El estado ES el del composable (un `reactive` prestado por el padre): se escribe acá a propósito.
const c = props.consumo
</script>

<style scoped>
.cf { display: flex; flex-direction: column; gap: .8rem; padding-bottom: .5rem; }
.cf__hint { margin: 0; font-size: .85rem; color: var(--c-slate-600); }
.cf__field { display: flex; flex-direction: column; gap: .3rem; }
.cf__label { font-size: .76rem; font-weight: 700; color: var(--c-slate-600); text-transform: uppercase; letter-spacing: .04em; }
.cf__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.cf__input { width: 100%; padding: .7rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; font: inherit; font-size: 1rem; background: #fff; }
.cf__input:focus { outline: none; border-color: var(--c-leaf-500, #5A8A72); }
.cf__input-row { display: flex; align-items: center; gap: .5rem; }
.cf__input--num { font-size: 1.6rem; font-weight: 700; text-align: right; }
.cf__input-u { font-size: 1rem; font-weight: 600; color: var(--c-slate-500); }
.cf__error { margin: 0; font-size: .82rem; color: #b91c1c; }
.cf__resumen { margin: 0; font-size: .85rem; color: var(--c-slate-700); }
.cf__actions { display: flex; gap: .5rem; }
.cf__btn { flex: 1; padding: .8rem; border-radius: 12px; font-size: .95rem; font-weight: 700; border: none; cursor: pointer; }
.cf__btn--ghost { background: var(--c-slate-100); color: var(--c-slate-700); }
.cf__btn--primary { background: var(--c-leaf-800, #1A3D2E); color: #fff; }
.cf__btn--primary:disabled { opacity: .5; }
</style>
