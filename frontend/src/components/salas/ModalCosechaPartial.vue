<template>
  <Teleport to="body">
    <div class="mcp-overlay" @click.self="$emit('cerrar')">
      <div class="mcp-panel">

        <div class="mcp-header">
          <div class="mcp-header-left">
            <span class="mcp-header-emoji">🌿</span>
            <div>
              <h2 class="mcp-title">Registrar cosecha</h2>
              <p class="mcp-sub">{{ lote.codigo }} · Pasada {{ pasadaLabel }}</p>
            </div>
          </div>
          <button class="mcp-close" @click="$emit('cerrar')"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mcp-body">

          <!-- Plantas en floración -->
          <div class="mcp-field">
            <label class="mcp-label">
              Plantas a cosechar
              <span class="mcp-hint">{{ plantasEnFloracion.length }} disponibles en floración</span>
            </label>

            <div v-if="!plantasEnFloracion.length" class="mcp-empty">
              No hay plantas en floración. Podés avanzar el lote directamente.
            </div>

            <div v-else class="mcp-plantas">
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
          </div>

          <!-- Peso húmedo total -->
          <div class="mcp-field">
            <label class="mcp-label">
              Peso húmedo total <span class="mcp-opt">opcional</span>
            </label>
            <div class="mcp-input-wrap">
              <input
                v-model.number="pesoHumedo"
                type="number"
                min="0"
                step="0.1"
                class="mcp-input"
                placeholder="0"
              />
              <span class="mcp-unit">g</span>
            </div>
          </div>

          <!-- Nombre de pasada -->
          <div class="mcp-field">
            <label class="mcp-label">Identificador de pasada</label>
            <div class="mcp-pasadas">
              <button
                v-for="letra in ['A','B','C','D','E']"
                :key="letra"
                type="button"
                class="mcp-pasada-btn"
                :class="{
                  'mcp-pasada-btn--active': pasada === letra,
                  'mcp-pasada-btn--usada': pasadasUsadas.includes(letra)
                }"
                @click="pasada = letra"
              >
                {{ letra }}
                <span v-if="pasadasUsadas.includes(letra)" class="mcp-pasada-tag">✓</span>
              </button>
            </div>
          </div>

          <!-- Sala destino -->
          <div class="mcp-field" v-if="salas.length > 0">
            <label class="mcp-label">
              Sala destino
              <span v-if="salas.length === 1" class="mcp-hint">auto-seleccionada</span>
            </label>
            <div v-if="salas.length === 1" class="mcp-sala-unica">
              <i class="bi bi-house-door"></i> {{ salas[0].nombre }}
            </div>
            <select v-else v-model="salaDestinoId" class="mcp-input">
              <option :value="null">— Sin mover (quedar en sala actual) —</option>
              <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
          </div>

          <!-- Resumen -->
          <div v-if="seleccionadas.size > 0" class="mcp-resumen">
            <span class="mcp-resumen-ico">📋</span>
            <span>
              <strong>{{ seleccionadas.size }} plantas</strong> se marcarán como cosechadas en pasada
              <strong>{{ pasada }}</strong>
              <span v-if="pesoHumedo"> · {{ pesoHumedo }}g húmedo</span>
            </span>
          </div>

          <div v-if="error" class="mcp-error">{{ error }}</div>
        </div>

        <div class="mcp-footer">
          <button class="mcp-btn-cancel" type="button" @click="$emit('cerrar')">Cancelar</button>
          <button
            class="mcp-btn-submit"
            type="button"
            :disabled="!seleccionadas.size || guardando"
            @click="guardar"
          >
            <span v-if="guardando" class="mcp-spinner"></span>
            <span v-else>🌿 Cosechar {{ seleccionadas.size > 0 ? seleccionadas.size : '' }} plantas</span>
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { cosecharPlantas } from '../../lib/api.js'

const props = defineProps({
  lote:          { type: Object, required: true },
  plantas:       { type: Array,  default: () => [] },
  pasadasUsadas: { type: Array,  default: () => [] },
  pasadaInicial: { type: String, default: 'A' },
  salasDestino:  { type: Array,  default: () => [] },
})
const emit = defineEmits(['cosechado', 'cerrar'])

const seleccionadas = ref(new Set())
const pesoHumedo    = ref(null)
const pasada        = ref(props.pasadaInicial)
const guardando     = ref(false)
const error         = ref('')
const salaDestinoId = ref(null)

// Toma las salas de la prop explícita o del objeto lote como fallback
const salas = computed(() => {
  const fromProp = props.salasDestino || []
  const fromLote = props.lote?.salas_destino || []
  return fromProp.length > 0 ? fromProp : fromLote
})

