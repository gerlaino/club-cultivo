<script setup>
import { ref, computed, watch, nextTick } from 'vue'

const props = defineProps({
  modelValue: { type: String, default: '' },
  tipo: { type: String, default: '' },
  error: { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'blur'])

const CATEGORIAS = [
  { value: 'insumo',        label: 'Insumo / Materia prima',   tipo: 'egreso'  },
  { value: 'electricidad',  label: 'Electricidad',             tipo: 'egreso'  },
  { value: 'agua',          label: 'Agua',                     tipo: 'egreso'  },
  { value: 'alquiler',      label: 'Alquiler',                 tipo: 'egreso'  },
  { value: 'sueldo',        label: 'Sueldo / Staff',           tipo: 'egreso'  },
  { value: 'mantenimiento', label: 'Mantenimiento',            tipo: 'egreso'  },
  { value: 'honorario',     label: 'Honorario profesional',    tipo: 'egreso'  },
  { value: 'seguro',        label: 'Seguro',                   tipo: 'egreso'  },
  { value: 'admin',         label: 'Gasto administrativo',     tipo: 'egreso'  },
  { value: 'aporte_socio',  label: 'Aporte socio',             tipo: 'ingreso' },
  { value: 'dispensacion',  label: 'Recupero dispensación',    tipo: 'ingreso' },
  { value: 'subvencion',    label: 'Subvención / Donación',    tipo: 'ingreso' },
  { value: 'otro',          label: 'Otro',                     tipo: 'ambos'   },
]

const CATEGORIA_EMOJI = {
  insumo: '📦', electricidad: '⚡', agua: '💧', alquiler: '🏠',
  sueldo: '👤', mantenimiento: '🔧', honorario: '📋', seguro: '🛡️',
  admin: '⚙️', aporte_socio: '🌿', dispensacion: '💊', subvencion: '🎁', otro: '📌'
}

const query = ref('')
const open  = ref(false)
const highlighted = ref(-1)
const inputRef = ref(null)
const listRef  = ref(null)

// Label para mostrar en el input cuando hay selección
const selectedLabel = computed(() => {
  const cat = CATEGORIAS.find(c => c.value === props.modelValue)
  return cat ? `${CATEGORIA_EMOJI[cat.value] || '📌'} ${cat.label}` : ''
})

const filteredOptions = computed(() => {
  // Filtrar por tipo
  let base = CATEGORIAS
  if (props.tipo === 'egreso') {
    base = CATEGORIAS.filter(c => c.tipo === 'egreso' || c.tipo === 'ambos')
  } else if (props.tipo === 'ingreso' || props.tipo === 'recupero_costo') {
    base = CATEGORIAS.filter(c => c.tipo === 'ingreso' || c.tipo === 'ambos')
  }
  // Filtrar por query
  const q = query.value.trim().toLowerCase()
  if (!q) return base
  return base.filter(c =>
    c.label.toLowerCase().includes(q) || c.value.toLowerCase().includes(q)
  )
})

// Resetear cuando cambia el tipo y la categoría actual no aplica
watch(() => props.tipo, () => {
  if (props.modelValue) {
    const cat = CATEGORIAS.find(c => c.value === props.modelValue)
    if (!cat) return
    const tipoOk =
      cat.tipo === 'ambos' ||
      (props.tipo === 'egreso' && cat.tipo === 'egreso') ||
      ((props.tipo === 'ingreso' || props.tipo === 'recupero_costo') && cat.tipo === 'ingreso')
    if (!tipoOk) emit('update:modelValue', '')
  }
})

// Mostrar el label cuando está cerrado
const displayText = computed(() => {
  if (open.value) return query.value
  return selectedLabel.value
})

function openDropdown() {
  open.value = true
  query.value = ''
  highlighted.value = -1
  nextTick(() => inputRef.value?.focus())
}

function closeDropdown() {
  open.value = false
  query.value = ''
  emit('blur')
}

function selectOption(cat) {
  emit('update:modelValue', cat.value)
  closeDropdown()
}

function clearSelection() {
  emit('update:modelValue', '')
  query.value = ''
  open.value = true
  nextTick(() => inputRef.value?.focus())
}

function onKeydown(e) {
  if (!open.value) {
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowDown') {
      e.preventDefault()
      openDropdown()
    }
    return
  }
  if (e.key === 'Escape') { e.preventDefault(); closeDropdown(); return }
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    highlighted.value = Math.min(highlighted.value + 1, filteredOptions.value.length - 1)
    scrollHighlighted()
    return
  }
  if (e.key === 'ArrowUp') {
    e.preventDefault()
    highlighted.value = Math.max(highlighted.value - 1, 0)
    scrollHighlighted()
    return
  }
  if (e.key === 'Enter') {
    e.preventDefault()
    if (highlighted.value >= 0 && filteredOptions.value[highlighted.value]) {
      selectOption(filteredOptions.value[highlighted.value])
    }
    return
  }
  if (e.key === 'Tab') {
    closeDropdown()
    return
  }
}

