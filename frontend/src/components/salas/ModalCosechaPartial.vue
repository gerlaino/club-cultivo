<template>
  <Teleport to="body">
    <div class="mcp-overlay">
      <div class="mcp-panel">

        <div class="mcp-header">
          <div class="mcp-header-left">
            <span class="mcp-header-emoji">🌿</span>
            <div>
              <h2 class="mcp-title">Cosechar lote</h2>
              <p class="mcp-sub">{{ lote.codigo }}<span v-if="paso === 2"> · corte {{ pasada }}</span></p>
            </div>
          </div>
          <button class="mcp-close" @click="$emit('cerrar')"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mcp-body">

          <!-- Sin plantas -->
          <div v-if="!plantasEnFloracion.length" class="mcp-empty">
            No hay plantas en floración en este lote. No hay nada para cosechar.
          </div>

          <!-- ── PASO 1 — Total o parcial ── -->
          <template v-else-if="paso === 1">
            <p class="mcp-paso-hint">{{ plantasEnFloracion.length }} plantas en floración. ¿Qué querés cosechar?</p>
            <div class="mcp-choices">
              <button type="button" class="mcp-choice" @click="elegir('total')">
                <span class="mcp-choice-ico">🌾</span>
                <span class="mcp-choice-tit">Cosechar todo el lote</span>
                <span class="mcp-choice-sub">Las {{ plantasEnFloracion.length }} plantas en floración</span>
              </button>
              <button type="button" class="mcp-choice" @click="elegir('parcial')">
                <span class="mcp-choice-ico">✂️</span>
                <span class="mcp-choice-tit">Cosechar algunas plantas</span>
                <span class="mcp-choice-sub">Elegís cuáles (cosecha escalonada)</span>
              </button>
            </div>
          </template>

          <!-- ── PASO 2 — Detalle ── -->
          <template v-else>
            <button class="mcp-back" type="button" @click="volverPaso1">← Cambiar</button>

            <!-- Selección de plantas (solo parcial) -->
            <div v-if="modo === 'parcial'" class="mcp-field">
              <label class="mcp-label">
                Plantas a cosechar
                <span class="mcp-hint">{{ seleccionadas.size }} de {{ plantasEnFloracion.length }}</span>
              </label>
              <button class="mcp-sel-all" type="button" @click="toggleAll">
                {{ seleccionadas.size === plantasEnFloracion.length ? 'Deseleccionar todo' : 'Seleccionar todo' }}
              </button>
              <div class="mcp-plantas-grid">
                <button
                  v-for="p in plantasEnFloracion"
                  :key="p.id"
                  type="button"
                  class="mcp-planta"
                  :class="{ 'mcp-planta--sel': seleccionadas.has(p.id) }"
                  @click="toggle(p.id)"
                >
                  <span class="mcp-planta-ico">{{ seleccionadas.has(p.id) ? '✅' : '🌸' }}</span>
                  <span class="mcp-planta-nombre">{{ p.nombre }}</span>
                </button>
              </div>
            </div>

            <!-- Peso húmedo -->
            <div class="mcp-field">
              <label class="mcp-label">Peso húmedo total <span class="mcp-opt">opcional</span></label>
              <div class="mcp-input-wrap">
                <input v-model.number="pesoHumedo" type="number" min="0" step="0.1" class="mcp-input" placeholder="0" />
                <span class="mcp-unit">g</span>
              </div>
              <span class="mcp-help">Podés completarlo más tarde al pesar.</span>
            </div>

            <!-- Identificador de corte -->
            <div class="mcp-field">
              <label class="mcp-label">
                Identificar corte
                <span class="mcp-help-ico" title="Si cosechás el lote en varias tandas (cosecha escalonada), cada tanda es un 'corte'. Sirve para diferenciar pesadas y trazar cada parte por separado.">
                  <i class="bi bi-question-circle"></i>
                </span>
              </label>
              <div class="mcp-pasadas">
                <button
                  v-for="letra in ['A','B','C','D','E']"
                  :key="letra"
                  type="button"
                  class="mcp-pasada-btn"
                  :class="{ 'mcp-pasada-btn--active': pasada === letra, 'mcp-pasada-btn--usada': pasadasUsadas.includes(letra) }"
                  @click="pasada = letra"
                >
                  {{ letra }}
                  <span v-if="pasadasUsadas.includes(letra)" class="mcp-pasada-tag">✓</span>
                </button>
              </div>
            </div>

            <!-- Destino automático (info, no input) -->
            <div class="mcp-destino">
              <i class="bi bi-arrow-right-circle"></i>
              <span>Al cosechar, el lote pasa a <strong>Cosechado</strong> y queda pendiente de asignar a manicura. Lo ves desde la sección Cosechado.</span>
            </div>

            <!-- Resumen -->
            <div v-if="seleccionadas.size > 0" class="mcp-resumen">
              <span class="mcp-resumen-ico">📋</span>
              <span>
                <strong>{{ seleccionadas.size }} planta{{ seleccionadas.size !== 1 ? 's' : '' }}</strong>
                se cosechan en el corte <strong>{{ pasada }}</strong>
                <span v-if="pesoHumedo"> · {{ pesoHumedo }}g húmedo</span>
              </span>
            </div>

            <div v-if="error" class="mcp-error">{{ error }}</div>
          </template>
        </div>

        <div class="mcp-footer">
          <button class="mcp-btn-cancel" type="button" @click="$emit('cerrar')">Cancelar</button>
          <button
            v-if="paso === 2"
            class="mcp-btn-submit"
            type="button"
            :disabled="!seleccionadas.size || guardando"
            @click="guardar"
          >
            <DsSpinner v-if="guardando" :size="14" />
            <span v-else>🌿 Cosechar {{ seleccionadas.size || '' }} planta{{ seleccionadas.size !== 1 ? 's' : '' }}</span>
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { cosecharPlantas } from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  lote:          { type: Object, required: true },
  plantas:       { type: Array,  default: () => [] },
  pasadasUsadas: { type: Array,  default: () => [] },
  pasadaInicial: { type: String, default: 'A' },
})
const emit = defineEmits(['cosechado', 'cerrar'])

