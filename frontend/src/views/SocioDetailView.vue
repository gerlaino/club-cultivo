<!-- src/views/SocioDetailView.vue -->
<script setup>
import { ref, onMounted, computed } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useSociosStore } from "../stores/socios"
import IndicacionesMedicas from '../components/socios/IndicacionesMedicas.vue'

const route = useRoute()
const router = useRouter()
const store = useSociosStore()

const socioId = Number(route.params.id)
const loading = ref(true)
const error = ref(null)

const notaTexto = ref("")
const notasLoading = computed(() => store.notasLoading)

onMounted(async () => {
  try {
    await store.fetchOne(socioId)
    await store.fetchNotas(socioId)
  } catch (e) {
    error.value = store.error || "No se pudo cargar el paciente."
  } finally {
    loading.value = false
  }
})

async function agregarNota() {
  const txt = notaTexto.value.trim()
  if (!txt) return
  try {
    await store.addNota(socioId, txt)
    notaTexto.value = ""
  } catch (e) {
    // el store ya setea notasError
  }
}

async function borrarNota(n) {
  if (!confirm("¿Eliminar nota?")) return
  try {
    await store.removeNota(n.id)
  } catch (e) {}
}

const s = computed(() => store.current)
</script>

<template>
  <div>
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-outline-secondary btn-sm" @click="router.back()">← Volver</button>
        <h2 class="m-0">{{ s?.nombre }} {{ s?.apellido }}</h2>
      </div>
      <small class="text-muted" v-if="s?.updated_at">
        Actualizado: {{ new Date(s.updated_at).toLocaleString() }}
      </small>
    </div>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!s" class="alert alert-warning">Paciente no encontrado.</div>

    <div v-else class="row g-3">
      <div class="col-12 col-lg-4">
        <div class="card h-100">
          <div class="card-header fw-semibold">Información</div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">DNI</span><span>{{ s.dni || "—" }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Email</span><span>{{ s.email || "—" }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Teléfono</span><span>{{ s.telefono || s.phone || "—" }}</span>
            </div>
            <div class="d-flex justify-content-between py-1">
              <span class="text-muted">Creado</span><span>{{ new Date(s.created_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Notas -->
      <div class="col-12 col-lg-8">
        <div class="card h-100">
          <div class="card-header d-flex align-items-center justify-content-between">
            <strong>Notas</strong>
          </div>
          <div class="card-body">
            <div class="mb-3">
              <textarea class="form-control" rows="2" placeholder="Agregar nota…" v-model.trim="notaTexto"></textarea>
              <div class="text-end mt-2">
                <button class="btn btn-primary" :disabled="store.creandoNota || !notaTexto" @click="agregarNota">
                  <span v-if="store.creandoNota" class="spinner-border spinner-border-sm me-2"></span>
                  Agregar
                </button>
              </div>
              <div v-if="store.notasError" class="text-danger small mt-1">{{ store.notasError }}</div>
            </div>

            <div v-if="notasLoading" class="alert alert-info">Cargando notas…</div>
            <div v-else-if="store.notas.length === 0" class="text-muted">Sin notas.</div>

            <ul class="list-group" v-else>
              <li v-for="n in store.notas" :key="n.id" class="list-group-item d-flex justify-content-between align-items-start">
                <div>
                  <div class="small text-muted">{{ new Date(n.created_at).toLocaleString() }}</div>
                  <div>{{ n.contenido }}</div>
                </div>
                <button class="btn btn-sm btn-outline-danger" @click="borrarNota(n)">Eliminar</button>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Indicaciones Médicas -->
      <div class="col-12">
        <div class="card">
          <div class="card-body">
            <IndicacionesMedicas :socio-id="s.id" />
          </div>
        </div>
      </div>

    </div>
  </div>
</template>
