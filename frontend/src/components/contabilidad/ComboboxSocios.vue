<script setup>
import { ref, computed, watch, nextTick } from 'vue'

const props = defineProps({
  modelValue: { type: [Number, String, null], default: null },
  pacientes: { type: Array, default: () => [] },
  error: { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'blur'])

const query = ref('')
const open  = ref(false)
const highlighted = ref(-1)
const listRef = ref(null)

const selectedPaciente = computed(() =>
  props.pacientes.find(p => p.id === props.modelValue) || null
)

const filteredPacientes = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return props.pacientes.slice(0, 30)
  return props.pacientes.filter(p =>
    p.label?.toLowerCase().includes(q) ||
    String(p.id).includes(q)
  ).slice(0, 30)
})

function avatarColor(id) {
  // Color determinístico por id
  const colors = [
    '#6366f1', '#ec4899', '#f59e0b', '#10b981',
    '#3b82f6', '#8b5cf6', '#ef4444', '#14b8a6',
  ]
  return colors[(id || 0) % colors.length]
}

function initials(label) {
  if (!label) return '?'
  // Formato: "Apellido, Nombre — DNI ..."
  const clean = label.split('—')[0].replace(',', ' ')
  const words = clean.trim().split(/\s+/).filter(Boolean)
  if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase()
  return words[0]?.[0]?.toUpperCase() || '?'
}

function openDropdown() {
  open.value = true
  query.value = ''
  highlighted.value = -1
  nextTick(() => {
    const searchEl = listRef.value?.querySelector('input')
    searchEl?.focus()
  })
}

function closeDropdown() {
  open.value = false
  query.value = ''
  emit('blur')
}

function selectPaciente(p) {
  emit('update:modelValue', p.id)
  closeDropdown()
}

function clearSelection() {
  emit('update:modelValue', null)
  query.value = ''
  openDropdown()
}

function onKeydown(e) {
  if (!open.value) {
    if (e.key === 'Enter' || e.key === 'ArrowDown') { e.preventDefault(); openDropdown() }
    return
  }
  if (e.key === 'Escape') { e.preventDefault(); closeDropdown(); return }
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    highlighted.value = Math.min(highlighted.value + 1, filteredPacientes.value.length - 1)
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
    const opt = filteredPacientes.value[highlighted.value]
    if (opt) selectPaciente(opt)
    return
  }
  if (e.key === 'Tab') { closeDropdown() }
}

function scrollHighlighted() {
  nextTick(() => {
    const el = listRef.value?.querySelector('[data-highlighted]')
    el?.scrollIntoView({ block: 'nearest' })
  })
}

function onClickOutside(e) {
  if (!e.target.closest('.combo-s-wrap')) closeDropdown()
}

watch(open, (val) => {
  if (val) document.addEventListener('click', onClickOutside)
  else document.removeEventListener('click', onClickOutside)
})
</script>

<template>
  <div class="combo-s-wrap" :class="{ 'combo-s-wrap--err': error }">

    <!-- Estado: hay selección -->
    <button
      v-if="!open && selectedPaciente"
      type="button"
      class="combo-s-selected"
      @click="clearSelection"
      @keydown="onKeydown"
    >
      <div
        class="combo-s-avatar"
        :style="{ background: avatarColor(selectedPaciente.id) }"
      >{{ initials(selectedPaciente.label) }}</div>
      <span class="combo-s-label">{{ selectedPaciente.label }}</span>
      <span class="combo-s-clear"><i class="bi bi-x"></i></span>
    </button>

    <!-- Estado: sin selección -->
    <div v-else class="combo-s-trigger" @click="openDropdown" @keydown="onKeydown" tabindex="0">
      <i class="bi bi-person combo-s-icon"></i>
      <span class="combo-s-placeholder">{{ open ? '' : 'Seleccioná el paciente' }}</span>
    </div>

    <!-- Dropdown -->
    <Transition name="combo-s-drop">
      <div v-if="open" class="combo-s-panel" ref="listRef">
        <div class="combo-s-search-wrap">
          <i class="bi bi-search combo-s-search-icon"></i>
          <input
            class="combo-s-search"
            type="text"
            v-model="query"
            placeholder="Buscar por nombre o DNI…"
            @keydown="onKeydown"
            autofocus
          />
        </div>
        <ul class="combo-s-list" role="listbox">
          <li
            v-for="(p, idx) in filteredPacientes"
            :key="p.id"
            role="option"
            class="combo-s-option"
            :class="{ 'combo-s-option--highlighted': highlighted === idx }"
            :data-highlighted="highlighted === idx ? '' : undefined"
            @click.stop="selectPaciente(p)"
            @mouseenter="highlighted = idx"
          >
            <div
              class="combo-s-avatar combo-s-avatar--sm"
              :style="{ background: avatarColor(p.id) }"
            >{{ initials(p.label) }}</div>
            <span class="combo-s-option-text">{{ p.label }}</span>
          </li>
          <li v-if="filteredPacientes.length === 0" class="combo-s-empty">
            Sin resultados{{ query ? ` para "${query}"` : '' }}
          </li>
        </ul>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.combo-s-wrap { position: relative; width: 100%; }
