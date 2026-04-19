<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSuperAdminClub, cambiarPlanClub, crearUsuariosDefault, createSuperAdminUser, updateSuperAdminClub } from '../../lib/api.js'

const route  = useRoute()
const router = useRouter()
const id     = Number(route.params.id)

const club    = ref(null)
const loading = ref(true)
const saving  = ref(false)
const error   = ref(null)

const showPlanModal   = ref(false)
const showUserModal   = ref(false)
const planForm = ref({ plan: '', plan_activo_hasta: '', trial: false })
const userForm = ref({ first_name: '', last_name: '', email: '', password: '123456Aa', role: 'cultivador' })
const userError = ref(null)

const PLAN_META = {
  semilla:    { label: 'Semilla',    color: '#64748b', bg: '#f1f5f9' },
  brote:      { label: 'Brote',      color: '#15803d', bg: '#dcfce7' },
  cosecha:    { label: 'Cosecha',    color: '#0369a1', bg: '#dbeafe' },
  federacion: { label: 'Federación', color: '#7c3aed', bg: '#ede9fe' },
}
const PLANES = Object.entries(PLAN_META).map(([v, m]) => ({ value: v, ...m }))
function planMeta(p) { return PLAN_META[p] || PLAN_META.semilla }

const ROLES = ['admin', 'medico', 'agricultor', 'cultivador', 'abogado', 'auditor']
const ROLE_META = {
  admin:      { label: 'Admin',      color: '#0f172a', bg: '#f1f5f9' },
  medico:     { label: 'Médico',     color: '#0369a1', bg: '#dbeafe' },
  agricultor: { label: 'Agricultor', color: '#15803d', bg: '#dcfce7' },
  cultivador: { label: 'Cultivador', color: '#16a34a', bg: '#f0fdf4' },
  abogado:    { label: 'Abogado',    color: '#7c3aed', bg: '#ede9fe' },
  auditor:    { label: 'Auditor',    color: '#b45309', bg: '#fffbeb' },
}
function roleMeta(r) { return ROLE_META[r] || { label: r, color: '#64748b', bg: '#f1f5f9' } }

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

async function cargar() {
  try {
    const { data } = await getSuperAdminClub(id)
    club.value = data
  } finally {
    loading.value = false
  }
}

function abrirPlanModal() {
  planForm.value = {
    plan:              club.value.plan,
    plan_activo_hasta: club.value.plan_activo_hasta?.toString().slice(0, 10) || '',
    trial:             club.value.plan_trial,
  }
  showPlanModal.value = true
}

function abrirUserModal() {
  userForm.value = { first_name: '', last_name: '', email: '', password: '123456Aa', role: 'cultivador' }
  userError.value = null
  showUserModal.value = true
}

async function guardarPlan() {
  saving.value = true
  error.value  = null
  try {
    const { data } = await cambiarPlanClub(id, {
      plan:  planForm.value.plan,
      hasta: planForm.value.plan_activo_hasta || null,
      trial: planForm.value.trial,
    })
    club.value = { ...club.value, ...data }
    showPlanModal.value = false
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al actualizar el plan'
  } finally {
    saving.value = false
  }
}

async function crearUsuario() {
  if (!userForm.value.email.trim()) { userError.value = 'El email es obligatorio'; return }
  saving.value = true
  userError.value = null
  try {
    await createSuperAdminUser({ ...userForm.value, club_id: id })
    await cargar()
    showUserModal.value = false
  } catch (e) {
    userError.value = e?.response?.data?.errors?.join(', ') || 'Error al crear el usuario'
  } finally {
    saving.value = false
  }
}

async function generarUsuarios() {
  if (!confirm('¿Generar los 5 usuarios por defecto? Solo se crean los que no existen todavía.')) return
  saving.value = true
  try {
    const { data } = await crearUsuariosDefault(id)
    await cargar()
    alert(`Se crearon ${data.usuarios.length} usuarios nuevos.`)
  } finally {
    saving.value = false
  }
}

async function toggleWeb() {
  saving.value = true
  try {
    const { data } = await updateSuperAdminClub(id, { web_activa: !club.value.web_activa })
    club.value = { ...club.value, ...data }
  } catch (e) {
    alert('Error al actualizar')
  } finally {
    saving.value = false
  }
}

onMounted(cargar)
</script>

