<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Building2, MapPin, Zap, Users, ChevronRight, ChevronLeft, Check, ArrowLeft } from 'lucide-vue-next'
import { createSuperAdminClub } from '../../lib/api.js'

const router = useRouter()

const paso    = ref(1)
const saving  = ref(false)
const error   = ref(null)
const creado  = ref(null)

// ── Form ──────────────────────────────────────────────────────────────
const form = ref({
  name:              '',
  legal_name:        '',
  email:             '',
  phone:             '',
  city:              '',
  state:             '',
  country:           'Argentina',
  timezone:          'America/Argentina/Buenos_Aires',
  plan:              'semilla',
  plan_trial:        true,
  plan_activo_hasta: '',
  features:          {},
})

const PAISES    = ['Argentina', 'Uruguay', 'Colombia', 'España', 'Alemania', 'Canadá', 'Estados Unidos', 'México', 'Chile', 'Brasil', 'Otro']
const TIMEZONES = ['America/Argentina/Buenos_Aires', 'America/Montevideo', 'America/Bogota', 'America/Santiago', 'Europe/Berlin', 'America/Toronto', 'America/New_York']

// ── Plan ──────────────────────────────────────────────────────────────
const PLANES = [
  { value: 'semilla',    label: 'Semilla',    color: '#64748b', bg: '#f1f5f9', desc: '1 sede · 50 plantas · 30 socios' },
  { value: 'brote',      label: 'Brote',      color: '#15803d', bg: '#dcfce7', desc: '2 sedes · 150 plantas · 100 socios' },
  { value: 'cosecha',    label: 'Cosecha',    color: '#0369a1', bg: '#dbeafe', desc: '3 sedes · 250 plantas · ilimitado' },
  { value: 'federacion', label: 'Federación', color: '#7c3aed', bg: '#ede9fe', desc: 'Todo ilimitado — federaciones' },
]

// ── Feature flags ─────────────────────────────────────────────────────
const FEATURE_META = {
  ia_analisis:      { label: 'Análisis IA',      desc: 'IA aplicada a lotes y plantas',  icon: '🔬' },
  ia_voz:           { label: 'Asistente de voz', desc: 'Registro por voz con IA',         icon: '🎙️' },
  web_publica:      { label: 'Web pública',       desc: 'Sitio web del club',              icon: '🌐' },
  mailer:           { label: 'Correo',            desc: 'Emails a socios',                 icon: '✉️' },
  iot:              { label: 'IoT / Sensores',    desc: 'Sensores ambientales',            icon: '📡' },
  alertas:          { label: 'Alertas',           desc: 'Alertas por sala y lote',         icon: '🔔' },
  ariccame:         { label: 'ARICCAME',          desc: 'Reportes ARICCAME',               icon: '📋' },
  cuenta_corriente: { label: 'Cuenta corriente', desc: 'Saldo y movimientos por socio',   icon: '💳' },
  analytics:        { label: 'Analytics',         desc: 'Dashboard analítico avanzado',    icon: '📊' },
  multi_sede:       { label: 'Multi-sede',        desc: 'Múltiples sedes/ubicaciones',     icon: '🏢' },
}
const FEATURES_ORDER = Object.keys(FEATURE_META)

// ── Usuarios ──────────────────────────────────────────────────────────
const ROLES_META = {
  admin:       { label: 'Admin',       desc: 'Acceso total al panel',          required: true },
  medico:      { label: 'Médico',      desc: 'Informes y recetas médicas' },
  cultivador:  { label: 'Cultivador',  desc: 'Salas, lotes y plantas' },
  supervisor:  { label: 'Supervisor',  desc: 'Supervisión general de salas' },
  abogado:     { label: 'Abogado',     desc: 'Documentación y compliance' },
  auditor:     { label: 'Auditor',     desc: 'Auditoría y trazabilidad' },
  dispensador: { label: 'Dispensador', desc: 'Entregas y dispensaciones' },
  manicura:    { label: 'Manicura',    desc: 'Post-cosecha y pesaje' },
}
const rolesSeleccionados = ref(['admin'])
const passwordInicial    = ref('123456Aa')

