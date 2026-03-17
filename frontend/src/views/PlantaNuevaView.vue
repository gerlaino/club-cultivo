<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { createPlant, listLotes } from '../lib/api.js'
import api from '../lib/api.js'

const router = useRouter()
const route  = useRoute()

const lotes    = ref([])
const geneticas = ref([])
const saving   = ref(false)
const errors   = ref({})

const today = new Date().toISOString().split('T')[0]

const STATE_META = {
  germinacion: { label: 'Germinación', icon: '🌰', color: 'primary'   },
  vegetativo:  { label: 'Vegetativo',  icon: '🌱', color: 'success'   },
  floracion:   { label: 'Floración',   icon: '🌸', color: 'warning'   },
  secado:      { label: 'Secado',      icon: '🍂', color: 'secondary' },
  cosechado:   { label: 'Cosechado',   icon: '✂️',  color: 'purple'   },
}

const form = ref({
  nombre:            '',
  lote_id:           route.query.lote_id ? Number(route.query.lote_id) : '',
  genetica_id:       '',
  state:             'germinacion',
  fecha_germinacion: today,
  fecha_vegetativo:  '',
  fecha_floracion:   '',
  fecha_cosecha:     '',
  peso_seco:         null,
  notas:             '',
})

// ── Computed ──────────────────────────────────────────────────────────
const diasDesdeGerminacion = computed(() => {
  if (!form.value.fecha_germinacion) return null
  const diff = Math.floor((new Date() - new Date(form.value.fecha_germinacion)) / 86400000)
  return diff >= 0 ? diff : null
})

const loteSeleccionado = computed(() =>
    lotes.value.find(l => l.id === Number(form.value.lote_id)) || null
)

// ── Validación ────────────────────────────────────────────────────────
function validate() {
  const e = {}
  if (!form.value.nombre.trim())  e.nombre  = 'El nombre es obligatorio'
  if (!form.value.lote_id)        e.lote_id = 'Seleccioná un lote'
  errors.value = e
  return !Object.keys(e).length
}

// ── Submit ────────────────────────────────────────────────────────────
async function handleSubmit() {
  if (!validate()) return
  saving.value = true
  errors.value = {}
  try {
    const payload = {}
    Object.entries(form.value).forEach(([k, v]) => {
      if (v !== '' && v !== null) payload[k] = v
    })
    const { data } = await createPlant(payload)
    router.push(`/plantas/${data.id}`)
  } catch (e) {
    errors.value.general = e.response?.data?.errors?.join(', ') || 'Error al crear la planta'
  } finally {
    saving.value = false
  }
}

