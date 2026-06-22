<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { usePacientesStore } from '../stores/pacientes'
import { useClubStore } from '../stores/club'
import { enviarMailPaciente } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'

const router = useRouter()
const store  = usePacientesStore()
const club   = useClubStore()

const sendWelcomeMail = ref(false)
const formError       = ref(null)
const formErrors      = ref({})
const todayISO        = new Date().toLocaleDateString('en-CA') // yyyy-mm-dd local

const form = ref({
  nombre:               '',
  apellido:             '',
  dni:                  '',
  fecha_nacimiento:     '',
  telefono:             '',
  email:                '',
  domicilio_calle:      '',
  domicilio_altura:     '',
  domicilio_piso:       '',
  domicilio_depto:      '',
  domicilio_barrio:     '',
  domicilio_ciudad:     '',
  envio_calle:          '',
  envio_altura:         '',
  envio_piso:           '',
  envio_depto:          '',
  envio_barrio:         '',
  envio_ciudad:         '',
  reprocann_numero:     '',
  reprocann_vencimiento:'',
  reprocann_estado:     'sin_registro',
  es_paciente:          true,
})

const REPROCANN_ESTADOS = [
  { value: 'sin_registro', label: 'Sin registro',         color: '#94a3b8', bg: '#f8fafc' },
  { value: 'pendiente',    label: 'Pendiente aprobación', color: '#b45309', bg: '#fffbeb' },
  { value: 'activo',       label: 'Activo',               color: '#15803d', bg: '#f0fdf4' },
  { value: 'inactivo',     label: 'Inactivo',             color: '#dc2626', bg: '#fef2f2' },
]

const reprocannVencimientoSugerido = computed(() => {
  const d = new Date()
  d.setFullYear(d.getFullYear() + 3)
  return d.toISOString().slice(0, 10)
})

function sugerirVencimiento() {
  if (!form.value.reprocann_vencimiento && form.value.reprocann_numero) {
    form.value.reprocann_vencimiento = reprocannVencimientoSugerido.value
  }
}

function validate() {
  const e = {}
  if (!form.value.nombre.trim())    e.nombre          = 'Requerido'
  if (!form.value.apellido.trim())  e.apellido         = 'Requerido'
  if (!form.value.dni.trim())       e.dni              = 'Requerido'
  if (form.value.dni && !/^\d{7,9}$/.test(form.value.dni.replace(/\D/g, '')))
    e.dni = 'DNI inválido (7 a 9 dígitos)'
  if (!form.value.fecha_nacimiento) e.fecha_nacimiento = 'Requerida'
  if (form.value.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email))
    e.email = 'Email inválido'
  if (!form.value.domicilio_calle.trim()) e.domicilio_calle = 'Requerida'
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

    if (sendWelcomeMail.value && socio.email) {
      const clubNombre = club.data?.name || ''
      await enviarMailPaciente(socio.id, {
        tipo:   'bienvenida',
        asunto: `Bienvenido/a a ${clubNombre}`,
        cuerpo: `Hola ${socio.nombre},\n\nTe damos la bienvenida como paciente de ${clubNombre}.\n\nEstamos a tu disposición para cualquier consulta.\n\nSaludos,`,
      }).catch(() => {})
    }

    router.push({ name: 'paciente-detail', params: { id: socio.id } })
  } catch (e) {
    if (e.response?.status === 402) {
      formError.value = e.response.data?.mensaje || 'Límite del plan alcanzado. Contactá al equipo para actualizar.'
    } else {
      formError.value = store.error || 'Error al crear el paciente'
    }
  }
}
</script>