<template>
  <div class="scd">

    <div v-if="loading" class="scd__loading">
      <div class="scd__ring"></div>
    </div>

    <template v-else-if="club">

      <!-- Header -->
      <div class="scd__header">
        <div>
          <RouterLink :to="{ name: 'sa-clubs' }" class="scd__back">
            <i class="bi bi-arrow-left"></i> Clubs
          </RouterLink>
          <div class="scd__title-row">
            <div class="scd__avatar">{{ club.name?.[0]?.toUpperCase() }}</div>
            <div>
              <h1 class="scd__title">{{ club.name }}</h1>
              <div class="scd__slug">{{ club.slug }}</div>
            </div>
          </div>
        </div>
        <div class="scd__header-actions">
          <button class="scd__btn-secondary" @click="generarUsuarios" :disabled="saving">
            <i class="bi bi-magic"></i> Generar usuarios default
          </button>
          <button class="scd__btn-primary" @click="abrirPlanModal">
            <i class="bi bi-stars"></i> Cambiar plan
          </button>
        </div>
      </div>

      <div class="scd__layout">

        <!-- Info del club -->
        <div class="scd__col">
          <div class="scd__card">
            <div class="scd__card-header">
              <span class="scd__card-title">Información del club</span>
            </div>
            <dl class="scd__dl">
              <dt>Nombre legal</dt><dd>{{ club.legal_name || '—' }}</dd>
              <dt>Email</dt><dd>{{ club.email || '—' }}</dd>
              <dt>Teléfono</dt><dd>{{ club.phone || '—' }}</dd>
              <dt>Sitio web</dt><dd>{{ club.website || '—' }}</dd>
              <dt>Dirección</dt><dd>{{ club.address || '—' }}</dd>
              <dt>Ciudad</dt><dd>{{ club.city || '—' }}</dd>
              <dt>Provincia</dt><dd>{{ club.state || '—' }}</dd>
              <dt>País</dt><dd>{{ club.country || '—' }}</dd>
              <dt>Timezone</dt><dd>{{ club.timezone || '—' }}</dd>
              <dt>Registrado</dt><dd>{{ formatDate(club.created_at) }}</dd>
            </dl>
          </div>

          <!-- Plan -->
          <div class="scd__card scd__card--mt">
            <div class="scd__card-header">
              <span class="scd__card-title">Plan actual</span>
              <button class="scd__edit-btn" @click="abrirPlanModal">
                <i class="bi bi-pencil"></i> Editar
              </button>
            </div>
            <div class="scd__plan-body">
              <span class="scd__plan-badge"
                    :style="{ background: planMeta(club.plan).bg, color: planMeta(club.plan).color }">
                {{ planMeta(club.plan).label }}
              </span>
              <span v-if="club.plan_trial" class="scd__trial-badge">TRIAL</span>
              <div class="scd__plan-meta">
                <span v-if="club.plan_activo_hasta">Vigente hasta {{ formatDate(club.plan_activo_hasta) }}</span>
                <span v-else>Sin fecha de vencimiento</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Card web pública -->
        <div class="scd__card scd__card--mt">
          <div class="scd__card-header">
            <span class="scd__card-title">Web pública</span>
          </div>
          <div class="scd__plan-body" style="justify-content:space-between">
            <div>
              <div style="font-size:.875rem;font-weight:600;color:#0f172a;margin-bottom:4px">
                {{ club.web_activa ? 'Activa y visible al público' : 'Desactivada' }}
              </div>
              <div style="font-size:.78rem;color:#94a3b8">
                {{ club.web_activa ? 'El sitio público del club es accesible.' : 'El sitio no es accesible públicamente.' }}
              </div>
            </div>
            <button
              class="scd__web-toggle"
              :class="{ 'scd__web-toggle--on': club.web_activa }"
              :disabled="saving"
              @click="toggleWeb"
            >
              <span class="scd__web-toggle-thumb"></span>
            </button>
          </div>
        </div>

        <!-- Usuarios -->
        <div class="scd__col">
          <div class="scd__card">
            <div class="scd__card-header">
              <span class="scd__card-title">Usuarios ({{ club.usuarios?.length || 0 }})</span>
              <button class="scd__btn-primary scd__btn-sm" @click="abrirUserModal">
                <i class="bi bi-person-plus"></i> Crear usuario
              </button>
            </div>
            <div v-if="!club.usuarios?.length" class="scd__empty">
              Sin usuarios registrados
            </div>
            <div v-else class="scd__users">
              <div v-for="u in club.usuarios" :key="u.id" class="scd__user-row">
                <div class="scd__user-avatar">
                  {{ (u.nombre?.[0] || u.email?.[0] || '?').toUpperCase() }}
                </div>
                <div class="scd__user-info">
                  <div class="scd__user-nombre">{{ u.nombre || '—' }}</div>
                  <div class="scd__user-email">{{ u.email }}</div>
                </div>
                <span class="scd__role-badge"
                      :style="{ background: roleMeta(u.role).bg, color: roleMeta(u.role).color }">
                  {{ roleMeta(u.role).label }}
                </span>
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- ══ Modal cambiar plan ══ -->
      <Teleport to="body">
        <div v-if="showPlanModal" class="scd__overlay" @click.self="showPlanModal = false">
          <div class="scd__modal">
            <div class="scd__modal-header">
              <h3 class="scd__modal-title">Cambiar plan — {{ club.name }}</h3>
              <button class="scd__modal-close" @click="showPlanModal = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="scd__modal-body">
              <div v-if="error" class="scd__alert">{{ error }}</div>
              <div class="scd__field">
                <label class="scd__label">Plan</label>
                <div class="scd__planes">
                  <button v-for="p in PLANES" :key="p.value" type="button"
                          class="scd__plan-btn"
                          :class="{ 'scd__plan-btn--active': planForm.plan === p.value }"
                          :style="planForm.plan === p.value ? { borderColor: p.color, background: p.bg, color: p.color } : {}"
                          @click="planForm.plan = p.value">
                    {{ p.label }}
                  </button>
                </div>
              </div>
              <div class="scd__field">
                <label class="scd__label">Vigente hasta</label>
                <input v-model="planForm.plan_activo_hasta" type="date" class="scd__input" />
                <span class="scd__hint">Dejá vacío para sin vencimiento</span>
              </div>
              <label class="scd__toggle">
                <input v-model="planForm.trial" type="checkbox" class="scd__toggle__input" />
                <div class="scd__toggle__track"><div class="scd__toggle__thumb"></div></div>
                <div class="scd__toggle__label">Período de prueba (trial)</div>
              </label>
            </div>
            <div class="scd__modal-footer">
              <button class="scd__btn-ghost" @click="showPlanModal = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="saving" @click="guardarPlan">
                <span v-if="saving" class="scd__spinner"></span>
                <i v-else class="bi bi-check-lg"></i> Guardar
              </button>
            </div>
          </div>
        </div>
      </Teleport>

      <!-- ══ Modal crear usuario ══ -->
      <Teleport to="body">
        <div v-if="showUserModal" class="scd__overlay" @click.self="showUserModal = false">
          <div class="scd__modal">
            <div class="scd__modal-header">
              <h3 class="scd__modal-title">Nuevo usuario — {{ club.name }}</h3>
              <button class="scd__modal-close" @click="showUserModal = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="scd__modal-body">
              <div v-if="userError" class="scd__alert">{{ userError }}</div>
              <div class="scd__grid">
                <div class="scd__field">
                  <label class="scd__label">Nombre</label>
                  <input v-model.trim="userForm.first_name" class="scd__input" placeholder="Juan" autofocus />
                </div>
                <div class="scd__field">
                  <label class="scd__label">Apellido</label>
                  <input v-model.trim="userForm.last_name" class="scd__input" placeholder="García" />
                </div>
                <div class="scd__field scd__field--full">
                  <label class="scd__label">Email <span style="color:#dc2626">*</span></label>
                  <input v-model.trim="userForm.email" type="email" class="scd__input" placeholder="juan@club.com" />
                </div>
                <div class="scd__field">
                  <label class="scd__label">Contraseña inicial</label>
                  <input v-model="userForm.password" class="scd__input" />
                </div>
                <div class="scd__field">
                  <label class="scd__label">Rol</label>
                  <select v-model="userForm.role" class="scd__input">
                    <option v-for="r in ROLES" :key="r" :value="r">{{ roleMeta(r).label }}</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="scd__modal-footer">
              <button class="scd__btn-ghost" @click="showUserModal = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="saving" @click="crearUsuario">
                <span v-if="saving" class="scd__spinner"></span>
                <i v-else class="bi bi-person-plus"></i>
                {{ saving ? 'Creando…' : 'Crear usuario' }}
              </button>
            </div>
          </div>
        </div>
      </Teleport>

    </template>
  </div>
