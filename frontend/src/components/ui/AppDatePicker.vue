<template>
  <div class="adp">
    <input
      type="date"
      :value="modelValue"
      :min="min"
      :max="max"
      :class="['adp__input', inputClass]"
      @change="$emit('update:modelValue', $event.target.value)"
    />
    <span class="adp__ico"><i class="bi bi-calendar3"></i></span>
  </div>
</template>

<script setup>
defineProps({
  modelValue: { type: String, default: '' },
  min:        { type: String, default: '' },
  max:        { type: String, default: '' },
  inputClass: { type: [String, Object, Array], default: '' },
})
defineEmits(['update:modelValue'])
</script>

<style scoped>
.adp {
  position: relative; display: flex; align-items: center; width: 100%;
}
.adp__input {
  width: 100%; box-sizing: border-box; cursor: pointer;
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px;
  padding: .65rem 2.2rem .65rem .9rem;
  font-size: .875rem; color: #1a1a1a; outline: none;
  font-family: inherit;
  appearance: none; -webkit-appearance: none;
}
.adp__input:focus { border-color: #4ade80; box-shadow: 0 0 0 3px rgba(74,222,128,.15); }
.adp__input::-webkit-calendar-picker-indicator { opacity: 0; position: absolute; right: 0; width: 2.5rem; height: 100%; cursor: pointer; }
.adp__ico {
  position: absolute; right: .75rem; pointer-events: none;
  color: #94a3b8; font-size: .85rem; top: 50%; transform: translateY(-50%);
}
</style>