<template>
  <div class="snv">

    <div class="snv__header">
      <RouterLink to="/pacientes" class="snv__back">
        <i class="bi bi-arrow-left"></i> Pacientes
      </RouterLink>
      <h1 class="snv__title">Nuevo paciente</h1>
      <p class="snv__subtitle">Completá los datos básicos — podés agregar más información desde el perfil del paciente</p>
    </div>

    <div v-if="formError" class="snv__alert">
      <i class="bi bi-exclamation-triangle-fill"></i>
      {{ formError }}
    </div>

    <div class="snv__form">

      <!-- ── Datos personales ── -->
      <div class="snv__section">
        <div class="snv__section-header">
          <div class="snv__section-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
            <i class="bi bi-person-vcard"></i>
          </div>
          <div>
            <div class="snv__section-title">Datos personales</div>
            <div class="snv__section-sub">Información de identidad</div>
          </div>
        </div>

        <div class="snv__grid snv__grid--2">
          <div class="snv__field">
            <label class="snv__label">Nombre <span class="snv__req">*</span></label>
            <input v-model.trim="form.nombre" class="snv__input" :class="{ 'snv__input--err': formErrors.nombre }"
              placeholder="Ej: Juan Martín" autofocus />
            <span v-if="formErrors.nombre" class="snv__err">{{ formErrors.nombre }}</span>
          </div>
          <div class="snv__field">
            <label class="snv__label">Apellido <span class="snv__req">*</span></label>
            <input v-model.trim="form.apellido" class="snv__input" :class="{ 'snv__input--err': formErrors.apellido }"
              placeholder="Ej: García" />
            <span v-if="formErrors.apellido" class="snv__err">{{ formErrors.apellido }}</span>
          </div>
          <div class="snv__field">
            <label class="snv__label">DNI <span class="snv__req">*</span></label>
            <input v-model.trim="form.dni" class="snv__input" :class="{ 'snv__input--err': formErrors.dni }"
              placeholder="Sin puntos" />
            <span v-if="formErrors.dni" class="snv__err">{{ formErrors.dni }}</span>
          </div>
          <div class="snv__field">
            <label class="snv__label">Fecha de nacimiento <span class="snv__req">*</span></label>
            <AppDatePicker v-model="form.fecha_nacimiento" :max="todayISO" />
            <span v-if="formErrors.fecha_nacimiento" class="snv__err">{{ formErrors.fecha_nacimiento }}</span>
          </div>
          <div class="snv__field">
            <label class="snv__label">Teléfono</label>
            <input v-model.trim="form.telefono" class="snv__input" placeholder="+54 9 11 1234-5678" />
          </div>
          <div class="snv__field">
            <label class="snv__label">Email</label>
            <input v-model.trim="form.email" type="email" class="snv__input"
              :class="{ 'snv__input--err': formErrors.email }" placeholder="paciente@email.com" />
            <span v-if="formErrors.email" class="snv__err">{{ formErrors.email }}</span>
          </div>
        </div>
      </div>

      <!-- ── Domicilio ── -->
      <div class="snv__section">
        <div class="snv__section-header">
          <div class="snv__section-icon" style="background:rgba(180,83,9,.1);color:#b45309">
            <i class="bi bi-geo-alt"></i>
          </div>
          <div>
            <div class="snv__section-title">Domicilio del paciente</div>
            <div class="snv__section-sub">Dirección del paciente · se usa como entrega por defecto</div>
          </div>
        </div>

        <div class="snv__grid snv__grid--2">
          <div class="snv__field">
            <label class="snv__label">Calle <span class="snv__req">*</span></label>
            <input v-model.trim="form.domicilio_calle" class="snv__input" :class="{ 'snv__input--err': formErrors.domicilio_calle }" placeholder="Ej: Av. Corrientes" />
            <span v-if="formErrors.domicilio_calle" class="snv__err">{{ formErrors.domicilio_calle }}</span>
          </div>
          <div class="snv__field">
            <label class="snv__label">Altura</label>
            <input v-model.trim="form.domicilio_altura" class="snv__input" placeholder="Ej: 1234" />
          </div>
          <div class="snv__field">
            <label class="snv__label">Piso</label>
            <input v-model.trim="form.domicilio_piso" class="snv__input" placeholder="Ej: 3" />
          </div>
          <div class="snv__field">
            <label class="snv__label">Depto</label>
            <input v-model.trim="form.domicilio_depto" class="snv__input" placeholder="Ej: B" />
          </div>
          <div class="snv__field">
            <label class="snv__label">Barrio</label>
            <input v-model.trim="form.domicilio_barrio" class="snv__input" placeholder="Ej: Almagro" />
          </div>
          <div class="snv__field">
            <label class="snv__label">Ciudad</label>
            <input v-model.trim="form.domicilio_ciudad" class="snv__input" placeholder="Ej: CABA" />
          </div>
        </div>

        <!-- Dirección de entrega (opcional, si es distinta del domicilio) -->
        <details class="snv__envio">
          <summary class="snv__envio-sum">Dirección de entrega distinta <span class="snv__opt">opcional</span></summary>
          <div class="snv__grid snv__grid--2" style="margin-top:.75rem">
            <div class="snv__field">
              <label class="snv__label">Calle</label>
              <input v-model.trim="form.envio_calle" class="snv__input" placeholder="Calle de entrega" />
            </div>
            <div class="snv__field">
              <label class="snv__label">Altura</label>
              <input v-model.trim="form.envio_altura" class="snv__input" placeholder="Altura" />
            </div>
            <div class="snv__field">
              <label class="snv__label">Piso</label>
              <input v-model.trim="form.envio_piso" class="snv__input" placeholder="Piso" />
            </div>
            <div class="snv__field">
              <label class="snv__label">Depto</label>
              <input v-model.trim="form.envio_depto" class="snv__input" placeholder="Depto" />
            </div>
            <div class="snv__field">
              <label class="snv__label">Barrio</label>
              <input v-model.trim="form.envio_barrio" class="snv__input" placeholder="Barrio" />
            </div>
            <div class="snv__field">
              <label class="snv__label">Ciudad</label>
              <input v-model.trim="form.envio_ciudad" class="snv__input" placeholder="Ciudad" />
            </div>
          </div>
        </details>
      </div>

      <!-- ── REPROCANN ── -->
      <div class="snv__section">
        <div class="snv__section-header">
          <div class="snv__section-icon" style="background:rgba(21,128,61,.1);color:#15803d">
            <i class="bi bi-patch-check-fill"></i>
          </div>
          <div>
            <div class="snv__section-title">Autorización REPROCANN</div>
            <div class="snv__section-sub">Res. 1780/2025 — vigencia 3 años desde emisión</div>
          </div>
        </div>

        <div class="snv__field" style="margin-bottom:1rem">
          <label class="snv__label">Estado del certificado</label>
          <div class="snv__repro-estados">
            <button
              v-for="opt in REPROCANN_ESTADOS" :key="opt.value"
              type="button"
              class="snv__repro-btn"
              :class="{ 'snv__repro-btn--active': form.reprocann_estado === opt.value }"
              :style="form.reprocann_estado === opt.value ? { background: opt.bg, borderColor: opt.color, color: opt.color } : {}"
              @click="form.reprocann_estado = opt.value"
            >{{ opt.label }}</button>
          </div>
        </div>

        <div class="snv__grid snv__grid--2">
          <div class="snv__field">
            <label class="snv__label">Número de certificado</label>
            <input v-model.trim="form.reprocann_numero" class="snv__input"
              placeholder="Ej: REP-2024-001234" @input="sugerirVencimiento" />
            <span class="snv__hint">Número asignado por ANMAT al emisor</span>
          </div>
          <div class="snv__field">
            <label class="snv__label">Fecha de vencimiento</label>
            <AppDatePicker v-model="form.reprocann_vencimiento" />
            <span class="snv__hint">El sistema alertará a 90, 60 y 30 días</span>
          </div>
        </div>

        <div class="snv__infobox">
          <i class="bi bi-info-circle-fill snv__infobox-icon"></i>
          <div class="snv__infobox-text">
            Sin REPROCANN activo el paciente no podrá recibir dispensaciones.
            Podés completar o actualizar el certificado desde el perfil del paciente.
          </div>
        </div>
      </div>

      <!-- ── Estado clínico ── -->
      <div class="snv__section">
        <div class="snv__section-header">
          <div class="snv__section-icon" style="background:rgba(124,58,237,.1);color:#7c3aed">
            <i class="bi bi-heart-pulse"></i>
          </div>
          <div>
            <div class="snv__section-title">Estado clínico</div>
            <div class="snv__section-sub">Configuración del tratamiento activo</div>
          </div>
        </div>

        <label class="snv__toggle">
          <input v-model="form.es_paciente" type="checkbox" class="snv__toggle__input" />
          <div class="snv__toggle__track">
            <div class="snv__toggle__thumb"></div>
          </div>
          <div>
            <div class="snv__toggle__label">Paciente activo en tratamiento</div>
            <div class="snv__toggle__hint">
              Activá para incluirlo en el panel de seguimiento y habilitarlo para dispensaciones
            </div>
          </div>
        </label>
      </div>

      <!-- ── Mail de bienvenida ── -->
      <label class="snv__welcome-mail" :class="{ 'snv__welcome-mail--disabled': !form.email }">
        <div class="snv__welcome-mail-check">
          <input v-model="sendWelcomeMail" type="checkbox" class="snv__welcome-mail-input" :disabled="!form.email" />
          <div class="snv__welcome-mail-box">
            <i v-if="sendWelcomeMail && form.email" class="bi bi-check2" style="font-size:.75rem;line-height:1"></i>
          </div>
        </div>
        <div class="snv__welcome-mail-text">
          <span class="snv__welcome-mail-label">Enviar mail de bienvenida al crear</span>
          <span class="snv__welcome-mail-hint">{{ form.email ? form.email : 'Requiere email del paciente' }}</span>
        </div>
      </label>

      <!-- ── Acciones ── -->
      <div class="snv__actions">
        <RouterLink to="/pacientes" class="snv__btn-ghost">Cancelar</RouterLink>
        <button class="snv__btn-primary" :disabled="store.saving" @click="handleSubmit">
          <DsSpinner v-if="store.saving" :size="16" />
          <i v-else class="bi bi-person-plus-fill"></i>
          {{ store.saving ? 'Creando…' : 'Crear paciente' }}
        </button>
      </div>

    </div>
  </div>