const paso          = ref(1)
const modo          = ref(null)   // 'total' | 'parcial'
const seleccionadas = ref(new Set())
const pesoHumedo    = ref(null)
const pasada        = ref(props.pasadaInicial)
const guardando     = ref(false)
const error         = ref('')

const plantasEnFloracion = computed(() => props.plantas.filter(p => p.state === 'floracion'))

function elegir(m) {
  modo.value = m
  if (m === 'total') {
    seleccionadas.value = new Set(plantasEnFloracion.value.map(p => p.id))
  } else {
    seleccionadas.value = new Set()
  }
  paso.value = 2
}

function volverPaso1() {
  paso.value = 1
  modo.value = null
  seleccionadas.value = new Set()
  error.value = ''
}

function toggle(id) {
  const s = new Set(seleccionadas.value)
  s.has(id) ? s.delete(id) : s.add(id)
  seleccionadas.value = s
}

function toggleAll() {
  if (seleccionadas.value.size === plantasEnFloracion.value.length) {
    seleccionadas.value = new Set()
  } else {
    seleccionadas.value = new Set(plantasEnFloracion.value.map(p => p.id))
  }
}

async function guardar() {
  if (!seleccionadas.value.size) return
  guardando.value = true
  error.value = ''
  try {
    const { data } = await cosecharPlantas(props.lote.id, {
      plantas_ids:  Array.from(seleccionadas.value),
      peso_total_g: pesoHumedo.value || null,
      pasada:       pasada.value,
    })
    emit('cosechado', data)
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al registrar la cosecha'
  } finally {
    guardando.value = false
  }
}

function escapeHandler(e) {
  if (e.key === 'Escape') emit('cerrar')
}
onMounted(() => document.addEventListener('keydown', escapeHandler, true))
onUnmounted(() => document.removeEventListener('keydown', escapeHandler, true))
</script>