</template>

<style scoped>
.scd { padding: 2rem 2rem 3rem; max-width: 1100px; }
.scd__loading { display: flex; justify-content: center; padding: 5rem; }
.scd__ring { width: 24px; height: 24px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: scd-spin .7s linear infinite; }
@keyframes scd-spin { to { transform: rotate(360deg); } }

.scd__back { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; font-weight: 600; color: #64748b; text-decoration: none; margin-bottom: .75rem; }
.scd__back:hover { color: #0f172a; }
.scd__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.scd__title-row { display: flex; align-items: center; gap: .875rem; }
.scd__avatar { width: 48px; height: 48px; border-radius: 12px; background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15)); color: #1b5e20; font-size: 1.1rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.scd__title { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0 0 .15rem; letter-spacing: -.03em; }
.scd__slug  { font-size: .78rem; color: #94a3b8; font-family: monospace; }
.scd__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; align-items: center; }

.scd__layout { display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .scd__layout { grid-template-columns: 1fr; } }
.scd__col { display: flex; flex-direction: column; }
.scd__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.scd__card--mt { margin-top: 1.25rem; }
.scd__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.scd__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }
.scd__edit-btn { font-size: .75rem; font-weight: 600; color: #0369a1; background: none; border: none; cursor: pointer; display: flex; align-items: center; gap: .3rem; }
.scd__edit-btn:hover { text-decoration: underline; }

.scd__dl { display: grid; grid-template-columns: 130px 1fr; gap: .4rem .75rem; padding: 1rem 1.1rem; margin: 0; }
.scd__dl dt { font-size: .75rem; color: #94a3b8; font-weight: 500; }
.scd__dl dd { font-size: .82rem; color: #0f172a; font-weight: 500; margin: 0; }

.scd__plan-body { padding: 1rem 1.1rem; display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.scd__plan-badge { font-size: .82rem; font-weight: 800; padding: .3em .85em; border-radius: 8px; }
.scd__trial-badge { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; background: #fffbeb; color: #b45309; padding: .2em .6em; border-radius: 6px; }
.scd__plan-meta { font-size: .78rem; color: #94a3b8; width: 100%; }

.scd__empty { padding: 2rem; text-align: center; color: #94a3b8; font-size: .875rem; }
.scd__users { display: flex; flex-direction: column; }
.scd__user-row { display: flex; align-items: center; gap: .75rem; padding: .75rem 1.1rem; border-bottom: 1px solid #f8fafc; }
.scd__user-row:last-child { border-bottom: none; }
.scd__user-avatar { width: 32px; height: 32px; border-radius: 50%; background: #f1f5f9; color: #475569; font-size: .75rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.scd__user-info { flex: 1; min-width: 0; }
.scd__user-nombre { font-size: .82rem; font-weight: 600; color: #0f172a; }
.scd__user-email  { font-size: .72rem; color: #94a3b8; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.scd__role-badge { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; white-space: nowrap; flex-shrink: 0; }

/* Modal */
.scd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.scd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.scd__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; }
.scd__modal-title { font-size: 1.05rem; font-weight: 800; color: #0f172a; margin: 0; }
.scd__modal-close { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.scd__modal-close:hover { background: #e2e8f0; }
.scd__modal-body { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: 1rem; }
.scd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; }
.scd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem; border-radius: 8px; font-size: .85rem; }
.scd__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.scd__field { display: flex; flex-direction: column; gap: .35rem; }
.scd__field--full { grid-column: 1 / -1; }
.scd__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.scd__hint { font-size: .72rem; color: #94a3b8; }
.scd__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .6rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; }
.scd__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.scd__planes { display: grid; grid-template-columns: repeat(2,1fr); gap: .5rem; }
.scd__plan-btn { padding: .6rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 9px; background: #f8fafc; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; text-align: left; color: #475569; }
.scd__plan-btn:hover { border-color: #94a3b8; }
.scd__toggle { display: flex; align-items: center; gap: .75rem; cursor: pointer; padding: .75rem; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; }
.scd__toggle__input { display: none; }
.scd__toggle__track { width: 38px; height: 22px; background: #cbd5e1; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.scd__toggle__input:checked + .scd__toggle__track { background: #1b5e20; }
.scd__toggle__thumb { position: absolute; width: 16px; height: 16px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; }
.scd__toggle__input:checked + .scd__toggle__track .scd__toggle__thumb { left: 19px; }
.scd__toggle__label { font-size: .875rem; font-weight: 600; color: #0f172a; }

.scd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s; white-space: nowrap; }
.scd__btn-primary:hover:not(:disabled) { background: #144a18; }
.scd__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-sm { padding: .45rem .875rem; font-size: .8rem; }
.scd__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.scd__btn-secondary:hover:not(:disabled) { background: #f8fafc; border-color: #94a3b8; }
.scd__btn-secondary:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.scd__btn-ghost:hover { background: #f8fafc; }
.scd__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: scd-spin .6s linear infinite; }

.scd__web-toggle {
  width: 46px; height: 26px; border-radius: 13px; background: #e2e8f0;
  border: none; cursor: pointer; position: relative; transition: background .25s;
  padding: 0; flex-shrink: 0;
}
.scd__web-toggle--on { background: #1b5e20; }
.scd__web-toggle:disabled { opacity: .5; cursor: not-allowed; }
.scd__web-toggle-thumb {
  position: absolute; top: 3px; left: 3px; width: 20px; height: 20px;
  border-radius: 50%; background: white; transition: transform .25s; display: block;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.scd__web-toggle--on .scd__web-toggle-thumb { transform: translateX(20px); }
</style>

