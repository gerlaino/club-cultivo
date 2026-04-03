<template>
  <div class="sala-cultivadores">
    <div class="d-flex align-items-center justify-content-between mb-3">
      <h6 class="fw-bold mb-0">
        <i class="bi bi-person-check me-2 text-success"></i>Cultivadores a cargo
      </h6>
      <button
        v-if="puedeEditar"
        class="btn btn-sm btn-outline-success"
        @click="mostrarAsignar = true"
      >
        <i class="bi bi-plus-lg me-1"></i>Asignar
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-2">
      <div class="spinner-border spinner-border-sm text-success"></div>
    </div>

    <!-- Sin cultivadores -->
    <div v-else-if="cultivadores.length === 0" class="text-muted small py-2">
      <i class="bi bi-person-dash me-1"></i>Sin cultivadores asignados
    </div>

    <!-- Lista de cultivadores -->
    <div v-else class="cultivadores-list">
      <div
        v-for="c in cultivadores"
        :key="c.id"
        class="cultivador-row"
      >
        <div class="d-flex align-items-center gap-2">
          <div class="cultivador-avatar">{{ iniciales(c.nombre_completo) }}</div>
          <div>
            <div class="fw-semibold small">{{ c.nombre_completo }}</div>
            <div class="text-muted" style="font-size:0.72rem">{{ c.email }}</div>
          </div>
        </div>
        <button
          v-if="puedeEditar"
          class="btn btn-sm btn-ghost text-danger"
          @click="desasignar(c)"
          title="Desasignar"
        >
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
    </div>

    <!-- Modal asignar cultivador -->
    <div v-if="mostrarAsignar" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-sm">
        <div class="modal-content">
          <div class="modal-header border-0 pb-0">
            <h6 class="modal-title fw-bold">Asignar cultivador</h6>
            <button class="btn-close" @click="mostrarAsignar = false"></button>
          </div>
          <div class="modal-body">
            <p class="small text-muted mb-3">Sala: <strong>{{ salaNombre }}</strong></p>
            <select v-model="userSeleccionado" class="form-select form-select-sm">
              <option value="">Seleccioná un cultivador...</option>
              <option
                v-for="u in cultivadoresDisponibles"
                :key="u.id"
                :value="u.id"
              >
                {{ u.first_name }} {{ u.last_name }}
              </option>
            </select>
            <div v-if="errorAsignar" class="text-danger small mt-2">{{ errorAsignar }}</div>
          </div>
          <div class="modal-footer border-0 pt-0">
            <button class="btn btn-sm btn-outline-secondary" @click="mostrarAsignar = false">Cancelar</button>
            <button
              class="btn btn-sm btn-success"
              @click="asignar"
              :disabled="!userSeleccionado || asignando"
            >
              <span v-if="asignando" class="spinner-border spinner-border-sm me-1"></span>
              Asignar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="mostrarAsignar" class="modal-backdrop fade show" @click="mostrarAsignar = false"></div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { getSalaCultivadores, asignarCultivador, desasignarCultivador, listUsers } from '../lib/api.js'

const props = defineProps({
  salaId:     { type: Number, required: true },
  salaNombre: { type: String, default: '' }
})

const emit = defineEmits(['actualizado'])

const auth           = useAuthStore()
const cultivadores   = ref([])
const todosUsuarios  = ref([])
const loading        = ref(false)
const mostrarAsignar = ref(false)
const userSeleccionado = ref('')
const asignando      = ref(false)
const errorAsignar   = ref('')

const puedeEditar = computed(() =>
  auth.user?.role === 'admin'
)

// Solo mostrar cultivadores que no están ya asignados a esta sala
const cultivadoresDisponibles = computed(() => {
  const asignadosIds = new Set(cultivadores.value.map(c => c.id))
  return todosUsuarios.value.filter(u =>
    u.role === 'cultivador' && !asignadosIds.has(u.id)
  )
})

onMounted(async () => {
  await cargar()
  if (puedeEditar.value) {
    const res = await listUsers()
    todosUsuarios.value = res.data?.data || res.data || []
  }
})

async function cargar() {
  loading.value = true
  try {
    const res = await getSalaCultivadores(props.salaId)
    cultivadores.value = res.data || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

async function asignar() {
  if (!userSeleccionado.value) return
  asignando.value  = true
  errorAsignar.value = ''
  try {
    await asignarCultivador(props.salaId, userSeleccionado.value)
    mostrarAsignar.value = false
    userSeleccionado.value = ''
    await cargar()
    emit('actualizado')
  } catch (e) {
    errorAsignar.value = e.response?.data?.error || 'Error al asignar'
  } finally {
    asignando.value = false
  }
}

async function desasignar(cultivador) {
  if (!confirm(`¿Desasignar a ${cultivador.nombre_completo} de esta sala?`)) return
  try {
    await desasignarCultivador(props.salaId, cultivador.id)
    await cargar()
    emit('actualizado')
  } catch (e) {
    console.error(e)
  }
}

function iniciales(nombre) {
  if (!nombre) return '?'
  return nombre.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase()
}
</script>

<style scoped>
.cultivadores-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.cultivador-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 10px;
  border-radius: 8px;
  background: var(--bs-tertiary-bg, #f8f9fa);
  border: 1px solid var(--bs-border-color);
}

.cultivador-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(135deg, #198754, #0d6efd);
  color: white;
  font-size: 0.7rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.btn-ghost {
  background: transparent;
  border: none;
  padding: 4px 6px;
}
</style>
