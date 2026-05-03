<template>
  <div class="adp">
    <input
      type="text"
      readonly
      :value="displayValue"
      placeholder="DD/MM/AAAA"
      :class="['adp__display', inputClass]"
    />
    <!-- Overlay transparente que dispara el picker nativo al clickear -->
    <input
      ref="nativeRef"
      type="date"
      :value="modelValue"
      :min="min"
      :max="max"
      class="adp__native"
      @change="$emit('update:modelValue', $event.target.value)"
    />
    <span class="adp__ico"><i class="bi bi-calendar3"></i></span>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'

const props = defineProps({
  modelValue: { type: String, default: '' },
  min:        { type: String, default: '' },
  max:        { type: String, default: '' },
  inputClass: { type: [String, Object, Array], default: '' },
})
defineEmits(['update:modelValue'])

const nativeRef = ref(null)

const displayValue = computed(() => {
  if (!props.modelValue) return ''
  const [y, m, d] = props.modelValue.split('-')
  if (!y || !m || !d) return ''
  return `${d}/${m}/${y}`
})
</script>

<style scoped>
.adp {
  position: relative; display: flex; align-items: center; width: 100%;
}
.adp__display {
  width: 100%; box-sizing: border-box; cursor: pointer;
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px;
  padding: .65rem .9rem; font-size: .875rem; color: #1a1a1a; outline: none;
}
.adp__display::placeholder { color: #94a3b8; }
/* El input nativo cubre exactamente el componente, invisible pero clickeable */
.adp__native {
  position: absolute; top: 0; left: 0;
  width: 100%; height: 100%;
  opacity: 0; cursor: pointer;
  border: none; background: transparent;
  z-index: 1;
}
.adp__ico {
  position: absolute; right: .75rem; pointer-events: none;
  color: #94a3b8; font-size: .85rem; top: 50%; transform: translateY(-50%);
  z-index: 2;
}
</style>
