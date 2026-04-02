<template>
  <div>
    <div v-if="loading" class="text-center py-2">
      <div class="spinner-border spinner-border-sm text-primary"></div>
    </div>

    <div v-else-if="sedesAsignadas.length === 0" class="text-muted small py-1">
      <i class="bi bi-building-dash me-1"></i>Sin sedes asignadas
    </div>

    <div v-else class="mb-3">
      <div v-for="sede in sedesAsignadas" :key="sede.id"
           class="d-flex align-items-center justify-content-between py-2 border-bottom">
        <div>
          <div class="fw-semibold small">{{ sede.nombre }}</div>
          <div class="text-muted" style="font-size:0.72rem">
            <span class="badge" :class="tipoBadge(sede.tipo)">{{ sede.tipo }}</span>
          </div>
        </div>
        <button v-if="puedeEditar" class="btn btn-sm btn-outline-danger" @click="desasignar(sede)">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
    </div>

    <div v-if="puedeEditar">
      <div v-if="!mostrarForm" class="d-grid">
        <button class="btn btn-sm btn-outline-primary" @click="abrirForm">
          <i class="bi bi-plus-lg me-1"></i>Asignar sede
        </button>
      </div>

      <div v-else class="border rounded p-3 bg-light">
        <!-- Seleccionar todo -->
        <div class="form-check mb-2">
          <input class="form-check-input" type="checkbox" id="todasLasSedes"
                 :checked="todasSeleccionadas" @change="toggleTodas">
          <label class="form-check-label small fw-semibold" for="todasLasSedes">
            Seleccionar todas las sedes
          </label>
        </div>
        <hr class="my-2">

        <div class="mb-3" style="max-height:180px;overflow-y:auto">
          <div v-for="sede in sedesDisponibles" :key="sede.id" class="form-check">
            <input class="form-check-input" type="checkbox"
                   :id="`sede-${sede.id}`"
                   :value="sede.id"
                   v-model="seleccionadas">
            <label class="form-check-label small" :for="`sede-${sede.id}`">
              {{ sede.nombre }}
              <span class="badge ms-1" :class="tipoBadge(sede.tipo)">{{ sede.tipo }}</span>
            </label>
          </div>
          <div v-if="sedesDisponibles.length === 0" class="text-muted small">
            Todas las sedes ya están asignadas
          </div>
        </div>

        <div v-if="error" class="text-danger small mb-2">{{ error }}</div>

        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-primary" @click="asignar"
                  :disabled="seleccionadas.length === 0 || asignando">
            <span v-if="asignando" class="spinner-border spinner-border-sm me-1"></span>
            <i v-else class="bi bi-check-lg me-1"></i>
            Confirmar ({{ seleccionadas.length }})
          </button>
          <button class="btn btn-sm btn-outline-secondary" @click="cerrarForm">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { getUserSedesAsignadas, asignarSedeAUsuario, desasignarSedeAUsuario, listSedes } from '../lib/api.js'

const props = defineProps({ userId: { type: Number, required: true } })

const auth          = useAuthStore()
const sedesAsignadas = ref([])
const todasLasSedes  = ref([])
const loading        = ref(false)
const mostrarForm    = ref(false)
const seleccionadas  = ref([])
const asignando      = ref(false)
const error          = ref('')

const puedeEditar = computed(() => ['admin', 'agricultor'].includes(auth.user?.role))

const sedesDisponibles = computed(() => {
  const asignadasIds = new Set(sedesAsignadas.value.map(s => s.id))
  return todasLasSedes.value.filter(s => !asignadasIds.has(s.id))
})

const todasSeleccionadas = computed(() =>
  sedesDisponibles.value.length > 0 &&
  seleccionadas.value.length === sedesDisponibles.value.length
)

function toggleTodas() {
  if (todasSeleccionadas.value) {
    seleccionadas.value = []
  } else {
    seleccionadas.value = sedesDisponibles.value.map(s => s.id)
  }
}

function tipoBadge(tipo) {
  return { produccion: 'bg-success text-white', social: 'bg-primary text-white', mixta: 'bg-purple text-white' }[tipo] || 'bg-secondary text-white'
}

onMounted(async () => {
  loading.value = true
  try {
    const [resSedes, resTodas] = await Promise.all([
      getUserSedesAsignadas(props.userId),
      puedeEditar.value ? listSedes() : Promise.resolve({ data: [] })
    ])
    sedesAsignadas.value = resSedes.data || []
    todasLasSedes.value  = resTodas.data || []
  } catch (e) { console.error(e) }
  finally { loading.value = false }
})

function abrirForm() {
  seleccionadas.value = []
  error.value = ''
  mostrarForm.value = true
}

function cerrarForm() {
  mostrarForm.value = false
  seleccionadas.value = []
  error.value = ''
}

async function asignar() {
  if (seleccionadas.value.length === 0) return
  asignando.value = true
  error.value = ''
  try {
    await Promise.all(seleccionadas.value.map(sedeId => asignarSedeAUsuario(props.userId, sedeId)))
    const nuevas = todasLasSedes.value.filter(s => seleccionadas.value.includes(s.id))
    sedesAsignadas.value.push(...nuevas)
    cerrarForm()
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al asignar'
  } finally { asignando.value = false }
}

async function desasignar(sede) {
  if (!confirm(`¿Quitar "${sede.nombre}" de este usuario?`)) return
  try {
    await desasignarSedeAUsuario(props.userId, sede.id)
    sedesAsignadas.value = sedesAsignadas.value.filter(s => s.id !== sede.id)
  } catch (e) { error.value = e.response?.data?.error || 'Error al desasignar' }
}
</script>