</template>

<style scoped>
.snv {
  padding: 2rem 1.5rem;
  max-width: 700px;
  margin: 0 auto;
}
@media (max-width: 768px) { .snv { padding: 1.25rem 1rem; } }

/* Header */
.snv__header { margin-bottom: 2rem; }
.snv__back {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .8rem; font-weight: 600; color: #64748b;
  text-decoration: none; margin-bottom: .75rem; transition: color .15s;
}
.snv__back:hover { color: #0f172a; }
.snv__title { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0 0 .25rem; letter-spacing: -.03em; line-height: 1.1; }
.snv__subtitle { font-size: .82rem; color: #64748b; margin: 0; line-height: 1.5; }

/* Alert */
.snv__alert {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .875rem 1rem; border-radius: 10px; font-size: .875rem;
  margin-bottom: 1.5rem; display: flex; gap: .5rem; align-items: flex-start;
}

/* Form container */
.snv__form { display: flex; flex-direction: column; gap: 1rem; }

/* Sections */
.snv__section {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  overflow: hidden;
}
.snv__section-header {
  display: flex; align-items: center; gap: .875rem;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid #f1f5f9;
  background: #fafbfc;
}
.snv__section-icon {
  width: 36px; height: 36px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: .9rem; flex-shrink: 0;
}
.snv__section-title { font-size: .88rem; font-weight: 800; color: #0f172a; }
.snv__section-sub   { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }

/* Section body (padding) */
.snv__section > .snv__grid,
.snv__section > .snv__field,
.snv__section > .snv__repro-estados,
.snv__section > .snv__toggle,
.snv__section > .snv__infobox {
  margin: 1.1rem 1.25rem;
}
.snv__section > .snv__field { margin-bottom: 0; }
.snv__section > .snv__infobox { margin-top: .75rem; margin-bottom: 1.1rem; }
.snv__section > .snv__toggle { margin: 1rem 1.25rem; }

/* Grid */
.snv__grid { display: grid; gap: .875rem; }
.snv__grid--2 { grid-template-columns: 1fr 1fr; }
@media (max-width: 540px) { .snv__grid--2 { grid-template-columns: 1fr; } }

/* Fields */
.snv__field { display: flex; flex-direction: column; gap: .3rem; }
.snv__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.snv__req   { color: #dc2626; }
.snv__err   { font-size: .72rem; color: #dc2626; font-weight: 600; }
.snv__opt   { font-size: .72rem; font-weight: 500; color: #94a3b8; }
.snv__envio { margin-top: 1rem; border-top: 1px dashed #e2e8f0; padding-top: .75rem; }
.snv__envio-sum { cursor: pointer; font-size: .85rem; font-weight: 700; color: #b45309; list-style: none; display: flex; align-items: center; gap: .4rem; }
.snv__envio-sum::before { content: '＋'; font-weight: 800; }
.snv__envio[open] .snv__envio-sum::before { content: '−'; }
.snv__hint  { font-size: .7rem; color: #94a3b8; }

.snv__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .875rem; font-size: .9rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s, background .15s;
}
.snv__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.snv__input--err { border-color: #dc2626; }
.snv__input--err:focus { box-shadow: 0 0 0 3px rgba(220,38,38,.1); }

/* REPROCANN estados */
.snv__repro-estados { display: flex; gap: .5rem; flex-wrap: wrap; }
.snv__repro-btn {
  padding: .4rem .85rem; border-radius: 8px;
  border: 1.5px solid #e2e8f0; background: #f8fafc; color: #64748b;
  font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s;
}
.snv__repro-btn:hover { border-color: #94a3b8; color: #374151; }
.snv__repro-btn--active { font-weight: 700; }

/* Infobox */
.snv__infobox {
  display: flex; gap: .6rem; padding: .75rem .9rem;
  background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 10px;
}
.snv__infobox-icon { color: #0369a1; font-size: .9rem; flex-shrink: 0; margin-top: .15rem; }
.snv__infobox-text { font-size: .75rem; color: #1e40af; line-height: 1.5; }

/* Toggle */
.snv__toggle {
  display: flex; align-items: flex-start; gap: .875rem; cursor: pointer;
  padding: .9rem 1rem; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 10px; transition: border .15s;
}
.snv__toggle:hover { border-color: #1b5e20; }
.snv__toggle__input { display: none; }
.snv__toggle__track {
  width: 44px; height: 24px; background: #cbd5e1; border-radius: 999px;
  position: relative; transition: background .2s; flex-shrink: 0; margin-top: .15rem;
}
.snv__toggle__input:checked + .snv__toggle__track { background: #1b5e20; }
.snv__toggle__thumb {
  position: absolute; width: 18px; height: 18px; background: #fff;
  border-radius: 50%; top: 3px; left: 3px; transition: left .2s;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.snv__toggle__input:checked + .snv__toggle__track .snv__toggle__thumb { left: 22px; }
.snv__toggle__label { font-size: .88rem; font-weight: 700; color: #0f172a; margin-bottom: .25rem; }
.snv__toggle__hint  { font-size: .75rem; color: #64748b; line-height: 1.4; }

/* Mail bienvenida */
.snv__welcome-mail {
  display: flex; align-items: flex-start; gap: .625rem;
  padding: .875rem 1rem; background: #f0fdf4;
  border: 1.5px solid #bbf7d0; border-radius: 12px;
  cursor: pointer; transition: all .15s; user-select: none;
}
.snv__welcome-mail:hover:not(.snv__welcome-mail--disabled) { border-color: #4ade80; }
.snv__welcome-mail--disabled { background: #f8fafc; border-color: #e2e8f0; opacity: .6; cursor: not-allowed; }
.snv__welcome-mail-check { flex-shrink: 0; margin-top: .15rem; }
.snv__welcome-mail-input { display: none; }
.snv__welcome-mail-box {
  width: 18px; height: 18px; border-radius: 5px;
  border: 2px solid #d1d5db; background: #fff;
  display: flex; align-items: center; justify-content: center;
  transition: all .15s; color: #fff;
}
.snv__welcome-mail-input:checked + .snv__welcome-mail-box { background: #1b5e20; border-color: #1b5e20; }
.snv__welcome-mail-text { flex: 1; min-width: 0; }
.snv__welcome-mail-label { display: block; font-size: .85rem; font-weight: 700; color: #14532d; }
.snv__welcome-mail-hint  { display: block; font-size: .72rem; color: #16a34a; margin-top: .1rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.snv__welcome-mail--disabled .snv__welcome-mail-label,
.snv__welcome-mail--disabled .snv__welcome-mail-hint { color: #94a3b8; }

/* Acciones */
.snv__actions {
  display: flex; gap: .75rem; justify-content: flex-end;
  padding-top: .5rem;
}
@media (max-width: 480px) {
  .snv__actions { flex-direction: column-reverse; }
  .snv__btn-primary, .snv__btn-ghost { width: 100%; justify-content: center; }
}

.snv__btn-primary {
  display: inline-flex; align-items: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .8rem 1.5rem; border-radius: 10px;
  font-size: .9rem; font-weight: 700; cursor: pointer; transition: background .15s;
}
.snv__btn-primary:hover:not(:disabled) { background: #144a18; }
.snv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }

.snv__btn-ghost {
  display: inline-flex; align-items: center; justify-content: center;
  background: transparent; color: #64748b;
  border: 1.5px solid #e2e8f0; padding: .8rem 1.25rem; border-radius: 10px;
  font-size: .875rem; font-weight: 600; cursor: pointer;
  text-decoration: none; transition: all .15s;
}
.snv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
</style>
