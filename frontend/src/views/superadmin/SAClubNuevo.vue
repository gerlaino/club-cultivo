<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { createSuperAdminClub } from '../../lib/api.js'

const router = useRouter()

const saving   = ref(false)
const error    = ref(null)
const errors   = ref({})
const creado   = ref(null)  // resultado post-creación

const PLANES = [
  { value: 'semilla',    label: 'Semilla',    desc: '1 sede · 2 lotes · 50 plantas · 30 pacientes · 3 usuarios',      color: '#64748b' },
  { value: 'brote',      label: 'Brote',      desc: '2 sedes · 6 lotes · 150 plantas · 100 pacientes · 8 usuarios',   color: '#15803d' },
  { value: 'cosecha',    label: 'Cosecha',    desc: '3 sedes · ilimitado · 250 pacientes · 20 usuarios',              color: '#0369a1' },
  { value: 'federacion', label: 'Federación', desc: 'Todo ilimitado — para federaciones y redes de clubes',           color: '#7c3aed' },
]

const PAISES = ['Argentina', 'Uruguay', 'Colombia', 'España', 'Alemania', 'Canadá', 'Estados Unidos', 'México', 'Chile', 'Brasil', 'Otro']
const TIMEZONES = ['America/Argentina/Buenos_Aires', 'America/Montevideo', 'America/Bogota', 'America/Santiago', 'Europe/Berlin', 'America/Toronto', 'America/New_York']

const form = ref({
  name:              '',
  legal_name:        '',
  email:             '',
  phone:             '',
  website:           '',
  address:           '',
  city:              '',
  state:             '',
  country:           'Argentina',
  timezone:          'America/Argentina/Buenos_Aires',
  plan:              'semilla',
  plan_trial:        true,
  plan_activo_hasta: '',
})

function validate() {
  const e = {}
  if (!form.value.name.trim())   e.name  = 'El nombre es obligatorio'
  if (!form.value.email.trim())  e.email = 'El email es obligatorio'
  if (form.value.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email))
    e.email = 'Email inválido'
  errors.value = e
  return !Object.keys(e).length
}

