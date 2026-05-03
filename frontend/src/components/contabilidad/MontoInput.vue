<script setup>
import { ref, computed, watch } from 'vue'

const props = defineProps({
  modelValue: { type: Number, default: null },
  tipo: { type: String, default: 'egreso' },
  error: { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'blur'])

// El input muestra texto formateado, pero el modelo guarda el número real
const displayValue = ref('')
const inputRef = ref(null)

const colorClass = computed(() => {
  if (!props.modelValue) return 'monto--neutral'
  if (props.tipo === 'ingreso' || props.tipo === 'recupero_costo') return 'monto--ingreso'
  if (props.tipo === 'egreso') return 'monto--egreso'
  return 'monto--neutral'
})

function formatDisplay(n) {
  if (!n && n !== 0) return ''
  return new Intl.NumberFormat('es-AR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(n)
}

// Inicializar display desde modelValue
watch(() => props.modelValue, (val) => {
  // Solo actualizar si el input no está en foco
  if (document.activeElement !== inputRef.value) {
    displayValue.value = formatDisplay(val)
  }
}, { immediate: true })

// También actualizar cuando cambia el tipo (no afecta el valor, solo el color)
watch(() => props.tipo, () => {
  // No resetear el valor, solo re-renderizar el color
})

function onInput(e) {
  // Permitir solo dígitos, comas y puntos
  const raw = e.target.value
  // Limpiar: quitar todo excepto dígitos, coma y punto
  const cleaned = raw.replace(/[^\d,.]/g, '')
  // Normalizar separador decimal: última coma/punto es el decimal
  const normalized = cleaned.replace(/\./g, '').replace(',', '.')
  const num = parseFloat(normalized)
  if (!isNaN(num) && num > 0) {
    emit('update:modelValue', num)
  } else if (cleaned === '' || cleaned === '0') {
    emit('update:modelValue', null)
  }
  displayValue.value = cleaned
}

function onFocus() {
  // Al enfocar, mostrar el número limpio para editar
  if (props.modelValue) {
    displayValue.value = String(props.modelValue).replace('.', ',')
  }
}

function onBlur() {
  // Al perder el foco, formatear el número con separadores de miles
  displayValue.value = formatDisplay(props.modelValue)
  emit('blur')
}
</script>

<template>
  <div class="monto-wrap" :class="[colorClass, { 'monto-wrap--err': error }]">
    <span class="monto-prefix">$</span>
    <input
      ref="inputRef"
      class="monto-input"
      type="text"
      inputmode="decimal"
      placeholder="0"
      :value="displayValue"
      @input="onInput"
      @focus="onFocus"
      @blur="onBlur"
      autocomplete="off"
    />
  </div>
</template>

<style scoped>
.monto-wrap {
  display: flex;
  align-items: center;
  border: 2px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
  transition: border-color 150ms ease, box-shadow 150ms ease;
}
.monto-wrap:focus-within {
  box-shadow: 0 0 0 3px rgba(27, 94, 32, 0.12);
}
.monto-wrap--err {
  border-color: #ef4444;
}
.monto-wrap--err:focus-within {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.12);
}

/* Color del borde según tipo */
.monto-wrap--ingreso { border-color: #bbf7d0; }
.monto-wrap--ingreso:focus-within { border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.12); }
.monto-wrap--egreso { border-color: #fecaca; }
.monto-wrap--egreso:focus-within { border-color: #dc2626; box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.12); }
.monto-wrap--neutral { border-color: #e2e8f0; }
.monto-wrap--neutral:focus-within { border-color: #94a3b8; box-shadow: 0 0 0 3px rgba(100, 116, 139, 0.12); }

.monto-prefix {
  padding: 0 0 0 1.1rem;
  font-size: 1.3rem;
  font-weight: 700;
  font-family: var(--font-mono, 'Geist Mono', monospace);
  color: #94a3b8;
  flex-shrink: 0;
  user-select: none;
}
.monto-wrap--ingreso .monto-prefix { color: #16a34a; }
.monto-wrap--egreso  .monto-prefix { color: #dc2626; }

.monto-input {
  flex: 1;
  border: none;
  outline: none;
  background: transparent;
  padding: 0.85rem 1.1rem 0.85rem 0.4rem;
  font-size: 1.6rem;
  font-weight: 700;
  font-family: var(--font-mono, 'Geist Mono', monospace);
  color: #0f172a;
  letter-spacing: -0.03em;
  width: 100%;
  min-width: 0;
}
.monto-wrap--ingreso .monto-input { color: #16a34a; }
.monto-wrap--egreso  .monto-input { color: #dc2626; }

.monto-input::placeholder {
  color: #d1d5db;
  font-weight: 400;
}
</style>
