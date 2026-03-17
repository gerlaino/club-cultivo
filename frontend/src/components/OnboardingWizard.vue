<script setup>
import { ref, computed } from 'vue'
import { createSede } from '../lib/api.js'
import { useRouter } from 'vue-router'

const router = useRouter()
const emit   = defineEmits(['completado'])

const paso   = ref(1)
const saving = ref(false)
const error  = ref(null)

const sede = ref({
  nombre: '', tipo: 'produccion',
  direccion: '', ciudad: '', provincia: '',
  pais: 'Argentina', declarada_reprocann: false,
})

const TIPOS = {
  produccion: { label: 'Producción',           icon: '🌱', desc: 'Salas de cultivo, lotes y plantas' },
  social:     { label: 'Social / Dispensario', icon: '🏪', desc: 'Atención de pacientes y dispensaciones' },
  mixta:      { label: 'Mixta',                icon: '🔄', desc: 'Producción y dispensación en el mismo lugar' },
}

const pasos = [
  { num: 1, label: 'Sede' },
  { num: 2, label: 'Confirmar' },
]

async function crearSede() {
  if (!sede.value.nombre.trim()) { error.value = 'El nombre es obligatorio'; return }
  saving.value = true
  error.value  = null
  try {
    await createSede(sede.value)
    emit('completado')
    router.push('/salas')
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Error al crear la sede'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="onboarding-overlay">
    <div class="onboarding-card">

      <!-- Logo / Header -->
      <div class="text-center mb-4">
        <div class="onboarding-logo">🌿</div>
        <h2 class="fw-bold mb-1">¡Bienvenido a tu club!</h2>
        <p class="text-muted small">Configuremos todo en unos pasos simples</p>
      </div>

      <!-- Stepper -->
      <div class="d-flex justify-content-center gap-2 mb-4">
        <div v-for="p in pasos" :key="p.num"
             class="step-dot"
             :class="{ 'step-dot--active': paso >= p.num, 'step-dot--done': paso > p.num }"
        >
          <span v-if="paso > p.num">✓</span>
          <span v-else>{{ p.num }}</span>
          <div class="step-dot__label">{{ p.label }}</div>
        </div>
      </div>

      <!-- PASO 1 — Crear sede -->
      <div v-if="paso === 1">
        <h5 class="fw-semibold mb-1">Creá tu primera sede</h5>
        <p class="text-muted small mb-3">
          Una sede es el domicilio físico donde opera el club — puede ser de producción, social, o ambas.
        </p>

        <div v-if="error" class="alert alert-danger small">{{ error }}</div>

        <div class="mb-3">
          <label class="form-label small fw-semibold">Nombre de la sede <span class="text-danger">*</span></label>
          <input v-model.trim="sede.nombre" class="form-control" placeholder="Ej: Sede Principal, Dispensario Centro..." autofocus />
        </div>

        <div class="mb-3">
          <label class="form-label small fw-semibold">Tipo de sede</label>
          <div class="row g-2">
            <div v-for="(meta, key) in TIPOS" :key="key" class="col-12">
              <div class="tipo-btn" :class="{ 'tipo-btn--selected': sede.tipo === key }"
                   @click="sede.tipo = key">
                <span class="fs-4">{{ meta.icon }}</span>
                <div>
                  <div class="fw-semibold small">{{ meta.label }}</div>
                  <div class="text-muted" style="font-size:.75rem">{{ meta.desc }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="row g-2 mb-3">
          <div class="col-12">
            <label class="form-label small fw-semibold">Dirección</label>
            <input v-model.trim="sede.direccion" class="form-control" placeholder="Calle y número" />
          </div>
          <div class="col-6">
            <input v-model.trim="sede.ciudad" class="form-control" placeholder="Ciudad" />
          </div>
          <div class="col-6">
            <input v-model.trim="sede.provincia" class="form-control" placeholder="Provincia" />
          </div>
        </div>

        <div class="form-check form-switch mb-4">
          <input v-model="sede.declarada_reprocann" class="form-check-input" type="checkbox"
                 id="chkRep" role="switch" />
          <label class="form-check-label small" for="chkRep">
            Declarada ante REPROCANN <span class="text-muted">(Res. 1780/2025)</span>
          </label>
        </div>

        <div class="d-flex gap-2">
          <button class="btn btn-success flex-fill" :disabled="saving" @click="paso = 2">
            Continuar <i class="bi bi-arrow-right ms-1"></i>
          </button>
        </div>
      </div>

      <!-- PASO 2 — Confirmar -->
      <div v-if="paso === 2">
        <h5 class="fw-semibold mb-1">Confirmá los datos</h5>
        <p class="text-muted small mb-3">Revisá antes de crear la sede</p>

        <div v-if="error" class="alert alert-danger small">{{ error }}</div>

        <div class="confirm-card mb-4">
          <div class="d-flex align-items-center gap-3 mb-2">
            <span class="fs-3">{{ TIPOS[sede.tipo]?.icon }}</span>
            <div>
              <div class="fw-bold">{{ sede.nombre }}</div>
              <div class="small text-muted">{{ TIPOS[sede.tipo]?.label }}</div>
            </div>
          </div>
          <div v-if="sede.direccion || sede.ciudad" class="small text-muted">
            <i class="bi bi-geo-alt me-1"></i>
            {{ [sede.direccion, sede.ciudad, sede.provincia].filter(Boolean).join(', ') }}
          </div>
          <div v-if="sede.declarada_reprocann" class="small text-success mt-1">
            <i class="bi bi-shield-check me-1"></i>Declarada ante REPROCANN
          </div>
        </div>

        <div class="alert alert-info small mb-4">
          <i class="bi bi-info-circle me-1"></i>
          Después de crear la sede podrás agregar salas, lotes y plantas.
        </div>

        <div class="d-flex gap-2">
          <button class="btn btn-outline-secondary" :disabled="saving" @click="paso = 1">
            <i class="bi bi-arrow-left me-1"></i>Volver
          </button>
          <button class="btn btn-success flex-fill" :disabled="saving" @click="crearSede">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
            <i v-else class="bi bi-check-circle me-1"></i>
            Crear sede y continuar
          </button>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.onboarding-overlay {
  position: fixed; inset: 0;
  background: linear-gradient(135deg, #f0f7f0 0%, #e8f5e9 100%);
  display: flex; align-items: flex-start; justify-content: center;
  overflow-y: auto;
  z-index: 9999; padding: 2rem 1rem;
}
.onboarding-card {
  background: white;
  border-radius: 20px;
  padding: 2rem;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 20px 60px rgba(0,0,0,.12);
}
.onboarding-logo {
  font-size: 3rem; margin-bottom: .5rem;
  animation: float 3s ease-in-out infinite;
}
@keyframes float {
  0%, 100% { transform: translateY(0); }
  50%       { transform: translateY(-8px); }
}

/* Steps */
.step-dot {
  width: 36px; height: 36px; border-radius: 50%;
  background: #e9ecef; color: #6c757d;
  display: flex; align-items: flex-start; justify-content: center; overflow-y: auto;
  font-weight: 700; font-size: .85rem;
  position: relative; transition: all .2s;
}
.step-dot--active { background: #1b5e20; color: white; }
.step-dot--done   { background: #198754; color: white; }
.step-dot__label  {
  position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
  margin-top: 4px; font-size: .65rem; white-space: nowrap; color: #6c757d;
}

/* Tipo buttons */
.tipo-btn {
  border: 2px solid rgba(0,0,0,.08); border-radius: 10px;
  padding: .75rem 1rem; cursor: pointer;
  display: flex; align-items: center; gap: .75rem;
  transition: all .15s;
}
.tipo-btn:hover   { border-color: #1b5e20; }
.tipo-btn--selected { border-color: #1b5e20; background: #f0f7f0; }

/* Confirm */
.confirm-card {
  background: #f8f9fa; border-radius: 12px;
  padding: 1rem; border: 1.5px solid rgba(0,0,0,.06);
}
</style>