// ── Carga ─────────────────────────────────────────────────────────────
onMounted(async () => {
  const [lotesRes, genRes] = await Promise.allSettled([
    listLotes(),
    api.get('/geneticas'),
  ])
  if (lotesRes.status === 'fulfilled')  lotes.value    = lotesRes.value.data
  if (genRes.status   === 'fulfilled')  geneticas.value = genRes.value.data
})
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4" style="max-width:960px">

    <!-- Header -->
    <div class="d-flex align-items-center justify-content-between mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Nueva planta</h1>
        <p class="text-muted small mb-0">Registrá una planta en el sistema de trazabilidad</p>
      </div>
      <button class="btn btn-sm btn-outline-secondary" @click="router.back()">
        <i class="bi bi-arrow-left me-1"></i>Volver
      </button>
    </div>

    <div class="row g-4">

      <!-- ── Formulario ── -->
      <div class="col-12 col-lg-8">

        <!-- Error general -->
        <div v-if="errors.general" class="alert alert-danger alert-dismissible d-flex align-items-center gap-2 mb-3">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>{{ errors.general }}</span>
          <button class="btn-close" @click="errors.general=''"></button>
        </div>

        <!-- Datos básicos -->
        <div class="card border-0 shadow-sm mb-4">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Datos básicos</strong>
          </div>
          <div class="card-body">
            <div class="row g-3">

              <div class="col-12">
                <label class="form-label small fw-semibold">Nombre <span class="text-danger">*</span></label>
                <input
                    v-model.trim="form.nombre"
                    class="form-control"
                    :class="{ 'is-invalid': errors.nombre }"
                    placeholder="Ej: Planta A-001"
                />
                <div class="invalid-feedback">{{ errors.nombre }}</div>
              </div>

              <div class="col-md-6">
                <label class="form-label small fw-semibold">Lote <span class="text-danger">*</span></label>
                <select
                    v-model="form.lote_id"
                    class="form-select"
                    :class="{ 'is-invalid': errors.lote_id }"
                >
                  <option value="">Seleccioná un lote…</option>
                  <option v-for="l in lotes" :key="l.id" :value="l.id">
                    {{ l.codigo }} · {{ l.sala?.nombre || 'Sin sala' }}
                  </option>
                </select>
                <div class="invalid-feedback">{{ errors.lote_id }}</div>
                <div v-if="loteSeleccionado" class="form-text text-success">
                  ✓ {{ loteSeleccionado.estado }} · {{ loteSeleccionado.plants_count }} plantas
                </div>
              </div>

              <div class="col-md-6">
                <label class="form-label small fw-semibold">Genética</label>
                <select v-model="form.genetica_id" class="form-select">
                  <option value="">Sin genética asignada</option>
                  <option v-for="g in geneticas" :key="g.id" :value="g.id">
                    {{ g.nombre }} {{ g.tipo ? `(${g.tipo})` : '' }}
                  </option>
                </select>
              </div>

              <div class="col-12">
                <label class="form-label small fw-semibold">Estado inicial</label>
                <div class="d-flex flex-wrap gap-2">
                  <button
                      v-for="(meta, key) in STATE_META" :key="key"
                      type="button"
                      class="btn btn-sm"
                      :class="form.state === key ? `btn-${meta.color}` : 'btn-outline-secondary'"
                      @click="form.state = key"
                  >
                    {{ meta.icon }} {{ meta.label }}
                  </button>
                </div>
              </div>

            </div>
          </div>
        </div>

        <!-- Timeline -->
        <div class="card border-0 shadow-sm mb-4">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Timeline</strong>
            <p class="text-muted small mb-0">Completá las fechas que ya ocurrieron</p>
          </div>
          <div class="card-body">
            <div class="row g-3">

              <div class="col-md-6">
                <label class="form-label small fw-semibold">🌰 Fecha de germinación</label>
                <input v-model="form.fecha_germinacion" type="date" class="form-control" :max="today" />
                <div v-if="diasDesdeGerminacion !== null" class="form-text text-success">
                  {{ diasDesdeGerminacion }} días desde la germinación
                </div>
              </div>

              <div v-if="form.state !== 'germinacion'" class="col-md-6">
                <label class="form-label small fw-semibold">🌱 Inicio vegetativo</label>
                <input v-model="form.fecha_vegetativo" type="date" class="form-control" :max="today" />
              </div>

              <div v-if="['floracion','secado','cosechado'].includes(form.state)" class="col-md-6">
                <label class="form-label small fw-semibold">🌸 Inicio floración</label>
                <input v-model="form.fecha_floracion" type="date" class="form-control" :max="today" />
              </div>

              <div v-if="form.state === 'cosechado'" class="col-md-6">
                <label class="form-label small fw-semibold">✂️ Fecha de cosecha</label>
                <input v-model="form.fecha_cosecha" type="date" class="form-control" :max="today" />
              </div>

              <div v-if="form.state === 'cosechado'" class="col-md-6">
                <label class="form-label small fw-semibold">⚖️ Peso seco (gramos)</label>
                <input v-model.number="form.peso_seco" type="number" step="0.1" min="0" class="form-control" placeholder="0.0" />
              </div>

            </div>
          </div>
        </div>

        <!-- Notas -->
        <div class="card border-0 shadow-sm mb-4">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Notas</strong>
          </div>
          <div class="card-body">
            <textarea
                v-model.trim="form.notas"
                class="form-control"
                rows="3"
                placeholder="Observaciones, particularidades, etc."
            ></textarea>
          </div>
        </div>

        <!-- Botones -->
        <div class="d-flex gap-2">
          <button class="btn btn-success px-4" :disabled="saving" @click="handleSubmit">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
            <i v-else class="bi bi-check-circle me-1"></i>
            {{ saving ? 'Creando...' : 'Crear planta' }}
          </button>
          <button class="btn btn-outline-secondary" :disabled="saving" @click="router.back()">
            Cancelar
          </button>
        </div>

      </div>

      <!-- ── Panel lateral ── -->
      <div class="col-12 col-lg-4">

        <!-- Preview -->
        <div class="card border-0 shadow-sm mb-3">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Preview</strong>
          </div>
          <div class="card-body">
            <div class="d-flex align-items-center gap-2 mb-2">
              <span class="fs-4">{{ STATE_META[form.state]?.icon }}</span>
              <div>
                <div class="fw-semibold">{{ form.nombre || 'Nombre de la planta' }}</div>
                <span class="badge" :class="`text-bg-${STATE_META[form.state]?.color}`">
                  {{ STATE_META[form.state]?.label }}
                </span>
              </div>
            </div>
            <div class="small text-muted">
              <div v-if="loteSeleccionado">📦 {{ loteSeleccionado.codigo }}</div>
              <div v-if="form.genetica_id">
                🌿 {{ geneticas.find(g => g.id === Number(form.genetica_id))?.nombre }}
              </div>
              <div v-if="diasDesdeGerminacion !== null">📅 {{ diasDesdeGerminacion }} días</div>
            </div>
          </div>
        </div>

        <!-- Info -->
        <div class="card border-0 bg-body-secondary">
          <div class="card-body small">
            <div class="fw-semibold mb-2">ℹ️ A tener en cuenta</div>
            <ul class="mb-0 ps-3">
              <li class="mb-1">El <strong>código QR</strong> se genera automáticamente</li>
              <li class="mb-1">El <strong>lote</strong> agrupa plantas de las mismas condiciones</li>
              <li class="mb-1">Las <strong>fechas</strong> calculan tiempos por etapa</li>
              <li>Podés cambiar el estado después desde el detalle</li>
            </ul>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.text-bg-purple { background: #6f42c1 !important; color: white !important; }
.btn-purple     { background: #6f42c1; border-color: #6f42c1; color: white; }
</style>