async function handleSubmit() {
  if (!validate()) return
  saving.value = true
  error.value  = null
  try {
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => { if (payload[k] === '') delete payload[k] })
    const { data } = await createSuperAdminClub(payload)
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

    <!-- Header -->
    <div class="cnv__header">
      <RouterLink :to="{ name: 'sa-clubs' }" class="cnv__back">
        <i class="bi bi-arrow-left"></i> Clubs
      </RouterLink>
      <h1 class="cnv__title">Nuevo club</h1>
      <p class="cnv__sub">Completá la información para registrar un nuevo club en la plataforma</p>
    </div>

    <!-- ══ RESULTADO POST-CREACIÓN ══ -->
    <div v-if="creado" class="cnv__success">
      <div class="cnv__success-icon">
        <i class="bi bi-check-circle-fill"></i>
      </div>
      <h2 class="cnv__success-title">¡Club creado exitosamente!</h2>
      <p class="cnv__success-sub">Se generaron los usuarios por defecto con contraseña <code>123456Aa</code></p>

      <div class="cnv__usuarios-grid">
        <div v-for="u in creado.usuarios" :key="u.id" class="cnv__usuario-card">
          <div class="cnv__usuario-role">{{ u.role }}</div>
          <div class="cnv__usuario-email">{{ u.email }}</div>
        </div>
      </div>

      <div class="cnv__success-actions">
        <RouterLink :to="{ name: 'sa-club-detail', params: { id: creado.club.id } }" class="cnv__btn-primary">
          <i class="bi bi-building"></i> Ver club
        </RouterLink>
        <RouterLink :to="{ name: 'sa-club-nuevo' }" class="cnv__btn-ghost" @click="creado = null">
          Crear otro club
        </RouterLink>
      </div>
    </div>

    <!-- ══ FORMULARIO ══ -->
    <div v-else class="cnv__layout">

      <!-- Columna principal -->
      <div class="cnv__main">

        <!-- Identidad -->
        <div class="cnv__card">
          <div class="cnv__card-header">
            <div class="cnv__card-icon" style="background:rgba(27,94,32,.1);color:#1b5e20">
              <i class="bi bi-building"></i>
            </div>
            <div>
              <div class="cnv__card-title">Identidad del club</div>
              <div class="cnv__card-sub">Datos de identificación ante REPROCANN e IGJ</div>
            </div>
          </div>
          <div class="cnv__card-body">
            <div v-if="error" class="cnv__alert">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
            </div>
            <div class="cnv__grid">
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Nombre del club <span class="cnv__req">*</span></label>
                <input v-model.trim="form.name" class="cnv__input" :class="{ 'cnv__input--err': errors.name }"
                       placeholder="Ej: Club Medicinal del Sur" />
                <span v-if="errors.name" class="cnv__err">{{ errors.name }}</span>
                <span class="cnv__hint">Se usará para generar el slug y los emails de usuarios</span>
              </div>
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Razón social / Nombre legal</label>
                <input v-model.trim="form.legal_name" class="cnv__input"
                       placeholder="Ej: Asociación Civil Club Medicinal del Sur" />
                <span class="cnv__hint">Nombre con el que está registrado ante la IGJ o equivalente</span>
              </div>
              <div class="cnv__field">
                <label class="cnv__label">Email institucional <span class="cnv__req">*</span></label>
                <input v-model.trim="form.email" type="email" class="cnv__input" :class="{ 'cnv__input--err': errors.email }"
                       placeholder="contacto@clubmedicinal.org" />
                <span v-if="errors.email" class="cnv__err">{{ errors.email }}</span>
              </div>
              <div class="cnv__field">
                <label class="cnv__label">Teléfono</label>
                <input v-model.trim="form.phone" class="cnv__input" placeholder="+54 9 11 1234-5678" />
              </div>
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Sitio web</label>
                <input v-model.trim="form.website" class="cnv__input" placeholder="https://clubmedicinal.org" />
              </div>
            </div>
          </div>
        </div>

        <!-- Ubicación -->
        <div class="cnv__card cnv__card--mt">
          <div class="cnv__card-header">
            <div class="cnv__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
              <i class="bi bi-geo-alt"></i>
            </div>
            <div>
              <div class="cnv__card-title">Ubicación</div>
              <div class="cnv__card-sub">Domicilio legal del club</div>
            </div>
          </div>
          <div class="cnv__card-body">
            <div class="cnv__grid">
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Dirección</label>
                <input v-model.trim="form.address" class="cnv__input" placeholder="Av. Corrientes 1234" />
              </div>
              <div class="cnv__field">
                <label class="cnv__label">Ciudad</label>
                <input v-model.trim="form.city" class="cnv__input" placeholder="Buenos Aires" />
              </div>
              <div class="cnv__field">
                <label class="cnv__label">Provincia / Estado</label>
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

      </div>

      <!-- Aside -->
      <div class="cnv__aside">

        <!-- Plan -->
        <div class="cnv__card">
          <div class="cnv__card-header">
            <div class="cnv__card-icon" style="background:rgba(124,58,237,.1);color:#7c3aed">
              <i class="bi bi-stars"></i>
            </div>
            <div>
              <div class="cnv__card-title">Plan de membresía</div>
            </div>
          </div>
          <div class="cnv__card-body">
            <div class="cnv__planes">
              <button
                v-for="p in PLANES"
                :key="p.value"
                type="button"
                class="cnv__plan-btn"
                :class="{ 'cnv__plan-btn--active': form.plan === p.value }"
                :style="form.plan === p.value ? { borderColor: p.color, background: p.color + '10' } : {}"
                @click="form.plan = p.value"
              >
                <div class="cnv__plan-name" :style="form.plan === p.value ? { color: p.color } : {}">
                  {{ p.label }}
                </div>
                <div class="cnv__plan-desc">{{ p.desc }}</div>
              </button>
            </div>

            <div class="cnv__field" style="margin-top:1rem">
              <label class="cnv__label">Vigencia del plan</label>
              <input v-model="form.plan_activo_hasta" type="date" class="cnv__input" />
              <span class="cnv__hint">Dejá vacío para sin vencimiento</span>
            </div>

            <label class="cnv__toggle" style="margin-top:1rem">
              <input v-model="form.plan_trial" type="checkbox" class="cnv__toggle__input" />
              <div class="cnv__toggle__track"><div class="cnv__toggle__thumb"></div></div>
              <div>
                <div class="cnv__toggle__label">Plan en período de prueba</div>
                <div class="cnv__toggle__hint">Se mostrará badge "Trial" en el panel</div>
              </div>
            </label>
          </div>
        </div>

        <!-- Auto-usuarios info -->
        <div class="cnv__card cnv__card--mt cnv__card--info">
          <div class="cnv__card-body">
            <div class="cnv__info-icon"><i class="bi bi-magic"></i></div>
            <div class="cnv__info-title">Usuarios generados automáticamente</div>
            <p class="cnv__info-desc">Al crear el club se generan 5 usuarios con contraseña <code>123456Aa</code>:</p>
            <div class="cnv__roles-list">
              <span class="cnv__role-chip">Admin</span>
              <span class="cnv__role-chip">Médico</span>
              <span class="cnv__role-chip">Agricultor</span>
              <span class="cnv__role-chip">Cultivador</span>
              <span class="cnv__role-chip">Abogado</span>
            </div>
            <p class="cnv__info-desc" style="margin-top:.6rem">El admin del club puede cambiar contraseñas y datos desde su panel.</p>
          </div>
        </div>

        <!-- Acciones -->
        <div class="cnv__actions">
          <button class="cnv__btn-primary" :disabled="saving" @click="handleSubmit">
            <span v-if="saving" class="cnv__spinner"></span>
            <i v-else class="bi bi-building-add"></i>
            {{ saving ? 'Creando club…' : 'Crear club' }}
          </button>
          <RouterLink :to="{ name: 'sa-clubs' }" class="cnv__btn-ghost">Cancelar</RouterLink>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.cnv { padding: 2rem 2rem 3rem; max-width: 1200px; }

.cnv__header { margin-bottom: 2rem; }
.cnv__back { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; font-weight: 600; color: #64748b; text-decoration: none; margin-bottom: .75rem; transition: color .15s; }
.cnv__back:hover { color: #0f172a; }
.cnv__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .25rem; letter-spacing: -.04em; line-height: 1; }
.cnv__sub { font-size: .875rem; color: #64748b; margin: 0; }

/* Layout */
.cnv__layout { display: grid; grid-template-columns: 1fr 320px; gap: 1.5rem; align-items: start; }
@media (max-width: 1000px) { .cnv__layout { grid-template-columns: 1fr; } }

/* Cards */
.cnv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 16px; overflow: hidden; }
.cnv__card--mt { margin-top: 1.25rem; }
.cnv__card--info { background: #f0fdf4; border-color: #bbf7d0; }
.cnv__card-header { display: flex; align-items: center; gap: .875rem; padding: 1.1rem 1.4rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.cnv__card-icon { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: .95rem; flex-shrink: 0; }
.cnv__card-title { font-size: .9rem; font-weight: 800; color: #0f172a; }
.cnv__card-sub   { font-size: .75rem; color: #94a3b8; margin-top: .1rem; }
.cnv__card-body  { padding: 1.25rem 1.4rem; }

/* Grid */
.cnv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__grid { grid-template-columns: 1fr; } }
.cnv__field { display: flex; flex-direction: column; gap: .35rem; }
.cnv__field--full { grid-column: 1 / -1; }
.cnv__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.cnv__req { color: #dc2626; }
.cnv__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .9rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s; }
.cnv__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.cnv__input--err { border-color: #dc2626; }
.cnv__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.cnv__hint { font-size: .72rem; color: #94a3b8; }
.cnv__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 9px; font-size: .85rem; margin-bottom: 1rem; display: flex; gap: .5rem; align-items: flex-start; }

/* Planes */
.cnv__planes { display: flex; flex-direction: column; gap: .5rem; }
.cnv__plan-btn { width: 100%; padding: .75rem 1rem; border: 1.5px solid #e2e8f0; border-radius: 10px; background: #f8fafc; text-align: left; cursor: pointer; transition: all .15s; }
.cnv__plan-btn:hover { border-color: #94a3b8; background: #f1f5f9; }
.cnv__plan-btn--active { }
.cnv__plan-name { font-size: .875rem; font-weight: 800; color: #0f172a; margin-bottom: .2rem; }
.cnv__plan-desc { font-size: .72rem; color: #94a3b8; line-height: 1.4; }

/* Toggle */
.cnv__toggle { display: flex; align-items: flex-start; gap: .75rem; cursor: pointer; padding: .875rem 1rem; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; }
.cnv__toggle:hover { border-color: #1b5e20; }
.cnv__toggle__input { display: none; }
.cnv__toggle__track { width: 42px; height: 24px; background: #cbd5e1; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; margin-top: .1rem; }
.cnv__toggle__input:checked + .cnv__toggle__track { background: #1b5e20; }
.cnv__toggle__thumb { position: absolute; width: 18px; height: 18px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.cnv__toggle__input:checked + .cnv__toggle__track .cnv__toggle__thumb { left: 21px; }
.cnv__toggle__label { font-size: .875rem; font-weight: 700; color: #0f172a; }
.cnv__toggle__hint  { font-size: .75rem; color: #94a3b8; }

/* Info card */
.cnv__info-icon { font-size: 1.5rem; color: #15803d; margin-bottom: .5rem; }
.cnv__info-title { font-size: .875rem; font-weight: 800; color: #14532d; margin-bottom: .35rem; }
.cnv__info-desc { font-size: .78rem; color: #166534; margin: 0; }
.cnv__roles-list { display: flex; flex-wrap: wrap; gap: .35rem; margin-top: .5rem; }
.cnv__role-chip { font-size: .7rem; font-weight: 700; background: #dcfce7; color: #15803d; padding: .2em .6em; border-radius: 6px; }

/* Aside actions */
.cnv__actions { display: flex; flex-direction: column; gap: .6rem; margin-top: 1.25rem; }
.cnv__btn-primary { display: flex; align-items: center; justify-content: center; gap: .5rem; width: 100%; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .85rem 1.25rem; border-radius: 10px; font-size: .9rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; }
.cnv__btn-primary:hover:not(:disabled) { background: #144a18; transform: translateY(-1px); }
.cnv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.cnv__btn-ghost { display: flex; align-items: center; justify-content: center; width: 100%; background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .75rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: all .15s; text-align: center; }
.cnv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.cnv__spinner { width: 16px; height: 16px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: cnv-spin .6s linear infinite; }
@keyframes cnv-spin { to { transform: rotate(360deg); } }

/* Success */
.cnv__success { background: #fff; border: 1px solid #bbf7d0; border-radius: 16px; padding: 3rem 2rem; text-align: center; max-width: 640px; margin: 0 auto; }
.cnv__success-icon { font-size: 3rem; color: #15803d; margin-bottom: 1rem; }
.cnv__success-title { font-size: 1.5rem; font-weight: 800; color: #0f172a; margin: 0 0 .5rem; }
.cnv__success-sub { font-size: .875rem; color: #64748b; margin: 0 0 2rem; }
.cnv__success-sub code { background: #f1f5f9; padding: .1em .4em; border-radius: 4px; font-family: monospace; }
.cnv__usuarios-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px,1fr)); gap: .75rem; margin-bottom: 2rem; text-align: left; }
.cnv__usuario-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: .75rem; }
.cnv__usuario-role { font-size: .7rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; color: #1b5e20; margin-bottom: .25rem; }
.cnv__usuario-email { font-size: .75rem; color: #475569; font-family: monospace; word-break: break-all; }
.cnv__success-actions { display: flex; justify-content: center; gap: .75rem; flex-wrap: wrap; }
</style>