function toggleRol(rol) {
  if (ROLES_META[rol].required) return
  const idx = rolesSeleccionados.value.indexOf(rol)
  if (idx >= 0) rolesSeleccionados.value.splice(idx, 1)
  else rolesSeleccionados.value.push(rol)
}

// ── Slug preview ──────────────────────────────────────────────────────
const slugPreview = computed(() =>
  form.value.name.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'slug'
)

function emailRol(rol) { return `${rol}@${slugPreview.value}.com` }

// ── Validación ────────────────────────────────────────────────────────
const errores = ref({})

function validarPaso1() {
  const e = {}
  if (!form.value.name.trim())  e.name  = 'El nombre es requerido'
  if (!form.value.email.trim()) e.email = 'El email es requerido'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email)) e.email = 'Email inválido'
  errores.value = e
  return !Object.keys(e).length
}

function siguiente() {
  if (paso.value === 1 && !validarPaso1()) return
  if (paso.value < 3) paso.value++
}
function anterior() { if (paso.value > 1) paso.value-- }

// ── Submit ────────────────────────────────────────────────────────────
async function handleSubmit() {
  saving.value = true
  error.value  = null
  try {
    const club = { ...form.value }
    Object.keys(club).forEach(k => { if (club[k] === '') delete club[k] })
    const { data } = await createSuperAdminClub({
      club,
      roles_a_crear:    rolesSeleccionados.value,
      password_inicial: passwordInicial.value,
    })
    creado.value = data
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'Error al crear el club'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="cnv">

    <!-- Back -->
    <RouterLink :to="{ name: 'sa-clubs' }" class="cnv__back">
      <ArrowLeft :size="14" :stroke-width="2" /> Clubs
    </RouterLink>

    <!-- ══ SUCCESS ══ -->
    <div v-if="creado" class="cnv__success">
      <div class="cnv__success-check"><Check :size="28" :stroke-width="2.5" /></div>
      <h2 class="cnv__success-title">Club creado</h2>
      <p class="cnv__success-sub">
        <strong>{{ creado.club.name }}</strong> está listo.
        Se crearon {{ creado.usuarios.length }} usuario{{ creado.usuarios.length !== 1 ? 's' : '' }}.
      </p>

      <div class="cnv__usuarios-grid">
        <div v-for="u in creado.usuarios" :key="u.id" class="cnv__usuario-card">
          <div class="cnv__usuario-role">{{ u.role }}</div>
          <div class="cnv__usuario-email">{{ u.email }}</div>
        </div>
      </div>

      <div class="cnv__success-actions">
        <RouterLink :to="{ name: 'sa-club-detail', params: { id: creado.club.id } }" class="cnv__btn-primary">
          Ver club
          <ChevronRight :size="16" :stroke-width="2" />
        </RouterLink>
        <button class="cnv__btn-ghost" @click="creado = null; paso = 1">Crear otro</button>
      </div>
    </div>

    <!-- ══ WIZARD ══ -->
    <template v-else>

      <!-- Header + stepper -->
      <div class="cnv__header">
        <h1 class="cnv__title">Nuevo club</h1>
        <div class="cnv__stepper">
          <div
            v-for="n in 3" :key="n"
            class="cnv__step"
            :class="{ 'cnv__step--done': paso > n, 'cnv__step--active': paso === n }"
          >
            <div class="cnv__step-dot">
              <Check v-if="paso > n" :size="12" :stroke-width="3" />
              <span v-else>{{ n }}</span>
            </div>
            <span class="cnv__step-label">{{ ['Identidad', 'Suscripción', 'Acceso'][n - 1] }}</span>
          </div>
          <div class="cnv__step-line" :style="{ width: `${((paso - 1) / 2) * 100}%` }"></div>
        </div>
      </div>

      <!-- ─── Paso 1: Identidad ─── -->
      <div v-if="paso === 1" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico"><Building2 :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Identidad del club</div>
            <div class="cnv__panel-sub">Datos de identificación y contacto</div>
          </div>
        </div>
        <div class="cnv__panel-body">
          <div v-if="Object.keys(errores).length" class="cnv__alert">
            Corregí los campos marcados en rojo antes de continuar.
          </div>
          <div class="cnv__grid">
            <div class="cnv__field cnv__field--full">
              <label class="cnv__label">Nombre del club <span class="cnv__req">*</span></label>
              <input v-model.trim="form.name" class="cnv__input" :class="{ 'cnv__input--err': errores.name }"
                     placeholder="Club Medicinal del Sur" />
              <span v-if="errores.name" class="cnv__err">{{ errores.name }}</span>
              <span v-else class="cnv__hint">Slug: <code>{{ slugPreview }}</code></span>
            </div>
            <div class="cnv__field cnv__field--full">
              <label class="cnv__label">Razón social</label>
              <input v-model.trim="form.legal_name" class="cnv__input"
                     placeholder="Asociación Civil Club Medicinal del Sur" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Email de contacto <span class="cnv__req">*</span></label>
              <input v-model.trim="form.email" type="email" class="cnv__input" :class="{ 'cnv__input--err': errores.email }"
                     placeholder="contacto@clubmedicinal.org" />
              <span v-if="errores.email" class="cnv__err">{{ errores.email }}</span>
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Teléfono</label>
              <input v-model.trim="form.phone" class="cnv__input" placeholder="+54 9 11 1234-5678" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Ciudad</label>
              <input v-model.trim="form.city" class="cnv__input" placeholder="Buenos Aires" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Provincia</label>
              <input v-model.trim="form.state" class="cnv__input" placeholder="CABA" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">País</label>
              <select v-model="form.country" class="cnv__input">
                <option v-for="p in PAISES" :key="p" :value="p">{{ p }}</option>
              </select>
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Zona horaria</label>
              <select v-model="form.timezone" class="cnv__input">
                <option v-for="tz in TIMEZONES" :key="tz" :value="tz">{{ tz }}</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- ─── Paso 2: Suscripción & Features ─── -->
      <div v-if="paso === 2" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--purple"><Zap :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Suscripción & funcionalidades</div>
            <div class="cnv__panel-sub">Plan y módulos habilitados para este club</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <!-- Planes -->
          <div class="cnv__section-label">Plan</div>
          <div class="cnv__planes">
            <button
              v-for="p in PLANES" :key="p.value"
              type="button"
              class="cnv__plan-btn"
              :class="{ 'cnv__plan-btn--active': form.plan === p.value }"
              :style="form.plan === p.value ? { borderColor: p.color, background: p.color + '10', color: p.color } : {}"
              @click="form.plan = p.value"
            >
              <span class="cnv__plan-name">{{ p.label }}</span>
              <span class="cnv__plan-desc">{{ p.desc }}</span>
            </button>
          </div>

          <div class="cnv__row-2" style="margin-top:1rem">
            <div class="cnv__field">
              <label class="cnv__label">Vigente hasta</label>
              <input v-model="form.plan_activo_hasta" type="date" class="cnv__input" />
              <span class="cnv__hint">Dejá vacío para sin vencimiento</span>
            </div>
            <label class="cnv__toggle">
              <input v-model="form.plan_trial" type="checkbox" class="cnv__toggle__input" />
              <div class="cnv__toggle__track"><div class="cnv__toggle__thumb"></div></div>
              <div>
                <div class="cnv__toggle__label">Período de prueba</div>
                <div class="cnv__hint">Muestra badge "Trial" en el panel</div>
              </div>
            </label>
          </div>

          <!-- Feature flags -->
          <div class="cnv__section-label" style="margin-top:1.5rem">Funcionalidades habilitadas</div>
          <div class="cnv__feat-grid">
            <label
              v-for="key in FEATURES_ORDER" :key="key"
              class="cnv__feat-toggle"
              :class="{ 'cnv__feat-toggle--on': form.features[key] }"
            >
              <div class="cnv__feat-left">
                <span class="cnv__feat-ico">{{ FEATURE_META[key].icon }}</span>
                <div>
                  <div class="cnv__feat-name">{{ FEATURE_META[key].label }}</div>
                  <div class="cnv__feat-desc">{{ FEATURE_META[key].desc }}</div>
                </div>
              </div>
              <input v-model="form.features[key]" type="checkbox" class="cnv__toggle__input" />
              <div class="cnv__toggle__track cnv__toggle__track--sm"><div class="cnv__toggle__thumb cnv__toggle__thumb--sm"></div></div>
            </label>
          </div>

        </div>
      </div>

      <!-- ─── Paso 3: Acceso inicial ─── -->
      <div v-if="paso === 3" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--blue"><Users :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Acceso inicial</div>
            <div class="cnv__panel-sub">Seleccioná qué roles crear y la contraseña temporal</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <div class="cnv__field" style="max-width:260px;margin-bottom:1.5rem">
            <label class="cnv__label">Contraseña temporal</label>
            <input v-model="passwordInicial" type="password" autocomplete="new-password" class="cnv__input" placeholder="123456Aa" />
            <span class="cnv__hint">El usuario puede cambiarla desde su perfil</span>
          </div>

          <div class="cnv__section-label">Roles a crear</div>
          <div class="cnv__roles-grid">
            <div
              v-for="(meta, rol) in ROLES_META" :key="rol"
              class="cnv__role-card"
              :class="{
                'cnv__role-card--on':       rolesSeleccionados.includes(rol),
                'cnv__role-card--required': meta.required,
              }"
              @click="toggleRol(rol)"
            >
              <div class="cnv__role-top">
                <div class="cnv__role-check">
                  <Check v-if="rolesSeleccionados.includes(rol)" :size="12" :stroke-width="3" />
                </div>
                <span class="cnv__role-label">{{ meta.label }}</span>
                <span v-if="meta.required" class="cnv__role-req">siempre</span>
              </div>
              <div class="cnv__role-desc">{{ meta.desc }}</div>
              <div class="cnv__role-email">{{ emailRol(rol) }}</div>
            </div>
          </div>

          <div v-if="error" class="cnv__alert" style="margin-top:1.25rem">{{ error }}</div>
        </div>
      </div>

      <!-- ── Navegación ── -->
      <div class="cnv__nav">
        <button v-if="paso > 1" class="cnv__btn-ghost" @click="anterior">
          <ChevronLeft :size="16" :stroke-width="2" /> Anterior
        </button>
        <div class="cnv__nav-spacer"></div>
        <button v-if="paso < 3" class="cnv__btn-primary" @click="siguiente">
          Siguiente <ChevronRight :size="16" :stroke-width="2" />
        </button>
        <button v-else class="cnv__btn-primary" :disabled="saving" @click="handleSubmit">
          <span v-if="saving" class="cnv__spinner"></span>
          <Check v-else :size="16" :stroke-width="2.5" />
          {{ saving ? 'Creando…' : 'Crear club' }}
        </button>
      </div>

    </template>
  </div>
</template>

<style scoped>
.cnv {
  padding: 2rem 2.5rem 3rem;
}

.cnv__back {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .78rem; font-weight: 600; color: #64748b;
  text-decoration: none; margin-bottom: 1.5rem;
  transition: color .15s;
}
.cnv__back:hover { color: #0f172a; }

/* Header + stepper */
.cnv__header { margin-bottom: 2rem; }
.cnv__title { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0 0 1.5rem; letter-spacing: -.04em; }

.cnv__stepper {
  position: relative;
  display: flex; align-items: center; gap: 0;
  background: #f8fafc; border: 1px solid #e2e8f0;
  border-radius: 12px; padding: .875rem 1.25rem;
}
.cnv__step {
  display: flex; align-items: center; gap: .5rem;
  flex: 1; position: relative; z-index: 1;
}
.cnv__step:last-child { flex: 0; }
.cnv__step-dot {
  width: 26px; height: 26px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: .75rem; font-weight: 700; flex-shrink: 0;
  background: #e2e8f0; color: #94a3b8;
  border: 2px solid #e2e8f0;
  transition: all .2s;
}
.cnv__step--active .cnv__step-dot {
  background: #0f172a; color: #fff; border-color: #0f172a;
}
.cnv__step--done .cnv__step-dot {
  background: #1b5e20; color: #fff; border-color: #1b5e20;
}
.cnv__step-label {
  font-size: .78rem; font-weight: 600; color: #94a3b8;
  white-space: nowrap;
}
.cnv__step--active .cnv__step-label { color: #0f172a; }
.cnv__step--done .cnv__step-label   { color: #1b5e20; }

/* Connector line */
.cnv__step:not(:last-child)::after {
  content: '';
  flex: 1;
  height: 1px;
  background: #e2e8f0;
  margin: 0 .75rem;
}
.cnv__step-line { display: none; } /* handled by ::after */

/* Panel */
.cnv__panel {
  background: #fff; border: 1px solid #e2e8f0;
  border-radius: 16px; overflow: hidden;
  margin-bottom: 1.25rem;
}
.cnv__panel-header {
  display: flex; align-items: center; gap: .875rem;
  padding: 1.1rem 1.4rem; border-bottom: 1px solid #f1f5f9;
  background: #fafbfc;
}
.cnv__panel-ico {
  width: 38px; height: 38px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(27,94,32,.1); color: #1b5e20;
}
.cnv__panel-ico--purple { background: rgba(124,58,237,.1); color: #7c3aed; }
.cnv__panel-ico--blue   { background: rgba(3,105,161,.1);  color: #0369a1; }
.cnv__panel-title { font-size: .9rem; font-weight: 800; color: #0f172a; }
.cnv__panel-sub   { font-size: .75rem; color: #94a3b8; margin-top: .1rem; }
.cnv__panel-body  { padding: 1.4rem; }

/* Form */
.cnv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__grid { grid-template-columns: 1fr; } }
.cnv__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__row-2 { grid-template-columns: 1fr; } }

.cnv__field { display: flex; flex-direction: column; gap: .3rem; }
.cnv__field--full { grid-column: 1 / -1; }
.cnv__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.cnv__req   { color: #dc2626; }
.cnv__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .6rem .9rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.cnv__input:focus { outline: none; border-color: #1b5e20; background: #fff; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.cnv__input--err  { border-color: #dc2626; }
.cnv__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.cnv__hint { font-size: .72rem; color: #94a3b8; }
.cnv__hint code { background: #f1f5f9; padding: .1em .4em; border-radius: 4px; font-size: .85em; }
.cnv__alert {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .75rem 1rem; border-radius: 9px; font-size: .82rem; margin-bottom: 1rem;
}
.cnv__section-label {
  font-size: .68rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .06em; color: #94a3b8; margin-bottom: .6rem;
}

/* Planes */
.cnv__planes { display: grid; grid-template-columns: repeat(4,1fr); gap: .5rem; }
@media (max-width: 700px) { .cnv__planes { grid-template-columns: 1fr 1fr; } }
.cnv__plan-btn {
  padding: .75rem .875rem; border: 1.5px solid #e2e8f0; border-radius: 10px;
  background: #f8fafc; text-align: left; cursor: pointer; transition: all .15s;
}
.cnv__plan-btn:hover:not(.cnv__plan-btn--active) { border-color: #94a3b8; background: #f1f5f9; }
.cnv__plan-name { font-size: .85rem; font-weight: 800; display: block; margin-bottom: .2rem; }
.cnv__plan-desc { font-size: .68rem; color: #94a3b8; line-height: 1.4; }
.cnv__plan-btn--active .cnv__plan-desc { color: inherit; opacity: .75; }

/* Toggle */
.cnv__toggle {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: .75rem 1rem; background: #f8fafc;
  border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer;
}
.cnv__toggle:hover { border-color: #1b5e20; }
.cnv__toggle__input { display: none; }
.cnv__toggle__track {
  width: 40px; height: 22px; background: #cbd5e1; border-radius: 999px;
  position: relative; transition: background .2s; flex-shrink: 0; margin-top: .15rem;
}
.cnv__toggle__input:checked + .cnv__toggle__track { background: #1b5e20; }
.cnv__toggle__thumb {
  position: absolute; width: 16px; height: 16px; background: #fff;
  border-radius: 50%; top: 3px; left: 3px;
  transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.cnv__toggle__input:checked + .cnv__toggle__track .cnv__toggle__thumb { left: 21px; }
.cnv__toggle__label { font-size: .875rem; font-weight: 700; color: #0f172a; }

/* Compact toggle for features */
.cnv__toggle__track--sm  { width: 32px; height: 18px; flex-shrink: 0; }
.cnv__toggle__thumb--sm  { width: 12px; height: 12px; top: 3px; left: 3px; }
.cnv__toggle__input:checked + .cnv__toggle__track--sm .cnv__toggle__thumb--sm { left: 17px; }

/* Feature flags grid */
.cnv__feat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px,1fr)); gap: .4rem; }
.cnv__feat-toggle {
  display: flex; align-items: center; gap: .6rem;
  padding: .6rem .75rem; border-radius: 9px;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  cursor: pointer; transition: border-color .15s, background .15s;
  user-select: none;
}
.cnv__feat-toggle--on { border-color: #bbf7d0; background: #f0fdf4; }
.cnv__feat-left { display: flex; align-items: center; gap: .5rem; flex: 1; min-width: 0; }
.cnv__feat-ico  { font-size: .9rem; flex-shrink: 0; }
.cnv__feat-name { font-size: .78rem; font-weight: 700; color: #0f172a; }
.cnv__feat-desc { font-size: .68rem; color: #94a3b8; }

/* Roles */
.cnv__roles-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: .6rem; }
.cnv__role-card {
  padding: .875rem 1rem; border-radius: 10px;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  cursor: pointer; transition: all .15s; user-select: none;
}
.cnv__role-card--on { border-color: #1b5e20; background: #f0fdf4; }
.cnv__role-card--required { cursor: default; }
.cnv__role-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .3rem; }
.cnv__role-check {
  width: 18px; height: 18px; border-radius: 5px; border: 1.5px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
  background: #fff; transition: all .15s;
}
.cnv__role-card--on .cnv__role-check { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.cnv__role-label { font-size: .82rem; font-weight: 800; color: #0f172a; flex: 1; }
.cnv__role-req   { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: #f1f5f9; color: #94a3b8; padding: .15em .5em; border-radius: 5px; }
.cnv__role-desc  { font-size: .72rem; color: #64748b; margin-bottom: .35rem; }
.cnv__role-email { font-size: .68rem; color: #94a3b8; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* Navigation bar */
.cnv__nav {
  display: flex; align-items: center; gap: .75rem;
  padding-top: .25rem;
}
.cnv__nav-spacer { flex: 1; }
.cnv__btn-primary {
  display: inline-flex; align-items: center; gap: .45rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .75rem 1.4rem; border-radius: 10px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s; white-space: nowrap;
}
.cnv__btn-primary:hover:not(:disabled) { background: #166534; }
.cnv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.cnv__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #64748b;
  border: 1.5px solid #e2e8f0; padding: .75rem 1.25rem;
  border-radius: 10px; font-size: .875rem; font-weight: 600;
  cursor: pointer; text-decoration: none; transition: all .15s;
}
.cnv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.cnv__spinner {
  width: 15px; height: 15px;
  border: 2px solid rgba(255,255,255,.3); border-top-color: #fff;
  border-radius: 50%; animation: cnv-spin .6s linear infinite;
}
@keyframes cnv-spin { to { transform: rotate(360deg); } }

/* Success */
.cnv__success {
  background: #fff; border: 1px solid #bbf7d0; border-radius: 16px;
  padding: 3rem 2rem; text-align: center; max-width: 600px; margin: 0 auto;
}
.cnv__success-check {
  width: 56px; height: 56px; border-radius: 50%;
  background: #dcfce7; color: #15803d;
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 1rem;
}
.cnv__success-title { font-size: 1.5rem; font-weight: 800; color: #0f172a; margin: 0 0 .5rem; }
.cnv__success-sub { font-size: .875rem; color: #64748b; margin: 0 0 1.5rem; }
.cnv__usuarios-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(140px,1fr));
  gap: .6rem; margin-bottom: 2rem; text-align: left;
}
.cnv__usuario-card {
  background: #f8fafc; border: 1px solid #e2e8f0;
  border-radius: 10px; padding: .7rem .875rem;
}
.cnv__usuario-role  { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; color: #1b5e20; margin-bottom: .2rem; }
.cnv__usuario-email { font-size: .72rem; color: #64748b; font-family: monospace; word-break: break-all; }
.cnv__success-actions { display: flex; justify-content: center; gap: .75rem; flex-wrap: wrap; }
</style>
