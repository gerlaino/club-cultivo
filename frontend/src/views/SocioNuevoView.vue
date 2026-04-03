<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useSociosStore } from '../stores/socios'

const router = useRouter()
const store  = useSociosStore()

const formError  = ref(null)
const formErrors = ref({})

const form = ref({
  nombre:                '',
  apellido:              '',
  dni:                   '',
  fecha_nacimiento:      '',
  telefono:              '',
  email:                 '',
  reprocann_numero:      '',
  reprocann_vencimiento: '',
  es_paciente:           true,
})

// Auto-calcular vencimiento REPROCANN: 3 años desde hoy si no se carga
const reprocannVencimientoSugerido = computed(() => {
  const d = new Date()
  d.setFullYear(d.getFullYear() + 3)
  return d.toISOString().slice(0, 10)
})

function validate() {
  const e = {}
  if (!form.value.nombre.trim())    e.nombre           = 'Requerido'
  if (!form.value.apellido.trim())   e.apellido          = 'Requerido'
  if (!form.value.dni.trim())        e.dni               = 'Requerido'
  if (form.value.dni && !/^\d{7,9}$/.test(form.value.dni.replace(/\D/g, '')))
    e.dni = 'DNI inválido (7 a 9 dígitos)'
  if (!form.value.fecha_nacimiento)  e.fecha_nacimiento  = 'Requerida'
  if (form.value.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email))
    e.email = 'Email inválido'
  formErrors.value = e
  return !Object.keys(e).length
}

async function handleSubmit() {
  if (!validate()) return
  formError.value = null
  try {
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => { if (payload[k] === '') delete payload[k] })
    const socio = await store.create(payload)
    router.push({ name: 'socio-detail', params: { id: socio.id } })
  } catch {
    formError.value = store.error || 'Error al crear el paciente'
  }
}

function sugerirVencimiento() {
  if (!form.value.reprocann_vencimiento && form.value.reprocann_numero) {
    form.value.reprocann_vencimiento = reprocannVencimientoSugerido.value
  }
}
</script>

