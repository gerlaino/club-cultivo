<script setup>
import { onMounted, ref, computed } from 'vue'
import { useAmbienteStore } from '../stores/ambiente.js'
import { useToast } from '../composables/useToast.js'
import DispositivoCard from '../components/ambiente/DispositivoCard.vue'

const store = useAmbienteStore()
const toast = useToast()

const loading     = ref(false)
const showForm    = ref(false)
const guardando   = ref(false)
const form        = ref(emptyForm())
const formError   = ref(null)

function emptyForm() {
  return { nombre: '', protocolo: 'http', sala_id: '', descripcion: '' }
}

onMounted(async () => {
  loading.value = true
  await store.cargarDispositivos()
  loading.value = false
})

async function guardar() {
  if (!form.value.nombre) { formError.value = 'El nombre es obligatorio'; return }
  guardando.value = true
  formError.value = null
  try {
    const payload = { ...form.value }
    if (!payload.sala_id) delete payload.sala_id
    await store.createDispositivo(payload)
    toast.success('Dispositivo creado')
    showForm.value = false
    form.value = emptyForm()
  } catch (e) {
    formError.value = e?.response?.data?.errors?.[0] || 'Error al crear'
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div class="dv">
    <!-- Header -->
    <div class="dv__header">
      <div>
        <h1 class="dv__title">📡 Dispositivos IoT</h1>
        <p class="dv__sub">Sensores y dispositivos conectados al módulo ambiente.</p>
      </div>
      <button class="dv__btn-primary" @click="showForm = !showForm">
        <i class="bi bi-plus-lg"></i> Nuevo dispositivo
      </button>
    </div>

    <!-- Formulario -->
    <div v-if="showForm" class="dv__form-card">
      <div class="dv__form-title">Nuevo dispositivo</div>
      <div v-if="formError" class="dv__alert">{{ formError }}</div>
      <div class="dv__form-grid">
        <div class="dv__field">
          <label class="dv__label">Nombre <span class="dv__req">*</span></label>
          <input class="dv__input" v-model="form.nombre" placeholder="Ej: Sensor Sala 1" />
        </div>
        <div class="dv__field">
          <label class="dv__label">Protocolo</label>
          <select class="dv__input" v-model="form.protocolo">
            <option value="http">HTTP webhook</option>
            <option value="mqtt">MQTT</option>
          </select>
        </div>
        <div class="dv__field dv__field--full">
          <label class="dv__label">Descripción</label>
          <input class="dv__input" v-model="form.descripcion" placeholder="Opcional…" />
        </div>
      </div>
      <div class="dv__form-actions">
        <button class="dv__btn-ghost" @click="showForm = false; form = emptyForm()">Cancelar</button>
        <button class="dv__btn-primary" :disabled="guardando" @click="guardar">
          {{ guardando ? 'Guardando…' : 'Crear dispositivo' }}
        </button>
      </div>
    </div>

    <!-- Lista -->
    <div v-if="loading" class="dv__loading">Cargando dispositivos…</div>
    <div v-else-if="!store.dispositivos.length" class="dv__empty">
      <div class="dv__empty-icon">📡</div>
      <div class="dv__empty-title">Sin dispositivos todavía</div>
      <div class="dv__empty-sub">Registrá el primer sensor o dispositivo IoT.</div>
    </div>
    <div v-else class="dv__grid">
      <DispositivoCard
        v-for="d in store.dispositivos"
        :key="d.id"
        :dispositivo="d"
        @deleted="store.cargarDispositivos()"
      />
    </div>
  </div>
</template>

<style scoped>
.dv { padding: 1.75rem 1.5rem; max-width: 1000px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; }
@media (max-width: 640px) { .dv { padding: 1rem; } }

.dv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.dv__title { font-size: 1.6rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.dv__sub { font-size: .82rem; color: #60725d; margin: .25rem 0 0; }

.dv__form-card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.25rem; margin-bottom: 1.5rem; }
.dv__form-title { font-size: .9rem; font-weight: 700; margin-bottom: 1rem; }
.dv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 480px) { .dv__form-grid { grid-template-columns: 1fr; } }
.dv__field { display: flex; flex-direction: column; gap: .3rem; }
.dv__field--full { grid-column: 1/-1; }
.dv__label { font-size: .75rem; font-weight: 600; color: #374151; }
.dv__req { color: #dc2626; }
.dv__input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px;
  padding: .55rem .75rem; font-size: .875rem; color: #1a1a1a;
  width: 100%; box-sizing: border-box;
}
.dv__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.dv__form-actions { display: flex; justify-content: flex-end; gap: .6rem; margin-top: 1rem; }
.dv__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .6rem .9rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }

.dv__loading { padding: 3rem; text-align: center; color: #94a3b8; font-size: .875rem; }
.dv__empty { text-align: center; padding: 4rem 1rem; }
.dv__empty-icon { font-size: 3rem; margin-bottom: .75rem; }
.dv__empty-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin-bottom: .35rem; }
.dv__empty-sub { font-size: .82rem; color: #94a3b8; }

.dv__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; }

.dv__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer;
}
.dv__btn-primary:hover:not(:disabled) { background: #104417; }
.dv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.dv__btn-ghost {
  background: transparent; color: #60725d; border: 1px solid #d4e6d4;
  padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem;
  font-weight: 500; cursor: pointer; transition: all .15s;
}
.dv__btn-ghost:hover { background: #f0fdf4; }
</style>