watch(salas, (arr) => {
  if (arr.length === 1 && salaDestinoId.value === null) {
    salaDestinoId.value = arr[0].id
  }
}, { immediate: true })

const plantasEnFloracion = computed(() => props.plantas.filter(p => p.state === 'floracion'))
const pasadaLabel = computed(() => pasada.value)

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
      sala_id:      salaDestinoId.value || undefined,
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

.mcp-field { display: flex; flex-direction: column; gap: 8px; }
.mcp-label {
  font-size: .82rem; font-weight: 600; color: var(--c-ink-700, #374151);
  display: flex; align-items: baseline; gap: 8px;
}
.mcp-hint { font-size: .75rem; color: var(--c-ink-400, #94a3b8); font-weight: 400; }
.mcp-opt  { font-size: .72rem; color: var(--c-ink-400, #94a3b8); font-weight: 400; }

.mcp-empty {
  padding: 12px 16px;
  background: #f1f5f9; border-radius: 10px;
  font-size: .82rem; color: #64748b;
}

.mcp-sel-all {
  align-self: flex-start;
  font-size: .75rem; color: #1b5e20; background: none; border: none;
  cursor: pointer; padding: 0; text-decoration: underline; font-weight: 600;
}

.mcp-plantas-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 8px; max-height: 240px; overflow-y: auto;
  border: 1.5px solid var(--c-ink-200, #e2e8f0); border-radius: 12px;
  padding: 10px;
}
.mcp-planta {
  display: flex; flex-direction: column; align-items: center; gap: 4px;
  padding: 8px 6px;
  border: 1.5px solid var(--c-ink-200, #e2e8f0);
  border-radius: 10px; cursor: pointer; background: #f8fafc;
  transition: border-color .15s, background .15s;
  font-size: .72rem; color: #374151;
}
.mcp-planta--sel { border-color: #16a34a; background: #dcfce7; }
.mcp-planta-ico { font-size: 16px; }
.mcp-planta-nombre { font-family: monospace; font-size: .7rem; word-break: break-all; text-align: center; }

.mcp-sala-unica {
  display: flex; align-items: center; gap: 8px;
  padding: .55rem .9rem;
  background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 10px;
  font-size: .82rem; color: #15803d; font-weight: 600;
}
.mcp-input-wrap { display: flex; align-items: center; gap: 8px; }
.mcp-input {
  flex: 1; padding: .6rem .9rem;
  border: 1.5px solid var(--c-ink-200, #e2e8f0); border-radius: 10px;
  font-size: .875rem; outline: none;
  background: #f8fafc;
}
.mcp-input:focus { border-color: #4ade80; }
.mcp-unit { font-size: .82rem; color: #64748b; font-weight: 600; }

.mcp-pasadas { display: flex; gap: 8px; flex-wrap: wrap; }
.mcp-pasada-btn {
  padding: 6px 16px; border-radius: 999px;
  border: 1.5px solid var(--c-ink-200, #e2e8f0);
  background: #f8fafc; font-size: .82rem; font-weight: 700;
  cursor: pointer; color: #374151; transition: all .15s;
  display: flex; align-items: center; gap: 4px;
}
.mcp-pasada-btn--active { border-color: #16a34a; background: #dcfce7; color: #15803d; }
.mcp-pasada-btn--usada { opacity: .6; }
.mcp-pasada-tag { font-size: .65rem; color: #16a34a; }

.mcp-resumen {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 16px;
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 12px;
  font-size: .82rem; color: #15803d;
}
.mcp-resumen-ico { font-size: 18px; flex-shrink: 0; }
.mcp-error {
  padding: 10px 14px; background: #fef2f2; border: 1px solid #fecaca;
  border-radius: 10px; font-size: .82rem; color: #dc2626;
}
.mcp-spinner {
  display: inline-block; width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,.4); border-top-color: #fff;
  border-radius: 50%; animation: mcp-spin .6s linear infinite;
}
@keyframes mcp-spin { to { transform: rotate(360deg); } }

.mcp-footer {
  display: flex; gap: 10px; padding: 16px 24px;
  border-top: 1px solid var(--c-ink-100, #f1f5f1);
}
.mcp-btn-cancel {
  flex: 1; padding: .65rem; border: 1.5px solid var(--c-ink-200, #e2e8f0);
  border-radius: 12px; background: none; cursor: pointer;
  font-size: .875rem; color: #64748b; font-weight: 500;
}
.mcp-btn-submit {
  flex: 2; padding: .65rem;
  border-radius: 12px; border: none; cursor: pointer;
  background: #15803d; color: #fff; font-size: .875rem; font-weight: 700;
  transition: background .15s;
}
.mcp-btn-submit:hover:not(:disabled) { background: #166534; }
.mcp-btn-submit:disabled { opacity: .5; cursor: not-allowed; }
</style>