<style scoped>
.mcp-overlay {
  position: fixed; inset: 0; z-index: 1200;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  padding: 16px;
}
.mcp-panel {
  background: var(--c-paper, #fff);
  border-radius: 20px;
  width: 100%; max-width: 520px;
  max-height: 90vh; overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,.22);
  display: flex; flex-direction: column;
}
.mcp-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 20px 24px 16px;
  border-bottom: 1px solid var(--c-ink-100, #f1f5f1);
}
.mcp-header-left { display: flex; align-items: center; gap: 12px; }
.mcp-header-emoji { font-size: 24px; }
.mcp-title { font-size: 1.05rem; font-weight: 700; color: var(--c-ink-900, #111); margin: 0; }
.mcp-sub { font-size: .78rem; color: var(--c-ink-500, #64748b); margin: 2px 0 0; font-family: monospace; }
.mcp-close { background: none; border: none; cursor: pointer; color: var(--c-ink-400, #94a3b8); font-size: 1rem; padding: 4px; }

.mcp-body { padding: 20px 24px; display: flex; flex-direction: column; gap: 18px; flex: 1; }

.mcp-paso-hint { font-size: .85rem; color: #64748b; margin: 0; }

/* Choices paso 1 */
.mcp-choices { display: flex; flex-direction: column; gap: 12px; }
.mcp-choice {
  display: flex; flex-direction: column; align-items: flex-start; gap: 2px;
  padding: 16px 18px; border: 1.5px solid var(--c-ink-200, #e2e8f0);
  border-radius: 14px; background: #f8fafc; cursor: pointer;
  transition: border-color .15s, background .15s; text-align: left;
}
.mcp-choice:hover { border-color: #16a34a; background: #f0fdf4; }
.mcp-choice-ico { font-size: 22px; }
.mcp-choice-tit { font-size: .92rem; font-weight: 700; color: #15803d; }
.mcp-choice-sub { font-size: .78rem; color: #64748b; }

.mcp-back {
  align-self: flex-start; background: none; border: none; padding: 0;
  color: #1b5e20; font-size: .8rem; font-weight: 600; cursor: pointer;
}
.mcp-back:hover { text-decoration: underline; }

.mcp-field { display: flex; flex-direction: column; gap: 8px; }
.mcp-label {
  font-size: .82rem; font-weight: 600; color: var(--c-ink-700, #374151);
  display: flex; align-items: center; gap: 8px;
}
.mcp-hint { font-size: .75rem; color: var(--c-ink-400, #94a3b8); font-weight: 400; }
.mcp-opt  { font-size: .72rem; color: var(--c-ink-400, #94a3b8); font-weight: 400; }
.mcp-help { font-size: .72rem; color: #94a3b8; }
.mcp-help-ico { color: #94a3b8; cursor: help; font-size: .8rem; }

.mcp-empty {
  padding: 12px 16px; background: #f1f5f9; border-radius: 10px;
  font-size: .82rem; color: #64748b;
}

.mcp-sel-all {
  align-self: flex-start; font-size: .75rem; color: #1b5e20; background: none;
  border: none; cursor: pointer; padding: 0; text-decoration: underline; font-weight: 600;
}
.mcp-plantas-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 8px; max-height: 240px; overflow-y: auto;
  border: 1.5px solid var(--c-ink-200, #e2e8f0); border-radius: 12px; padding: 10px;
}
.mcp-planta {
  display: flex; flex-direction: column; align-items: center; gap: 4px;
  padding: 8px 6px; border: 1.5px solid var(--c-ink-200, #e2e8f0);
  border-radius: 10px; cursor: pointer; background: #f8fafc;
  transition: border-color .15s, background .15s; font-size: .72rem; color: #374151;
}
.mcp-planta--sel { border-color: #16a34a; background: #dcfce7; }
.mcp-planta-ico { font-size: 16px; }
.mcp-planta-nombre { font-family: monospace; font-size: .7rem; word-break: break-all; text-align: center; }

.mcp-input-wrap { display: flex; align-items: center; gap: 8px; }
.mcp-input {
  flex: 1; padding: .6rem .9rem; border: 1.5px solid var(--c-ink-200, #e2e8f0);
  border-radius: 10px; font-size: .875rem; outline: none; background: #f8fafc;
}
.mcp-input:focus { border-color: #4ade80; }
.mcp-unit { font-size: .82rem; color: #64748b; font-weight: 600; }

.mcp-pasadas { display: flex; gap: 8px; flex-wrap: wrap; }
.mcp-pasada-btn {
  padding: 6px 16px; border-radius: 999px; border: 1.5px solid var(--c-ink-200, #e2e8f0);
  background: #f8fafc; font-size: .82rem; font-weight: 700; cursor: pointer;
  color: #374151; transition: all .15s; display: flex; align-items: center; gap: 4px;
}
.mcp-pasada-btn--active { border-color: #16a34a; background: #dcfce7; color: #15803d; }
.mcp-pasada-btn--usada { opacity: .6; }
.mcp-pasada-tag { font-size: .65rem; color: #16a34a; }

.mcp-destino {
  display: flex; align-items: flex-start; gap: 8px; padding: 10px 14px;
  background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 10px;
  font-size: .78rem; color: #1e40af;
}
.mcp-destino i { margin-top: 1px; }

.mcp-resumen {
  display: flex; align-items: flex-start; gap: 10px; padding: 12px 16px;
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 12px;
  font-size: .82rem; color: #15803d;
}
.mcp-resumen-ico { font-size: 18px; flex-shrink: 0; }
.mcp-error {
  padding: 10px 14px; background: #fef2f2; border: 1px solid #fecaca;
  border-radius: 10px; font-size: .82rem; color: #dc2626;
}

.mcp-footer { display: flex; gap: 10px; padding: 16px 24px; border-top: 1px solid var(--c-ink-100, #f1f5f1); }
.mcp-btn-cancel {
  flex: 1; padding: .65rem; border: 1.5px solid var(--c-ink-200, #e2e8f0);
  border-radius: 12px; background: none; cursor: pointer; font-size: .875rem;
  color: #64748b; font-weight: 500;
}
.mcp-btn-submit {
  flex: 2; padding: .65rem; border-radius: 12px; border: none; cursor: pointer;
  background: #15803d; color: #fff; font-size: .875rem; font-weight: 700; transition: background .15s;
}
.mcp-btn-submit:hover:not(:disabled) { background: #166534; }
.mcp-btn-submit:disabled { opacity: .5; cursor: not-allowed; }
</style>