.combo-s-wrap--err .combo-s-trigger,
.combo-s-wrap--err .combo-s-selected { border-color: #ef4444; }

.combo-s-selected {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  width: 100%;
  padding: 0.55rem 0.75rem;
  background: #f0fdf4;
  border: 1.5px solid #bbf7d0;
  border-radius: 9px;
  cursor: pointer;
  text-align: left;
  transition: border-color 150ms, background 150ms;
}
.combo-s-selected:hover {
  border-color: #86efac;
  background: #dcfce7;
}

.combo-s-trigger {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.65rem 0.875rem;
  border: 1.5px solid var(--c-slate-200);
  border-radius: 9px;
  background: var(--c-slate-50);
  cursor: pointer;
  transition: border-color 150ms, box-shadow 150ms;
  outline: none;
}
.combo-s-trigger:hover,
.combo-s-trigger:focus { border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27, 94, 32, 0.08); background: #fff; }

.combo-s-icon { color: var(--c-slate-400); font-size: 0.875rem; }
.combo-s-placeholder { font-size: 0.875rem; color: var(--c-slate-400); }

.combo-s-avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.68rem;
  font-weight: 700;
  color: #fff;
  flex-shrink: 0;
}
.combo-s-avatar--sm { width: 26px; height: 26px; font-size: 0.62rem; }

.combo-s-label {
  flex: 1;
  font-size: 0.82rem;
  font-weight: 600;
  color: #15803d;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.combo-s-clear {
  color: #86efac;
  font-size: 1rem;
  display: flex;
  align-items: center;
  flex-shrink: 0;
}
.combo-s-selected:hover .combo-s-clear { color: #15803d; }

/* Panel dropdown */
.combo-s-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  background: #fff;
  border: 1.5px solid var(--c-slate-200);
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  z-index: 200;
  overflow: hidden;
}

.combo-s-search-wrap {
  display: flex;
  align-items: center;
  padding: 8px;
  border-bottom: 1px solid var(--c-slate-100);
  gap: 8px;
}
.combo-s-search-icon { color: var(--c-slate-400); font-size: 0.8rem; padding-left: 4px; flex-shrink: 0; }
.combo-s-search {
  flex: 1;
  border: none;
  outline: none;
  font-size: 0.82rem;
  color: var(--c-slate-900);
  background: transparent;
}

.combo-s-list {
  list-style: none;
  margin: 0;
  padding: 4px 0;
  max-height: 220px;
  overflow-y: auto;
}

.combo-s-option {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.55rem 0.875rem;
  cursor: pointer;
  transition: background 100ms;
}
.combo-s-option:hover,
.combo-s-option--highlighted { background: #f0fdf4; }

.combo-s-option-text {
  font-size: 0.82rem;
  color: var(--c-slate-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.combo-s-empty {
  padding: 1rem;
  text-align: center;
  color: var(--c-slate-400);
  font-size: 0.82rem;
}

/* Transición */
.combo-s-drop-enter-active { transition: opacity 120ms ease, transform 120ms ease; }
.combo-s-drop-leave-active { transition: opacity 100ms ease; }
.combo-s-drop-enter-from  { opacity: 0; transform: translateY(-6px); }
.combo-s-drop-leave-to    { opacity: 0; }
</style>
