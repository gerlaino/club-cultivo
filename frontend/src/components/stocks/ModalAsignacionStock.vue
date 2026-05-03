<script setup>
import { ref, computed, onMounted } from 'vue'
import { listSedes, asignarStock } from '../../lib/api.js'

const props = defineProps({
  stocks: { type: Array, required: true },  // array de stocks pendientes
})
const emit = defineEmits(['close', 'asignado'])

const sedes      = ref([])
const seleccion  = ref({})   // { stockId: sedeId | 'club' | null }
const saving     = ref(false)
const error      = ref(null)

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado', otro: 'Otro',
}

const sedesSociales = computed(() =>
  sedes.value.filter(s => ['social', 'mixta'].includes(s.tipo))
)

onMounted(async () => {
  const { data } = await listSedes()
  sedes.value = data || []
  // Inicializar selección vacía para cada stock
  props.stocks.forEach(s => { seleccion.value[s.id] = null })
})

function opcionLabel(sede) {
  const tipo = { social: 'Dispensario', mixta: 'Mixta', produccion: 'Producción' }[sede.tipo] || sede.tipo
  return `${sede.nombre} (${tipo})`
}

function todosSeleccionados() {
  return props.stocks.every(s => seleccion.value[s.id] !== null && seleccion.value[s.id] !== undefined)
}

async function confirmar() {
  error.value = null
  saving.value = true
  try {
    const resultados = await Promise.all(
      props.stocks.map(stock => {
        const val = seleccion.value[stock.id]
        const payload = val === 'club' ? { sede_id: null } : { sede_id: val }
        return asignarStock(stock.id, payload).then(r => r.data)
      })
    )
    emit('asignado', resultados)
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'Error al asignar'
  } finally {
    saving.value = false
  }
}

function decidirDespues() {
  emit('close')
}
</script>

<template>
  <Teleport to="body">
    <div class="mas__overlay" @click.self="decidirDespues">
      <div class="mas__modal">
        <div class="mas__header">
          <div>
            <h2 class="mas__title">¿Dónde va este stock?</h2>
            <p class="mas__subtitle">
              {{ stocks.length }} lote{{ stocks.length !== 1 ? 's' : '' }} de stock listo{{ stocks.length !== 1 ? 's' : '' }} para asignación
            </p>
          </div>
          <button class="mas__close" @click="decidirDespues"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mas__body">
          <div v-for="stock in stocks" :key="stock.id" class="mas__stock-item">
            <div class="mas__stock-info">
              <span class="mas__stock-lote">{{ stock.lote_codigo }}</span>
              <span class="mas__stock-detalle">{{ stock.cantidad }}g · {{ FORMA_LABEL[stock.forma_producto] || stock.forma_producto }}</span>
            </div>

            <div class="mas__opciones">
              <label
                v-for="sede in sedesSociales"
                :key="sede.id"
                class="mas__opcion"
                :class="{ 'mas__opcion--selected': seleccion[stock.id] === sede.id }"
              >
                <input type="radio" :name="`stock-${stock.id}`" :value="sede.id" v-model="seleccion[stock.id]" />
                <div class="mas__opcion-body">
                  <span class="mas__opcion-nombre">{{ sede.nombre }}</span>
                  <span class="mas__opcion-tipo">{{ { social: 'Dispensario', mixta: 'Mixta' }[sede.tipo] || sede.tipo }}</span>
                </div>
              </label>

              <label
                class="mas__opcion mas__opcion--club"
                :class="{ 'mas__opcion--selected': seleccion[stock.id] === 'club' }"
              >
                <input type="radio" :name="`stock-${stock.id}`" value="club" v-model="seleccion[stock.id]" />
                <div class="mas__opcion-body">
                  <span class="mas__opcion-nombre">📦 Pool del club</span>
                  <span class="mas__opcion-tipo">Para envíos a domicilio</span>
                </div>
              </label>
            </div>
          </div>

          <div v-if="error" class="mas__error">{{ error }}</div>
        </div>

        <div class="mas__footer">
          <button class="mas__btn-ghost" @click="decidirDespues" :disabled="saving">
            Decidir después
          </button>
          <button
            class="mas__btn-primary"
            :disabled="saving || !todosSeleccionados()"
            @click="confirmar"
          >
            <span v-if="saving"><i class="bi bi-arrow-repeat mas__spin"></i> Asignando…</span>
            <span v-else>Confirmar asignación</span>
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mas__overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  backdrop-filter: blur(4px);
  display: flex; align-items: center; justify-content: center;
  z-index: 1100; padding: 1rem;
}
.mas__modal {
  background: #fff;
  border-radius: 16px;
  width: 100%; max-width: 520px;
  max-height: 90vh; overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,.18);
  display: flex; flex-direction: column;
}
.mas__header {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
  padding: 1.5rem 1.5rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}
.mas__title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin: 0; }
.mas__subtitle { font-size: .8rem; color: #64748b; margin: .2rem 0 0; }
.mas__close {
  background: none; border: none; cursor: pointer; color: #94a3b8;
  font-size: 1rem; padding: .25rem; border-radius: 6px;
  transition: all .15s; flex-shrink: 0;
}
.mas__close:hover { background: #f1f5f9; color: #1e293b; }

.mas__body { padding: 1rem 1.5rem; display: flex; flex-direction: column; gap: 1.25rem; }

.mas__stock-item { display: flex; flex-direction: column; gap: .6rem; }
.mas__stock-info { display: flex; align-items: center; gap: .6rem; }
.mas__stock-lote { font-weight: 700; font-size: .875rem; color: #0f172a; }
.mas__stock-detalle { font-size: .78rem; color: #64748b; background: #f1f5f9; padding: .15em .5em; border-radius: 5px; }

.mas__opciones { display: flex; flex-direction: column; gap: .4rem; }
.mas__opcion {
  display: flex; align-items: center; gap: .75rem;
  padding: .65rem .9rem;
  border: 1.5px solid #e2e8f0;
  border-radius: 10px;
  cursor: pointer;
  transition: all .15s;
}
.mas__opcion input[type="radio"] { accent-color: #1a3d2e; flex-shrink: 0; }
.mas__opcion:hover { border-color: #94a3b8; background: #f8fafc; }
.mas__opcion--selected { border-color: #1a3d2e; background: #f0fdf4; }
.mas__opcion--club { border-style: dashed; }
.mas__opcion--club.mas__opcion--selected { border-color: #0369a1; background: #f0f9ff; border-style: solid; }
.mas__opcion-body { display: flex; flex-direction: column; gap: .1rem; }
.mas__opcion-nombre { font-size: .875rem; font-weight: 600; color: #1e293b; }
.mas__opcion-tipo { font-size: .72rem; color: #64748b; }

.mas__error {
  background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c;
  padding: .65rem .9rem; border-radius: 8px; font-size: .82rem;
}

.mas__footer {
  display: flex; justify-content: flex-end; gap: .6rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid #f1f5f9;
}
.mas__btn-ghost {
  background: none; border: 1.5px solid #e2e8f0; color: #64748b;
  padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500;
  cursor: pointer; transition: all .15s;
}
.mas__btn-ghost:hover:not(:disabled) { background: #f8fafc; color: #1e293b; }
.mas__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.mas__btn-primary {
  background: #1a3d2e; color: #fff;
  border: none; padding: .6rem 1.3rem; border-radius: 9px;
  font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.mas__btn-primary:hover:not(:disabled) { background: #0f2a1e; }
.mas__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
@keyframes spin { to { transform: rotate(360deg); } }
.mas__spin { display: inline-block; animation: spin 1s linear infinite; }
</style>
