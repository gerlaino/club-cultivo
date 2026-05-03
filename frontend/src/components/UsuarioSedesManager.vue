<template>
  <div>
    <div v-if="loading" class="text-center py-2">
      <div class="spinner-border spinner-border-sm" style="color:#0f766e"></div>
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
            <i class="bi bi-geo-alt me-1"></i>{{ sede.tipo || 'Sede' }}
          </div>
        </div>
        <button v-if="puedeEditar" class="btn btn-sm btn-outline-danger" @click="desasignar(sede)">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
    </div>

    <div v-if="puedeEditar">
      <div v-if="!mostrarForm" class="d-grid">
        <button class="btn btn-sm btn-outline-success" @click="abrirForm" style="border-color:#0f766e;color:#0f766e">
          <i class="bi bi-plus-lg me-1"></i>Asignar sede
        </button>
      </div>

      <div v-else class="border rounded p-3 bg-light">
        <div class="mb-3">
          <label class="form-label small fw-semibold mb-1">Sede</label>
          <select v-model="sedeSeleccionada" class="form-select form-select-sm">
            <option value="">Seleccioná una sede...</option>
            <option v-for="sede in sedesDisponibles" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
          </select>
          <div v-if="sedesDisponibles.length === 0" class="text-muted small mt-1">No hay más sedes disponibles</div>
        </div>

        <div v-if="error" class="text-danger small mb-2">{{ error }}</div>

        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-success" @click="asignar" :disabled="!sedeSeleccionada || asignando"
                  style="background:#0f766e;border-color:#0f766e">
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
import { logger } from '../utils/logger.js'
import { useAuthStore } from '../stores/auth'
import { getUserSedesAsignadas, asignarSedeAUsuario, desasignarSedeAUsuario, listSedes } from '../lib/api.js'
import { useConfirm } from '../composables/useConfirm.js'

const { confirm } = useConfirm()

const props = defineProps({
  userId: { type: Number, required: true },
})

const auth           = useAuthStore()
const sedesAsignadas = ref([])
const todasLasSedes  = ref([])
const loading        = ref(false)
const mostrarForm    = ref(false)
const sedeSeleccionada = ref('')
const asignando      = ref(false)
const error          = ref('')

const puedeEditar = computed(() => auth.user?.role === 'admin')

const sedesDisponibles = computed(() => {
  const asignadasIds = new Set(sedesAsignadas.value.map(s => s.id))
  return todasLasSedes.value.filter(s => !asignadasIds.has(s.id))
})

onMounted(async () => {
  loading.value = true
  try {
    const [resSedes, resTodas] = await Promise.all([
      getUserSedesAsignadas(props.userId),
      puedeEditar.value ? listSedes() : Promise.resolve({ data: [] })
    ])
    sedesAsignadas.value = resSedes.data || []
    todasLasSedes.value  = resTodas.data || []
  } catch (e) { logger.error(e) }
  finally { loading.value = false }
})

function abrirForm() {
  sedeSeleccionada.value = ''
  error.value = ''
  mostrarForm.value = true
}

function cerrarForm() {
  mostrarForm.value = false
  sedeSeleccionada.value = ''
  error.value = ''
}

async function asignar() {
  if (!sedeSeleccionada.value) return
  asignando.value = true
  error.value = ''
  try {
    await asignarSedeAUsuario(props.userId, sedeSeleccionada.value)
    const sede = todasLasSedes.value.find(s => s.id === sedeSeleccionada.value)
    if (sede) sedesAsignadas.value.push(sede)
    cerrarForm()
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al asignar'
  } finally { asignando.value = false }
}

async function desasignar(sede) {
  const ok = await confirm({
    title: `¿Quitar "${sede.nombre}"?`,
    message: 'Se quitará esta sede del supervisor.',
    confirmText: 'Quitar',
  })
  if (!ok) return
  try {
    await desasignarSedeAUsuario(props.userId, sede.id)
    sedesAsignadas.value = sedesAsignadas.value.filter(s => s.id !== sede.id)
  } catch (e) { error.value = e.response?.data?.error || 'Error al desasignar' }
}
</script>
