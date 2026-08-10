<template>
  <Teleport to="body">
    <div v-if="modelValue" class="dsp__overlay" @click.self="cerrar">
      <div class="dsp__modal">
        <div class="dsp__head">
          <div>
            <h3 class="dsp__title">🪴 Separar plantas a otro lote</h3>
            <p class="dsp__sub">{{ lote?.codigo }} · {{ vivas }} plantas</p>
          </div>
          <button class="dsp__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="dsp__body">
          <p class="dsp__nota">
            Desde que van a macetas distintas dejan de ser el mismo grupo: cambia el riego, la
            frecuencia y cuándo toca el próximo trasplante. Por eso se separan en dos lotes.
          </p>
          <div v-if="error" class="dsp__alert">{{ error }}</div>

          <!-- ENRAIZANDO SE SEPARA POR CANTIDAD, y no hay opción de elegir: en la clonadora la
               etiqueta es del LOTE, las plántulas no tienen QR propio todavía. Recién cuando pasan a
               maceta individual tiene sentido decir CUÁLES —ahí sí, si el sistema las elige solo, el
               QR de la maceta deja de coincidir con el lote que figura en la app—. -->
          <div v-if="puedeElegir" class="dsp__modos">
            <button type="button" class="dsp__modo" :class="{ 'dsp__modo--on': modo === 'cantidad' }"
                    @click="modo = 'cantidad'">Por cantidad</button>
            <button type="button" class="dsp__modo" :class="{ 'dsp__modo--on': modo === 'elegir' }"
                    @click="activarElegir">Elegir plantas</button>
          </div>

          <div v-if="modo === 'cantidad'" class="dsp__field">
            <label class="dsp__label">¿Cuántas se separan?</label>
            <input v-model.number="cantidad" type="number" min="1" :max="vivas - 1" class="dsp__input" />
            <span class="dsp__hint">
              Quedan {{ Math.max(vivas - (cantidad || 0), 0) }} en {{ lote?.codigo }} y se van
              {{ cantidad || 0 }} al lote nuevo.
            </span>
          </div>

          <div v-else class="dsp__field">
            <label class="dsp__label">Escaneá o buscá las plantas que se van</label>
            <!-- Sirve igual con lector físico (escribe y manda Enter) que tecleando el código. -->
            <input ref="scanInput" v-model.trim="busqueda" type="text" class="dsp__input"
                   placeholder="Código de la planta…" @keydown.enter.prevent="marcarPrimera" />
            <div v-if="cargandoPlantas" class="dsp__hint">Cargando plantas…</div>
            <div v-else class="dsp__lista">
              <label v-for="p in plantasFiltradas" :key="p.id" class="dsp__item"
                     :class="{ 'dsp__item--on': elegidas.has(p.id) }">
                <input type="checkbox" :checked="elegidas.has(p.id)" @change="alternar(p.id)" />
                <span class="dsp__item-nom">{{ p.nombre || p.codigo || `#${p.id}` }}</span>
                <span v-if="p.codigo && p.nombre" class="dsp__item-cod">{{ p.codigo }}</span>
              </label>
              <div v-if="!plantasFiltradas.length" class="dsp__hint">Ninguna planta coincide.</div>
            </div>
            <span class="dsp__hint">{{ elegidas.size }} elegidas de {{ vivas }}</span>
          </div>

          <div class="dsp__field">
            <label class="dsp__label">Maceta del lote nuevo</label>
            <select v-model="maceta" class="dsp__input">
              <option value="">— Deja la misma ({{ lote?.tamanio_maceta || '—' }} L) —</option>
              <option v-for="m in MACETAS" :key="m.v" :value="m.v">{{ m.l }}</option>
            </select>
          </div>

          <div class="dsp__field">
            <label class="dsp__label">Motivo <span class="dsp__opt">(opcional)</span></label>
            <input v-model.trim="motivo" type="text" class="dsp__input"
                   placeholder="Ej. las de más vigor van a maceta más grande" />
          </div>

          <!-- El costo acumulado se reparte por cabeza: si no, el lote original cargaría plantas
               que ya no tiene y el nuevo saldría gratis. -->
          <p v-if="valido" class="dsp__resumen">
            El lote nuevo se va a llamar <strong>{{ codigoPrevisto }}</strong> y se lleva
            <strong>{{ pct }}%</strong> del costo acumulado.
          </p>
        </div>

        <div class="dsp__foot">
          <button class="dsp__btn dsp__btn--ghost" @click="cerrar">Cancelar</button>
          <button class="dsp__btn" :disabled="saving || !valido" @click="guardar">
            {{ saving ? 'Separando…' : 'Separar' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { MACETA_OPCIONES } from '../../lib/loteHelpers.js'
import { ref, computed, watch } from 'vue'
import { desprenderLote, listPlants } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  lote:       { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue', 'desprendido'])

const toast = useToast()

const MACETAS = MACETA_OPCIONES

const cantidad = ref(null)
const maceta   = ref('')
const motivo   = ref('')
const saving   = ref(false)
const error    = ref(null)

// ── Elegir plantas concretas ───────────────────────────────
const modo            = ref('cantidad')
const elegidas        = ref(new Set())
const plantas         = ref([])
const cargandoPlantas = ref(false)
const busqueda        = ref('')
const scanInput       = ref(null)

const plantasFiltradas = computed(() => {
  const q = busqueda.value.toLowerCase()
  if (!q) return plantas.value
  return plantas.value.filter(p =>
    `${p.nombre || ''} ${p.codigo || ''} ${p.codigo_qr || ''}`.toLowerCase().includes(q))
})

async function activarElegir() {
  modo.value = 'elegir'
  if (plantas.value.length) return
  cargandoPlantas.value = true
  try {
    const { data } = await listPlants({ lote_id: props.lote.id })
    // Las descartadas no se separan: ya no están en el cultivo.
    plantas.value = (data || []).filter(p => p.state !== 'descartada')
  } catch { plantas.value = [] } finally { cargandoPlantas.value = false }
}

function alternar(id) {
  const s = new Set(elegidas.value)
  s.has(id) ? s.delete(id) : s.add(id)
  elegidas.value = s
}

// Enter tras escanear: marca la única que coincide y limpia para el siguiente escaneo, así se
// pueden pasar 10 etiquetas seguidas sin tocar el mouse.
function marcarPrimera() {
  const m = plantasFiltradas.value
  if (m.length !== 1) return
  alternar(m[0].id)
  busqueda.value = ''
  scanInput.value?.focus()
}

// En el enraizado la etiqueta es del lote —las plántulas comparten bandeja y no tienen QR propio—,
// así que ahí solo se separa por cantidad.
const puedeElegir = computed(() => props.lote?.estado !== 'enraizado')

const vivas = computed(() => props.lote?.plants_count || 0)
const cuantas = computed(() => modo.value === 'elegir' ? elegidas.value.size : (cantidad.value || 0))
// Desprender el lote entero lo dejaría vacío: para cambiarle la maceta a todo se edita el lote.
const valido = computed(() => cuantas.value > 0 && cuantas.value < vivas.value)
const pct = computed(() => vivas.value ? Math.round((cuantas.value / vivas.value) * 100) : 0)
const codigoPrevisto = computed(() => `${(props.lote?.codigo || '').replace(/-[B-Z]$/, '')}-B`)

watch(() => props.modelValue, (v) => {
  if (v) {
    cantidad.value = null; maceta.value = ''; motivo.value = ''; error.value = null
    // Siempre arranca por cantidad: es el caso normal, y en enraizado es el único posible.
    modo.value = 'cantidad'; elegidas.value = new Set(); busqueda.value = ''; plantas.value = []
  }
})

function cerrar() { emit('update:modelValue', false) }

async function guardar() {
  saving.value = true; error.value = null
  try {
    const payload = modo.value === 'elegir'
      ? { plant_ids: [...elegidas.value] }
      : { cantidad: cantidad.value }
    if (maceta.value) payload.tamanio_maceta = maceta.value
    if (motivo.value) payload.motivo = motivo.value
    const { data } = await desprenderLote(props.lote.id, payload)
    toast.success(`${cuantas.value} plantas separadas a ${data.lote_nuevo.codigo}`)
    emit('desprendido', data.lote_nuevo)
    cerrar()
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo separar'
  } finally { saving.value = false }
}
</script>

<style scoped>
.dsp__overlay {
  position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1200;
  display: flex; align-items: center; justify-content: center; padding: 1rem;
}
.dsp__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 440px; overflow: hidden; }
.dsp__head {
  display: flex; align-items: flex-start; justify-content: space-between;
  padding: .9rem 1rem; border-bottom: 1px solid var(--c-slate-100);
}
.dsp__title { margin: 0; font-size: .95rem; color: #1e293b; }
.dsp__sub   { margin: .15rem 0 0; font-size: .75rem; color: var(--c-slate-400); }
.dsp__close { border: none; background: none; cursor: pointer; color: var(--c-slate-400); font-size: .85rem; }
.dsp__body  { padding: 1rem; display: flex; flex-direction: column; gap: .75rem; }
.dsp__nota  {
  margin: 0; font-size: .75rem; color: var(--c-slate-500); line-height: 1.45; background: #f0fdf4;
  border-left: 3px solid #86efac; padding: .5rem .65rem; border-radius: 0 6px 6px 0;
}
.dsp__resumen { margin: 0; font-size: .78rem; color: var(--c-slate-600); background: var(--c-slate-50); padding: .55rem .7rem; border-radius: 8px; }
.dsp__foot  { display: flex; justify-content: flex-end; gap: .5rem; padding: .8rem 1rem; border-top: 1px solid var(--c-slate-100); }

.dsp__field { display: flex; flex-direction: column; gap: .25rem; }
.dsp__label { font-size: .75rem; font-weight: 600; color: var(--c-slate-600); }
.dsp__opt   { font-weight: 400; color: var(--c-slate-400); }
.dsp__input {
  border: 1px solid var(--c-slate-200); border-radius: 8px; padding: .5rem .65rem; font-size: .85rem;
  width: 100%; box-sizing: border-box; font-family: inherit;
}
.dsp__input:focus { outline: none; border-color: #16a34a; }
.dsp__hint  { font-size: .7rem; color: var(--c-slate-400); }
.dsp__alert { background: #fee2e2; color: #b91c1c; padding: .5rem .7rem; border-radius: 8px; font-size: .78rem; }

.dsp__btn {
  border: none; border-radius: 8px; padding: .5rem .9rem; cursor: pointer;
  background: #16a34a; color: #fff; font-size: .82rem; font-weight: 600;
}
.dsp__btn:disabled { opacity: .5; cursor: not-allowed; }
.dsp__btn--ghost { background: none; color: var(--c-slate-500); border: 1px solid var(--c-slate-200); }

.dsp__modos { display: flex; gap: .4rem; }
.dsp__modo {
  flex: 1; border: 1px solid var(--c-slate-200); background: none; border-radius: 8px; cursor: pointer;
  padding: .4rem .6rem; font-size: .78rem; color: var(--c-slate-500);
}
.dsp__modo--on { border-color: #16a34a; background: #f0fdf4; color: #15803d; font-weight: 600; }

.dsp__lista { max-height: 220px; overflow-y: auto; border: 1px solid var(--c-slate-200); border-radius: 8px; }
.dsp__item {
  display: flex; align-items: center; gap: .5rem; padding: .4rem .6rem; cursor: pointer;
  font-size: .8rem; border-bottom: 1px solid var(--c-slate-50);
}
.dsp__item:last-child { border-bottom: none; }
.dsp__item--on { background: #f0fdf4; }
.dsp__item-nom { flex: 1; color: #1e293b; }
.dsp__item-cod { font-size: .7rem; color: var(--c-slate-400); }
</style>
