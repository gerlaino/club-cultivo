<script setup>
import { ref, computed, onMounted } from 'vue'
import { listLotes, cargarLoteEnSala } from '../../lib/api.js'
import { useModalEscape } from '../../composables/useModalEscape.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  sala: { type: Object, required: true },
})
const emit = defineEmits(['loaded', 'close'])
useModalEscape(() => emit('close'))

// Qué estado de lote acepta cada tipo de sala
const CONFIG = {
  manicura: { estadoElegible: 'cosecha',   label: 'Cosecha',    icon: 'bi-scissors',  color: '#b45309', bg: '#fff7ed',  etiquetaOrigen: 'sala de secado'    },
}

const cfg     = computed(() => CONFIG[props.sala.kind] || null)
const lotes   = ref([])
const loading = ref(true)
const selected = ref(null)
const saving   = ref(false)
const error    = ref(null)

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  if (!cfg.value) { loading.value = false; return }
  try {
    const { data } = await listLotes({ estado: cfg.value.estadoElegible })
    // Excluir los que ya están en esta sala
    lotes.value = (data || []).filter(l => l.sala_id !== props.sala.id)
  } catch { lotes.value = [] }
  finally { loading.value = false }
})

async function confirmar() {
  if (!selected.value) return
  saving.value = true
  error.value  = null
  try {
    await cargarLoteEnSala(props.sala.id, selected.value.id)
    emit('loaded')
    emit('close')
  } catch (e) {
    error.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al cargar el lote'
  } finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div class="mcl__overlay">
      <div class="mcl__panel">

        <!-- Header -->
        <div class="mcl__header">
          <div class="mcl__header-icon" :style="{ background: cfg?.bg, color: cfg?.color }">
            <i :class="['bi', cfg?.icon || 'bi-box-arrow-in-down']"></i>
          </div>
          <div>
            <h2 class="mcl__title">Cargar lote en {{ sala.nombre }}</h2>
            <p class="mcl__sub">
              Seleccioná un lote de <strong>{{ cfg?.etiquetaOrigen }}</strong> para ingresar a esta sala
            </p>
          </div>
          <button class="mcl__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Body -->
        <div class="mcl__body">

          <div v-if="!cfg" class="mcl__empty">
            <p>Este tipo de sala no soporta carga de lotes.</p>
          </div>

          <div v-else-if="loading" class="mcl__loading">
            <DsSpinner :size="16" /> Buscando lotes en {{ cfg.label }}…
          </div>

          <template v-else>
            <div v-if="error" class="mcl__error">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
            </div>

            <div v-if="!lotes.length" class="mcl__empty">
              <i class="bi bi-inbox mcl__empty-icon"></i>
              <p>No hay lotes en estado <strong>{{ cfg.label }}</strong> disponibles para cargar.</p>
              <p class="mcl__empty-hint">Los lotes deben estar en floración antes de pasar a secado, y en cosecha antes de pasar a manicura.</p>
            </div>

            <div v-else class="mcl__list">
              <button
                v-for="lote in lotes"
                :key="lote.id"
                class="mcl__lote"
                :class="{ 'mcl__lote--selected': selected?.id === lote.id }"
                @click="selected = lote"
                type="button"
              >
                <div class="mcl__lote-check">
                  <i class="bi" :class="selected?.id === lote.id ? 'bi-check-circle-fill' : 'bi-circle'"></i>
                </div>
                <div class="mcl__lote-body">
                  <div class="mcl__lote-codigo">{{ lote.codigo }}</div>
                  <div class="mcl__lote-meta">
                    <span v-if="lote.genetica?.nombre" class="mcl__lote-genetica">
                      <i class="bi bi-flower2"></i> {{ lote.genetica.nombre }}
                    </span>
                    <span class="mcl__lote-sala">
                      <i class="bi bi-grid-3x3-gap"></i> {{ lote.sala?.nombre || 'Sin sala' }}
                    </span>
                    <span v-if="lote.plants_count" class="mcl__lote-plantas">
                      <i class="bi bi-tree"></i> {{ lote.plants_count }} plantas
                    </span>
                    <span v-if="lote.start_date" class="mcl__lote-date">
                      <i class="bi bi-calendar3"></i> Inicio {{ formatDate(lote.start_date) }}
                    </span>
                  </div>
                  <div v-if="lote.dias_desde_inicio" class="mcl__lote-dias">
                    {{ lote.dias_desde_inicio }} días en floración
                  </div>
                </div>
                <div class="mcl__lote-estado" :style="{ color: cfg.color }">
                  <span class="mcl__estado-pill" :style="{ background: cfg.bg, color: cfg.color }">
                    {{ cfg.label }}
                  </span>
                </div>
              </button>
            </div>
          </template>

        </div>

        <!-- Footer -->
        <div class="mcl__footer">
          <button class="mcl__btn-ghost" :disabled="saving" @click="$emit('close')">Cancelar</button>
          <button
            class="mcl__btn-primary"
            :disabled="!selected || saving"
            @click="confirmar"
          >
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-box-arrow-in-down"></i>
            {{ saving ? 'Cargando…' : `Cargar "${selected?.codigo || '…'}"` }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mcl__overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem;
  backdrop-filter: blur(3px);
}
.mcl__panel {
  background: #fff; border-radius: 18px;
  width: 100%; max-width: 560px; max-height: 88vh;
  display: flex; flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
}

.mcl__header {
  display: flex; align-items: flex-start; gap: .875rem;
  padding: 1.25rem 1.4rem 1rem;
  border-bottom: 1px solid #f1f5f9;
  flex-shrink: 0;
}
.mcl__header-icon {
  width: 42px; height: 42px; border-radius: 11px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; flex-shrink: 0;
}
.mcl__title { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0 0 .15rem; }
.mcl__sub   { font-size: .78rem; color: #64748b; margin: 0; }
.mcl__close {
  margin-left: auto; background: #f1f5f9; border: none;
  width: 30px; height: 30px; border-radius: 8px;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0;
}
.mcl__close:hover { background: #e2e8f0; }

.mcl__body { flex: 1; overflow-y: auto; padding: 1.1rem 1.4rem; }

.mcl__loading { display: flex; align-items: center; gap: .65rem; color: #94a3b8; font-size: .875rem; padding: 2rem 0; }

.mcl__error {
  display: flex; align-items: center; gap: .45rem;
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .65rem .875rem; border-radius: 9px; font-size: .82rem; margin-bottom: .875rem;
}

.mcl__empty { text-align: center; padding: 2.5rem 1rem; color: #94a3b8; }
.mcl__empty-icon { font-size: 2.5rem; display: block; margin-bottom: .75rem; opacity: .4; }
.mcl__empty p { font-size: .875rem; margin: 0 0 .4rem; }
.mcl__empty-hint { font-size: .78rem; color: #b0b8c8; max-width: 320px; margin: .5rem auto 0; line-height: 1.5; }

.mcl__list { display: flex; flex-direction: column; gap: .5rem; }
.mcl__lote {
  display: flex; align-items: center; gap: .875rem;
  background: #f8fafc; border: 2px solid #e2e8f0;
  border-radius: 12px; padding: .875rem 1rem;
  cursor: pointer; text-align: left; transition: all .15s; width: 100%;
}
.mcl__lote:hover { border-color: #94a3b8; background: #f1f5f9; }
.mcl__lote--selected { border-color: #1b5e20; background: #f0fdf4; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.mcl__lote-check { font-size: 1.1rem; color: #94a3b8; flex-shrink: 0; transition: color .15s; }
.mcl__lote--selected .mcl__lote-check { color: #1b5e20; }
.mcl__lote-body { flex: 1; min-width: 0; }
.mcl__lote-codigo { font-size: .95rem; font-weight: 800; color: #0f172a; margin-bottom: .3rem; font-family: monospace; letter-spacing: .02em; }
.mcl__lote-meta { display: flex; flex-wrap: wrap; gap: .3rem .75rem; font-size: .73rem; color: #64748b; margin-bottom: .2rem; }
.mcl__lote-meta span { display: flex; align-items: center; gap: .25rem; }
.mcl__lote-genetica { color: #15803d; font-weight: 600; }
.mcl__lote-dias { font-size: .72rem; color: #94a3b8; font-style: italic; }
.mcl__estado-pill { font-size: .65rem; font-weight: 800; padding: .25em .65em; border-radius: 6px; text-transform: uppercase; letter-spacing: .04em; white-space: nowrap; }

.mcl__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; flex-shrink: 0;
}
.mcl__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff;
  border: none; padding: .65rem 1.25rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s;
}
.mcl__btn-primary:hover:not(:disabled) { background: #14532d; }
.mcl__btn-primary:disabled { opacity: .45; cursor: not-allowed; }
.mcl__btn-ghost {
  background: transparent; color: #64748b;
  border: 1.5px solid #e2e8f0; padding: .65rem 1.1rem;
  border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer;
}
.mcl__btn-ghost:hover:not(:disabled) { background: #f8fafc; }
</style>