function onInput() {
  highlighted.value = 0
}

function scrollHighlighted() {
  nextTick(() => {
    const el = listRef.value?.querySelector('[data-highlighted]')
    el?.scrollIntoView({ block: 'nearest' })
  })
}

function onClickOutside(e) {
  if (!e.target.closest('.combo-wrap')) closeDropdown()
}

watch(open, (val) => {
  if (val) document.addEventListener('click', onClickOutside)
  else document.removeEventListener('click', onClickOutside)
})
</script>

<template>
  <div class="combo-wrap" :class="{ 'combo-wrap--open': open, 'combo-wrap--err': error }">
    <!-- Trigger cuando está cerrado y hay selección -->
    <button
      v-if="!open && modelValue"
      type="button"
      class="combo-selected"
      @click="clearSelection"
      @keydown="onKeydown"
    >
      <span class="combo-selected-text">{{ selectedLabel }}</span>
      <span class="combo-clear" title="Cambiar categoría">
        <i class="bi bi-x"></i>
      </span>
    </button>

    <!-- Input de búsqueda -->
    <div v-else class="combo-input-wrap" @click="openDropdown">
      <i class="bi bi-tag combo-icon"></i>
      <input
        ref="inputRef"
        class="combo-input"
        type="text"
        :value="open ? query : ''"
        :placeholder="open ? 'Buscar categoría…' : 'Seleccioná una categoría'"
        @input="e => { query = e.target.value; onInput() }"
        @keydown="onKeydown"
        @focus="openDropdown"
        readonly
        :class="{ 'combo-input--active': open }"
        style="cursor: pointer"
      />
      <!-- Reemplazar readonly para poder escribir cuando está abierto -->
    </div>

    <!-- Dropdown de opciones -->
    <Transition name="combo-drop">
      <ul v-if="open" ref="listRef" class="combo-list" role="listbox">
        <!-- Input de búsqueda dentro del dropdown para evitar el readonly -->
        <li class="combo-search-li">
          <div class="combo-search-wrap">
            <i class="bi bi-search combo-search-icon"></i>
            <input
              class="combo-search-input"
              type="text"
              v-model="query"
              placeholder="Buscar categoría…"
              @keydown="onKeydown"
              @input="onInput"
              ref="searchInputRef"
              autofocus
            />
          </div>
        </li>
        <li
          v-for="(cat, idx) in filteredOptions"
          :key="cat.value"
          role="option"
          class="combo-option"
          :class="{ 'combo-option--active': modelValue === cat.value, 'combo-option--highlighted': highlighted === idx }"
          :data-highlighted="highlighted === idx ? '' : undefined"
          @click.stop="selectOption(cat)"
          @mouseenter="highlighted = idx"
        >
          <span class="combo-emoji">{{ CATEGORIA_EMOJI[cat.value] || '📌' }}</span>
          <span class="combo-option-label">{{ cat.label }}</span>
          <i v-if="modelValue === cat.value" class="bi bi-check2 combo-check"></i>
        </li>
        <li v-if="filteredOptions.length === 0" class="combo-empty">
          Sin resultados para "{{ query }}"
        </li>
      </ul>
    </Transition>
  </div>
