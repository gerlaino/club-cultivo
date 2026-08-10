<template>
  <div class="adp" :class="{ 'adp--disabled': disabled }">
    <input
      ref="textEl"
      type="text"
      inputmode="numeric"
      :value="display"
      :placeholder="placeholder"
      :disabled="disabled"
      :class="['adp__input', inputClass]"
      maxlength="10"
      @input="onInput"
      @blur="onBlur"
    />
    <button
      type="button"
      class="adp__btn"
      :disabled="disabled"
      tabindex="-1"
      aria-label="Abrir calendario"
      @click="openPicker"
    >
      <i class="bi bi-calendar3"></i>
    </button>
    <!-- input nativo oculto: solo para el picker visual (su valor siempre es ISO) -->
    <input
      ref="dateEl"
      type="date"
      class="adp__native"
      :value="modelValue || ''"
      :min="min"
      :max="max"
      :disabled="disabled"
      tabindex="-1"
      @input="onNative"
    />
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'

const props = defineProps({
  modelValue: { type: String, default: '' },          // ISO yyyy-mm-dd
  min:        { type: String, default: '' },
  max:        { type: String, default: '' },
  placeholder:{ type: String, default: 'dd/mm/aaaa' },
  disabled:   { type: Boolean, default: false },
  inputClass: { type: [String, Object, Array], default: '' },
})
const emit = defineEmits(['update:modelValue'])

const textEl = ref(null)
const dateEl = ref(null)
const buffer = ref(isoToDisplay(props.modelValue))

watch(() => props.modelValue, (v) => {
  const d = isoToDisplay(v)
  if (d !== buffer.value) buffer.value = d
})

const display = computed(() => buffer.value)

function isoToDisplay(iso) {
  if (!iso) return ''
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso)
  return m ? `${m[3]}/${m[2]}/${m[1]}` : ''
}

function displayToIso(s) {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec((s || '').trim())
  if (!m) return null
  const [, dd, mm, yyyy] = m
  const day = +dd, mon = +mm
  if (mon < 1 || mon > 12 || day < 1 || day > 31) return null
  const iso = `${yyyy}-${mm}-${dd}`
  const dt = new Date(iso + 'T00:00:00')
  if (isNaN(dt.getTime()) || dt.getDate() !== day || dt.getMonth() + 1 !== mon) return null
  return iso
}

function onInput(e) {
  const digits = e.target.value.replace(/\D/g, '').slice(0, 8)
  let out = digits.slice(0, 2)
  if (digits.length >= 3) out += '/' + digits.slice(2, 4)
  if (digits.length >= 5) out += '/' + digits.slice(4, 8)
  buffer.value = out
  if (out === '') { emit('update:modelValue', ''); return }
  const iso = displayToIso(out)
  if (iso) emit('update:modelValue', iso)
}

function onBlur() {
  // Si quedó incompleta/ inválida, la limpiamos para no dejar basura
  if (buffer.value !== '' && !displayToIso(buffer.value)) {
    buffer.value = isoToDisplay(props.modelValue)
  }
}

function onNative(e) {
  const iso = e.target.value
  buffer.value = isoToDisplay(iso)
  emit('update:modelValue', iso)
}

function openPicker() {
  const el = dateEl.value
  if (!el) return
  if (typeof el.showPicker === 'function') {
    try { el.showPicker(); return } catch (_) { /* fallback */ }
  }
  el.click()
}
</script>

<style scoped>
.adp { position: relative; display: flex; align-items: center; width: 100%; }
.adp__input {
  width: 100%; box-sizing: border-box;
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px;
  padding: .65rem 2.2rem .65rem .9rem;
  font-size: .875rem; color: #1a1a1a; outline: none;
  font-family: inherit;
}
.adp__input:focus { border-color: #4ade80; box-shadow: 0 0 0 3px rgba(74,222,128,.15); }
.adp__btn {
  position: absolute; right: .4rem; top: 50%; transform: translateY(-50%);
  background: none; border: none; cursor: pointer;
  color: var(--c-slate-400); font-size: .9rem; padding: .25rem .35rem; line-height: 1;
}
.adp__btn:hover:not(:disabled) { color: #1b5e20; }
.adp__btn:disabled { cursor: not-allowed; }
.adp--disabled .adp__input { opacity: .6; cursor: not-allowed; }
/* nativo oculto pero anclado al botón para que el picker aparezca cerca */
.adp__native {
  position: absolute; right: .5rem; bottom: 0;
  width: 1px; height: 1px; opacity: 0; pointer-events: none; border: 0; padding: 0;
}
</style>