<template>
  <div class="snv">

    <!-- Header -->
    <div class="snv__header">
      <div class="snv__header-left">
        <RouterLink to="/socios" class="snv__back">
          <i class="bi bi-arrow-left"></i>
          Pacientes
        </RouterLink>
        <h1 class="snv__title">Nuevo paciente</h1>
        <p class="snv__subtitle">Completá el expediente clínico del paciente</p>
      </div>
    </div>

    <!-- Error global -->
    <div v-if="formError" class="snv__alert">
      <i class="bi bi-exclamation-triangle-fill"></i>
      {{ formError }}
    </div>

    <div class="snv__layout">

      <!-- ── Columna principal ────────────────────────────── -->
      <div class="snv__main">

        <!-- Datos personales -->
        <div class="snv__card">
          <div class="snv__card-header">
            <div class="snv__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
              <i class="bi bi-person-vcard"></i>
            </div>
            <div>
              <div class="snv__card-title">Datos personales</div>
              <div class="snv__card-sub">Información de identidad del paciente</div>
            </div>
          </div>
          <div class="snv__card-body">
            <div class="snv__grid snv__grid--3">
              <div class="snv__field snv__field--2">
                <label class="snv__label">Nombre <span class="snv__req">*</span></label>
                <input
                  v-model.trim="form.nombre"
                  class="snv__input"
                  :class="{ 'snv__input--err': formErrors.nombre }"
                  placeholder="Ej: Juan Martín"
                  autofocus
                />
                <span v-if="formErrors.nombre" class="snv__err">{{ formErrors.nombre }}</span>
              </div>
              <div class="snv__field snv__field--2">
                <label class="snv__label">Apellido <span class="snv__req">*</span></label>
                <input
                  v-model.trim="form.apellido"
                  class="snv__input"
                  :class="{ 'snv__input--err': formErrors.apellido }"
                  placeholder="Ej: García"
                />
                <span v-if="formErrors.apellido" class="snv__err">{{ formErrors.apellido }}</span>
              </div>
              <div class="snv__field">
                <label class="snv__label">DNI <span class="snv__req">*</span></label>
                <input
                  v-model.trim="form.dni"
                  class="snv__input"
                  :class="{ 'snv__input--err': formErrors.dni }"
                  placeholder="Sin puntos"
                />
                <span v-if="formErrors.dni" class="snv__err">{{ formErrors.dni }}</span>
              </div>
              <div class="snv__field">
                <label class="snv__label">Fecha de nacimiento <span class="snv__req">*</span></label>
                <input
                  v-model="form.fecha_nacimiento"
                  type="date"
                  class="snv__input"
                  :class="{ 'snv__input--err': formErrors.fecha_nacimiento }"
                />
                <span v-if="formErrors.fecha_nacimiento" class="snv__err">{{ formErrors.fecha_nacimiento }}</span>
              </div>
              <div class="snv__field">
                <label class="snv__label">Teléfono</label>
                <input
                  v-model.trim="form.telefono"
                  class="snv__input"
                  placeholder="+54 9 11 1234-5678"
                />
              </div>
              <div class="snv__field snv__field--3">
                <label class="snv__label">Email</label>
                <input
                  v-model.trim="form.email"
                  type="email"
                  class="snv__input"
                  :class="{ 'snv__input--err': formErrors.email }"
                  placeholder="paciente@email.com"
                />
                <span v-if="formErrors.email" class="snv__err">{{ formErrors.email }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Autorización REPROCANN -->
        <div class="snv__card snv__card--mt">
          <div class="snv__card-header">
            <div class="snv__card-icon" style="background:rgba(21,128,61,.1);color:#15803d">
              <i class="bi bi-patch-check-fill"></i>
            </div>
            <div>
              <div class="snv__card-title">Autorización REPROCANN</div>
              <div class="snv__card-sub">Res. 1780/2025 — vigencia 3 años desde emisión</div>
            </div>
          </div>
          <div class="snv__card-body">
            <div class="snv__grid snv__grid--2">
              <div class="snv__field">
                <label class="snv__label">Número de certificado</label>
                <input
                  v-model.trim="form.reprocann_numero"
                  class="snv__input"
                  placeholder="Ej: REP-2024-001234"
                  @input="sugerirVencimiento"
                />
                <span class="snv__hint">Número asignado por ANMAT al emisor</span>
              </div>
              <div class="snv__field">
                <label class="snv__label">Fecha de vencimiento</label>
                <input
                  v-model="form.reprocann_vencimiento"
                  type="date"
                  class="snv__input"
                />
                <span class="snv__hint">Sistema alertará a 90, 60 y 30 días del vencimiento</span>
              </div>
            </div>

            <!-- Info box -->
            <div class="snv__infobox">
              <i class="bi bi-info-circle-fill snv__infobox-icon"></i>
              <div class="snv__infobox-text">
                El REPROCANN es requisito para dispensar cannabis medicinal. Sin número cargado,
                el paciente aparecerá como "Sin REPROCANN" en el sistema y no podrá recibir dispensaciones.
              </div>
            </div>
          </div>
        </div>

        <!-- Estado clínico -->
        <div class="snv__card snv__card--mt">
          <div class="snv__card-header">
            <div class="snv__card-icon" style="background:rgba(124,58,237,.1);color:#7c3aed">
              <i class="bi bi-heart-pulse"></i>
            </div>
            <div>
              <div class="snv__card-title">Estado clínico</div>
              <div class="snv__card-sub">Configuración del tratamiento activo</div>
            </div>
          </div>
          <div class="snv__card-body">
            <label class="snv__toggle">
              <input v-model="form.es_paciente" type="checkbox" class="snv__toggle__input" />
              <div class="snv__toggle__track">
                <div class="snv__toggle__thumb"></div>
              </div>
              <div>
                <div class="snv__toggle__label">Paciente activo en tratamiento</div>
                <div class="snv__toggle__hint">
                  Activá esta opción para incluirlo en el panel de seguimiento, alertas de vencimiento
                  y habilitarlo para recibir dispensaciones
                </div>
              </div>
            </label>
          </div>
        </div>

      </div>

      <!-- ── Aside ────────────────────────────────────────── -->
      <div class="snv__aside">

        <!-- Resumen -->
        <div class="snv__summary">
          <div class="snv__summary-header">Resumen del paciente</div>
          <div class="snv__summary-avatar">
            {{ (form.nombre?.[0] || '?') }}{{ (form.apellido?.[0] || '') }}
          </div>
          <div class="snv__summary-nombre">
            {{ form.nombre || '—' }} {{ form.apellido }}
          </div>
          <div class="snv__summary-dni">
            {{ form.dni ? 'DNI ' + form.dni : 'Sin DNI' }}
          </div>

          <div class="snv__summary-items">
            <div class="snv__summary-item">
              <span class="snv__summary-key">Nacimiento</span>
              <span class="snv__summary-val">{{ form.fecha_nacimiento || '—' }}</span>
            </div>
            <div class="snv__summary-item">
              <span class="snv__summary-key">REPROCANN</span>
              <span class="snv__summary-val" :style="form.reprocann_numero ? 'color:#15803d;font-weight:600' : ''">
                {{ form.reprocann_numero || 'Sin número' }}
              </span>
            </div>
            <div class="snv__summary-item">
              <span class="snv__summary-key">Estado</span>
              <span class="snv__summary-val" :style="form.es_paciente ? 'color:#15803d;font-weight:600' : 'color:#94a3b8'">
                {{ form.es_paciente ? 'Activo' : 'Inactivo' }}
              </span>
            </div>
          </div>
        </div>

        <!-- Acciones -->
        <div class="snv__actions">
          <button
            class="snv__btn-primary"
            :disabled="store.saving"
            @click="handleSubmit"
          >
            <span v-if="store.saving" class="snv__spinner"></span>
            <i v-else class="bi bi-person-plus-fill"></i>
            {{ store.saving ? 'Creando paciente…' : 'Crear paciente' }}
          </button>
          <RouterLink to="/socios" class="snv__btn-ghost">
            Cancelar
          </RouterLink>
        </div>

        <!-- Nota legal -->
        <div class="snv__legal">
          <i class="bi bi-shield-check snv__legal-icon"></i>
          <p class="snv__legal-text">
            Los datos del paciente se almacenan de forma segura y son de uso exclusivo
            del club. El acceso está restringido al equipo médico autorizado.
          </p>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.snv {
  padding: 2rem 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
}
@media (max-width: 768px) { .snv { padding: 1.25rem 1rem; } }

/* Header */
.snv__header { margin-bottom: 2rem; }
.snv__back {
  display: inline-flex;
  align-items: center;
  gap: .4rem;
  font-size: .8rem;
  font-weight: 600;
  color: #64748b;
  text-decoration: none;
  margin-bottom: .75rem;
  transition: color .15s;
}
.snv__back:hover { color: #0f172a; }
.snv__title {
  font-size: 2rem;
  font-weight: 800;
  color: #0f172a;
  margin: 0 0 .25rem;
  letter-spacing: -.04em;
  line-height: 1;
}
.snv__subtitle { font-size: .875rem; color: #64748b; margin: 0; }

/* Alert */
.snv__alert {
  background: #fef2f2;
  border: 1px solid #fecaca;
  color: #dc2626;
  padding: .875rem 1rem;
  border-radius: 10px;
  font-size: .875rem;
  margin-bottom: 1.5rem;
  display: flex;
  gap: .5rem;
  align-items: flex-start;
}

/* Layout */
.snv__layout {
  display: grid;
  grid-template-columns: 1fr 280px;
  gap: 1.5rem;
  align-items: start;
}
@media (max-width: 900px) {
  .snv__layout { grid-template-columns: 1fr; }
  .snv__aside { order: -1; }
}

/* Cards */
.snv__card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  overflow: hidden;
}
.snv__card--mt { margin-top: 1.25rem; }
.snv__card-header {
  display: flex;
  align-items: center;
  gap: .875rem;
  padding: 1.1rem 1.4rem;
  border-bottom: 1px solid #f1f5f9;
  background: #fafbfc;
}
.snv__card-icon {
  width: 38px; height: 38px;
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: .95rem;
  flex-shrink: 0;
}
.snv__card-title { font-size: .9rem; font-weight: 800; color: #0f172a; }
.snv__card-sub   { font-size: .75rem; color: #94a3b8; margin-top: .1rem; }
.snv__card-body  { padding: 1.25rem 1.4rem; }

/* Grid */
.snv__grid {
  display: grid;
  gap: 1rem;
}
.snv__grid--2 { grid-template-columns: 1fr 1fr; }
.snv__grid--3 { grid-template-columns: 1fr 1fr 1fr; }
@media (max-width: 640px) {
  .snv__grid--2,
  .snv__grid--3 { grid-template-columns: 1fr; }
}

/* Field span helpers */
.snv__field--2 { grid-column: span 1; }
.snv__field--3 { grid-column: 1 / -1; }

/* Fields */
.snv__field { display: flex; flex-direction: column; gap: .35rem; }
.snv__label {
  font-size: .78rem;
  font-weight: 700;
  color: #374151;
  text-transform: uppercase;
  letter-spacing: .04em;
}
.snv__req { color: #dc2626; }

.snv__input {
  background: #f8fafc;
  border: 1.5px solid #e2e8f0;
  border-radius: 9px;
  padding: .65rem .9rem;
  font-size: .9rem;
  color: #0f172a;
  width: 100%;
  box-sizing: border-box;
  transition: border .15s, box-shadow .15s, background .15s;
}
.snv__input:focus {
  outline: none;
  border-color: #1b5e20;
  box-shadow: 0 0 0 3px rgba(27,94,32,.1);
  background: #fff;
}
.snv__input--err { border-color: #dc2626; }
.snv__input--err:focus { box-shadow: 0 0 0 3px rgba(220,38,38,.1); }

.snv__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.snv__hint { font-size: .72rem; color: #94a3b8; }

/* Infobox */
.snv__infobox {
  display: flex;
  gap: .75rem;
  padding: .875rem 1rem;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 10px;
  margin-top: 1rem;
}
.snv__infobox-icon { color: #0369a1; font-size: 1rem; flex-shrink: 0; margin-top: .1rem; }
.snv__infobox-text { font-size: .78rem; color: #1e40af; line-height: 1.5; }

/* Toggle */
.snv__toggle {
  display: flex;
  align-items: flex-start;
  gap: .875rem;
  cursor: pointer;
  padding: 1rem 1.1rem;
  background: #f8fafc;
  border: 1.5px solid #e2e8f0;
  border-radius: 10px;
  transition: border .15s;
}
.snv__toggle:hover { border-color: #1b5e20; }
.snv__toggle__input { display: none; }
.snv__toggle__track {
  width: 44px; height: 24px;
  background: #cbd5e1;
  border-radius: 999px;
  position: relative;
  transition: background .2s;
  flex-shrink: 0;
  margin-top: .15rem;
}
.snv__toggle__input:checked + .snv__toggle__track { background: #1b5e20; }
.snv__toggle__thumb {
  position: absolute;
  width: 18px; height: 18px;
  background: #fff;
  border-radius: 50%;
  top: 3px; left: 3px;
  transition: left .2s;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.snv__toggle__input:checked + .snv__toggle__track .snv__toggle__thumb { left: 22px; }
.snv__toggle__label { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .3rem; }
.snv__toggle__hint  { font-size: .78rem; color: #64748b; line-height: 1.5; }

/* Aside */
.snv__aside { display: flex; flex-direction: column; gap: 1rem; }

/* Summary card */
.snv__summary {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 1.4rem;
  text-align: center;
}
.snv__summary-header {
  font-size: .7rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: #94a3b8;
  margin-bottom: 1rem;
}
.snv__summary-avatar {
  width: 64px; height: 64px;
  border-radius: 50%;
  background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15));
  color: #1b5e20;
  font-size: 1.4rem;
  font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto .75rem;
  text-transform: uppercase;
  transition: all .2s;
}
.snv__summary-nombre {
  font-size: 1rem;
  font-weight: 800;
  color: #0f172a;
  margin-bottom: .2rem;
  min-height: 1.4rem;
}
.snv__summary-dni {
  font-size: .78rem;
  color: #94a3b8;
  font-family: monospace;
  margin-bottom: 1rem;
}
.snv__summary-items {
  display: flex;
  flex-direction: column;
  gap: .5rem;
  padding-top: 1rem;
  border-top: 1px solid #f1f5f9;
  text-align: left;
}
.snv__summary-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: .5rem;
}
.snv__summary-key { font-size: .75rem; color: #94a3b8; }
.snv__summary-val { font-size: .78rem; color: #0f172a; font-weight: 600; text-align: right; }

/* Actions */
.snv__actions { display: flex; flex-direction: column; gap: .6rem; }

.snv__btn-primary {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: .5rem;
  width: 100%;
  background: var(--brand-primary, #1b5e20);
  color: #fff;
  border: none;
  padding: .85rem 1.25rem;
  border-radius: 10px;
  font-size: .9rem;
  font-weight: 700;
  cursor: pointer;
  transition: background .15s, transform .1s;
}
.snv__btn-primary:hover:not(:disabled) { background: #144a18; transform: translateY(-1px); }
.snv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }

.snv__btn-ghost {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  background: transparent;
  color: #64748b;
  border: 1.5px solid #e2e8f0;
  padding: .75rem 1.25rem;
  border-radius: 10px;
  font-size: .875rem;
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  transition: all .15s;
  text-align: center;
}
.snv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }

/* Spinner */
.snv__spinner {
  width: 16px; height: 16px;
  border: 2px solid rgba(255,255,255,.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: snv-spin .6s linear infinite;
}
@keyframes snv-spin { to { transform: rotate(360deg); } }

/* Legal note */
.snv__legal {
  display: flex;
  gap: .6rem;
  padding: .875rem 1rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
}
.snv__legal-icon { color: #94a3b8; font-size: .9rem; flex-shrink: 0; margin-top: .1rem; }
.snv__legal-text { font-size: .72rem; color: #94a3b8; margin: 0; line-height: 1.5; }
</style>