</template>

<style scoped>
.combo-wrap {
  position: relative;
  width: 100%;
}

.combo-selected {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 0.65rem 0.75rem 0.65rem 0.875rem;
  background: #f0fdf4;
  border: 1.5px solid #bbf7d0;
  border-radius: 9px;
  cursor: pointer;
  transition: border-color 150ms, background 150ms;
  font-size: 0.875rem;
  font-weight: 600;
  color: #15803d;
  text-align: left;
}
.combo-selected:hover {
  border-color: #86efac;
  background: #dcfce7;
}
.combo-wrap--err .combo-selected {
  border-color: #ef4444;
  background: #fef2f2;
  color: #dc2626;
}
.combo-selected-text { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.combo-clear {
  color: #86efac;
  font-size: 1rem;
  line-height: 1;
  flex-shrink: 0;
  display: flex;
  align-items: center;
}
.combo-selected:hover .combo-clear { color: #15803d; }

.combo-input-wrap {
  display: flex;
  align-items: center;
  border: 1.5px solid #e2e8f0;
  border-radius: 9px;
  background: #f8fafc;
  cursor: pointer;
  transition: border-color 150ms, box-shadow 150ms;
}
.combo-wrap--open .combo-input-wrap {
  border-color: #1b5e20;
  background: #fff;
  box-shadow: 0 0 0 3px rgba(27, 94, 32, 0.08);
}
.combo-wrap--err .combo-input-wrap { border-color: #ef4444; }

.combo-icon {
  padding-left: 0.75rem;
  color: #94a3b8;
  font-size: 0.875rem;
  flex-shrink: 0;
}

.combo-input {
  flex: 1;
  border: none;
  outline: none;
  background: transparent;
  padding: 0.65rem 0.875rem 0.65rem 0.5rem;
  font-size: 0.875rem;
  color: #0f172a;
  cursor: pointer;
  width: 100%;
}
.combo-input::placeholder { color: #94a3b8; }

/* Dropdown */
.combo-list {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  background: #fff;
  border: 1.5px solid #e2e8f0;
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  z-index: 200;
  list-style: none;
  margin: 0;
  padding: 4px 0;
  max-height: 280px;
  overflow-y: auto;
}

.combo-search-li { padding: 8px 8px 4px; border-bottom: 1px solid #f1f5f9; }
.combo-search-wrap {
  display: flex;
  align-items: center;
  background: #f8fafc;
  border: 1.5px solid #e2e8f0;
  border-radius: 7px;
  padding: 0 10px;
}
.combo-search-icon { color: #94a3b8; font-size: 0.8rem; flex-shrink: 0; }
.combo-search-input {
  flex: 1;
  border: none;
  outline: none;
  background: transparent;
  padding: 7px 8px;
  font-size: 0.82rem;
  color: #0f172a;
}

.combo-option {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.55rem 0.875rem;
  cursor: pointer;
  transition: background 100ms;
  font-size: 0.875rem;
  color: #374151;
}
.combo-option:hover,
.combo-option--highlighted { background: #f8fafc; }
.combo-option--active {
  background: #f0fdf4;
  color: #15803d;
  font-weight: 600;
}

.combo-emoji { font-size: 1rem; flex-shrink: 0; line-height: 1; }
.combo-option-label { flex: 1; }
.combo-check { color: #15803d; font-size: 0.9rem; flex-shrink: 0; }

.combo-empty {
  padding: 1rem;
  text-align: center;
  color: #94a3b8;
  font-size: 0.82rem;
}

/* Transición */
.combo-drop-enter-active { transition: opacity 120ms ease, transform 120ms ease; }
.combo-drop-leave-active { transition: opacity 100ms ease, transform 100ms ease; }
.combo-drop-enter-from  { opacity: 0; transform: translateY(-6px); }
.combo-drop-leave-to    { opacity: 0; transform: translateY(-4px); }
</style>
