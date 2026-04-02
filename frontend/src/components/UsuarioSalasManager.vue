<template>
  <div>
    <div v-if="loading" class="text-center py-2">
      <div class="spinner-border spinner-border-sm text-primary"></div>
    </div>
    <div v-else-if="salasAsignadas.length === 0" class="text-muted small py-1">
      <i class="bi bi-house-dash me-1"></i>Sin salas asignadas
    </div>
    <div v-else class="mb-3">
      <div v-for="sala in salasAsignadas" :key="sala.id"
           class="d-flex align-items-center justify-content-between py-2 border-bottom">
        <div>
          <div class="fw-semibold small">{{ sala.nombre }}</div>
          <div class="text-muted" style="font-size:0.72rem">
            <i class="bi bi-building me-1"></i>{{ sala.sede?.nombre || 'Sin sede' }}
          </div>
        </div>
        <button v-if="puedeEditar" class="btn btn-sm btn-outline-danger" @click="desasignar(sala)">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
    </div>

    <div v-if="puedeEditar">
      <div v-if="!mostrarForm" class="d-grid">
        <button class="btn btn-sm btn-outline-success" @click="abrirForm">
          <i class="bi bi-plus-lg me-1"></i>Asignar sala
        </button>
      </div>

      <div v-else class="border rounded p-3 bg-light">
        <div class="mb-2">
          <label class="form-label small fw-semibold mb-1">Sede</label>
          <select v-model="sedeSeleccionada" class="form-select form-select-sm" @change="salaSeleccionada = ''">
            <option value="">Seleccioná una sede...</option>
            <option v-for="sede in sedesDisponibles" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
          </select>
        </div>

        <div v-if="sedeSeleccionada" class="mb-3">
          <label class="form-label small fw-semibold mb-1">Sala</label>
          <select v-model="salaSeleccionada" class="form-select form-select-sm">
            <option value="">Seleccioná una sala...</option>
            <option v-for="sala in salasDeLaSede" :key="sala.id" :value="sala.id">{{ sala.nombre }}</option>
          </select>
          <div v-if="salasDeLaSede.length === 0" class="text-muted small mt-1">No hay salas disponibles en esta sede</div>
        </div>

        <div v-if="error" class="text-danger small mb-2">{{ error }}</div>

        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-success" @click="asignar" :disabled="!salaSeleccionada || asignando">
            <span v-if="asignando" class="spinner-border spinner-border-sm me-1"></span>
            <i v-else class="bi bi-check-lg me-1"></i>Confirmar
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
import { getUserSalasAsignadas, asignarSalaAUsuario, desasignarSalaAUsuario, listSalas } from '../lib/api.js'

const props = defineProps({ userId: { type: Number, required: true } })

const auth             = useAuthStore()
const salasAsignadas   = ref([])
const todasLasSalas    = ref([])
const loading          = ref(false)
const mostrarForm      = ref(false)
const sedeSeleccionada = ref('')
const salaSeleccionada = ref('')
const asignando        = ref(false)
const error            = ref('')

const puedeEditar = computed(() => ['admin', 'agricultor'].includes(auth.user?.role))

const salasNoAsignadas = computed(() => {
  const asignadasIds = new Set(salasAsignadas.value.map(s => s.id))
  return todasLasSalas.value.filter(s => !asignadasIds.has(s.id))
})

const sedesDisponibles = computed(() => {
  const map = new Map()
  salasNoAsignadas.value.forEach(sala => {
    if (sala.sede?.id && !map.has(sala.sede.id)) {
      map.set(sala.sede.id, { id: sala.sede.id, nombre: sala.sede.nombre })
    }
  })
  return Array.from(map.values())
})

const salasDeLaSede = computed(() =>
  !sedeSeleccionada.value ? [] :
    salasNoAsignadas.value.filter(s => s.sede?.id === sedeSeleccionada.value)
)

onMounted(async () => {
  loading.value = true
  try {
    const [resSalas, resTodas] = await Promise.all([
      getUserSalasAsignadas(props.userId),
      puedeEditar.value ? listSalas() : Promise.resolve({ data: [] })
    ])
    salasAsignadas.value = resSalas.data || []
    todasLasSalas.value  = resTodas.data || []
  } catch (e) { console.error(e) }
  finally { loading.value = false }
})

function abrirForm() {
  sedeSeleccionada.value = ''
  salaSeleccionada.value = ''
  error.value = ''
  mostrarForm.value = true
}

function cerrarForm() {
  mostrarForm.value = false
  sedeSeleccionada.value = ''
  salaSeleccionada.value = ''
  error.value = ''
}

async function asignar() {
  if (!salaSeleccionada.value) return
  asignando.value = true
  error.value = ''
  try {
    await asignarSalaAUsuario(props.userId, salaSeleccionada.value)
    const sala = todasLasSalas.value.find(s => s.id === salaSeleccionada.value)
    if (sala) salasAsignadas.value.push(sala)
    cerrarForm()
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al asignar'
  } finally { asignando.value = false }
}

async function desasignar(sala) {
  if (!confirm(`¿Quitar "${sala.nombre}" de este cultivador?`)) return
  try {
    await desasignarSalaAUsuario(props.userId, sala.id)
    salasAsignadas.value = salasAsignadas.value.filter(s => s.id !== sala.id)
  } catch (e) { error.value = e.response?.data?.error || 'Error al desasignar' }
}
</script>
