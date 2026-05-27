<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { listSalas, listSedes } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'

const router = useRouter()
const store  = useUsuariosStore()

const q             = ref("")
const showModal     = ref(false)
const editing       = ref(false)
const currentPage   = ref(1)
const PER_PAGE      = 20
const toast   = useToast()
const { confirm } = useConfirm()
const todasLasSalas = ref([])
const todasLasSedes = ref([])

const form = ref({
  id: null, first_name: "", last_name: "", email: "",
  role: "cultivador", sede_id: "", sala_id: ""
})

const ROLES = [
  { value: 'admin',       label: 'Administrador', icon: 'bi-shield-fill-check'   },
  { value: 'medico',      label: 'Médico',        icon: 'bi-heart-pulse-fill'    },
  { value: 'cultivador',  label: 'Cultivador',    icon: 'bi-flower1'             },
  { value: 'supervisor',  label: 'Supervisor',    icon: 'bi-binoculars-fill'     },
  { value: 'manicura',    label: 'Manicura',      icon: 'bi-scissors'            },
  { value: 'dispensador', label: 'Dispensador',   icon: 'bi-bag-check-fill'      },
  { value: 'delivery',    label: 'Delivery',      icon: 'bi-bicycle'             },
  { value: 'abogado',     label: 'Abogado',       icon: 'bi-briefcase-fill'      },
  { value: 'auditor',     label: 'Auditor',       icon: 'bi-clipboard-data-fill' },
  { value: 'paciente',    label: 'Paciente',      icon: 'bi-person-badge-fill'   },
]

const AVATAR_COLORS = [
  '#1A3D2E','#1A1F36','#172B1F','#C2410C','#1A2F1E','#2A2F38','#1F1810',
]

function getRoleInfo(role) {
  return ROLES.find(r => r.value === role) || { label: role, icon: 'bi-person' }
}

function roleVar(role) { return `--c-role-${role}` }
function roleColor(role) { return `var(${roleVar(role)}, #475569)` }
function roleBg(role) { return `color-mix(in srgb, var(${roleVar(role)}, #475569) 12%, white)` }
function roleBorder(role) { return `color-mix(in srgb, var(${roleVar(role)}, #475569) 30%, white)` }
function roleStyle(role) {
  return { color: roleColor(role), background: roleBg(role), borderColor: roleBorder(role) }
}
function getInitials(user) {
  const f = user.first_name?.[0] || ''
  const l = user.last_name?.[0]  || ''
  return (f + l).toUpperCase() || user.email?.[0]?.toUpperCase() || '?'
}
function getAvatarColor(user) {
  const idx = (user.id || 0) % AVATAR_COLORS.length
  return AVATAR_COLORS[idx]
}

const filteredUsers = computed(() => {
  if (!q.value.trim()) return store.items
  const s = q.value.toLowerCase()
  return store.items.filter(u =>
    u.first_name?.toLowerCase().includes(s) ||
    u.last_name?.toLowerCase().includes(s)  ||
    u.email?.toLowerCase().includes(s)
  )
})

const totalPages  = computed(() => Math.max(1, Math.ceil(filteredUsers.value.length / PER_PAGE)))
const pagedUsers  = computed(() => {
  const start = (currentPage.value - 1) * PER_PAGE
  return filteredUsers.value.slice(start, start + PER_PAGE)
})

watch(q, () => { currentPage.value = 1 })

const sedesDisponibles = computed(() => todasLasSedes.value)
const salasDeLaSede = computed(() =>
  todasLasSalas.value.filter(s =>
    s.sede?.id === form.value.sede_id &&
    ['produccion', 'mixta'].includes(s.sede?.tipo)
  )
)


onMounted(() => store.fetch())

function startCreate() {
  editing.value   = false
  form.value      = { id: null, first_name: "", last_name: "", email: "", role: "cultivador", sede_id: "", sala_id: "" }
  showModal.value = true
}

function startEdit(u) {
  editing.value   = true
  form.value      = { id: u.id, first_name: u.first_name || "", last_name: u.last_name || "", email: u.email || "", role: u.role || "cultivador", sede_id: "", sala_id: "" }
  showModal.value = true
}

const formValid = computed(() =>
  form.value.first_name.trim() && form.value.last_name.trim() && form.value.email.trim()
)

async function save() {
  if (!formValid.value) return
  try {
    const payload = {
      first_name: form.value.first_name,
      last_name:  form.value.last_name,
      email:      form.value.email,
      role:       form.value.role,
    }
    if (editing.value && form.value.id) {
      await store.update(form.value.id, payload)
      showModal.value = false
      toast.success('Usuario actualizado correctamente.')
    } else {
      const nuevo = await store.create({ ...payload, password: '123456Aa', password_confirmation: '123456Aa' })
      showModal.value = false
      toast.success('Usuario creado. La contraseña inicial es 123456Aa.')
    }
  } catch (e) {
    if (e.response?.status === 402) {
      toast.error(e.response.data?.mensaje || 'Límite del plan alcanzado. Contactá al equipo.')
    } else {
      toast.error(store.error || 'Error al guardar.')
    }
  }
}

async function removeOne(u) {
  const ok = await confirm({ title: `¿Eliminar a ${u.first_name || ''} ${u.last_name || ''}?`, message: 'Esta acción no se puede deshacer.', confirmText: 'Eliminar' })
  if (!ok) return
  try {
    await store.remove(u.id)
    toast.success('Usuario eliminado.')
  } catch {
    toast.error(store.error || 'No se pudo eliminar.')
  }
}

watch(showModal, async (val) => {
  if (val) {
    try {
      const [resSalas, resSedes] = await Promise.all([listSalas(), listSedes()])
      todasLasSalas.value = resSalas.data || []
      todasLasSedes.value = resSedes.data || []
    } catch {}
  }
})
</script>

<template>
  <div class="uv">

    <!-- Header -->
    <div class="uv__header">
      <div class="uv__header-left">
        <h1 class="uv__title">Equipo</h1>
        <p class="uv__sub">{{ store.items.length }} miembro{{ store.items.length !== 1 ? 's' : '' }} del club</p>
      </div>
      <div class="uv__header-right">
        <div class="uv__search">
          <i class="bi bi-search uv__search-icon"></i>
          <input
            v-model="q"
            class="uv__search-input"
            placeholder="Buscar por nombre o email…"
          />
          <span v-if="q" class="uv__search-clear" @click="q = ''">
            <i class="bi bi-x"></i>
          </span>
        </div>
        <button class="uv__btn-primary" @click="startCreate">
          <i class="bi bi-plus-lg"></i>
          Nuevo usuario
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="uv__loading">
      <div class="uv__ring"></div>
      <span>Cargando equipo…</span>
    </div>

    <!-- Empty -->
    <div v-else-if="filteredUsers.length === 0" class="uv__empty">
      <div class="uv__empty-icon">
        <i class="bi bi-people"></i>
      </div>
      <h3 class="uv__empty-title">{{ q ? 'Sin resultados' : 'Sin usuarios todavía' }}</h3>
      <p class="uv__empty-desc">{{ q ? 'Probá con otro término de búsqueda.' : 'Agregá el primer miembro del equipo.' }}</p>
      <button v-if="!q" class="uv__btn-primary" @click="startCreate">
        <i class="bi bi-plus-lg"></i> Crear primer usuario
      </button>
    </div>

    <!-- Tabla -->
    <div v-else class="uv__table-wrap">
      <table class="uv__table">
        <thead>
          <tr>
            <th>Usuario</th>
            <th>Rol</th>
            <th class="uv__col-fecha">Miembro desde</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in pagedUsers" :key="u.id" class="uv__table-row">
            <td>
              <div class="uv__user-cell">
                <div class="uv__avatar" :style="{ background: getAvatarColor(u) }">{{ getInitials(u) }}</div>
                <div>
                  <div class="uv__cell-name">{{ u.first_name }} {{ u.last_name }}</div>
                  <div class="uv__cell-email">{{ u.email }}</div>
                </div>
              </div>
            </td>
            <td>
              <span class="uv__role-badge" :style="roleStyle(u.role)">
                <i :class="['bi', getRoleInfo(u.role).icon]"></i>
                {{ getRoleInfo(u.role).label }}
              </span>
            </td>
            <td class="uv__col-fecha">
              <span class="uv__fecha">{{ u.created_at ? new Date(u.created_at).toLocaleDateString('es-AR', { day:'numeric', month:'short', year:'numeric' }) : '—' }}</span>
            </td>
            <td>
              <div class="uv__row-actions">
                <RouterLink :to="{ name: 'usuario-detail', params: { id: u.id } }" class="uv__row-btn" title="Ver perfil">
                  <i class="bi bi-person-lines-fill"></i>
                </RouterLink>
                <button class="uv__row-btn" @click="startEdit(u)" title="Editar">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="uv__row-btn uv__row-btn--danger" @click="removeOne(u)" title="Eliminar">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Paginación -->
      <div v-if="totalPages > 1" class="uv__pagination">
        <span class="uv__page-info">
          {{ filteredUsers.length }} usuario{{ filteredUsers.length !== 1 ? 's' : '' }} ·
          página {{ currentPage }} de {{ totalPages }}
        </span>
        <div class="uv__page-nav">
          <button class="uv__page-btn" :disabled="currentPage === 1" @click="currentPage--">
            <i class="bi bi-chevron-left"></i>
          </button>
          <button
            v-for="p in totalPages" :key="p"
            class="uv__page-btn"
            :class="{ 'uv__page-btn--active': p === currentPage }"
            @click="currentPage = p"
          >{{ p }}</button>
          <button class="uv__page-btn" :disabled="currentPage === totalPages" @click="currentPage++">
            <i class="bi bi-chevron-right"></i>
          </button>
        </div>
      </div>
      <div v-else class="uv__page-footer">
        {{ filteredUsers.length }} usuario{{ filteredUsers.length !== 1 ? 's' : '' }}
      </div>
    </div>

    <!-- Modal crear/editar -->
    <Teleport to="body">
      <div v-if="showModal" class="uv__overlay" @click.self="showModal = false">
        <div class="uv__modal">

          <div class="uv__modal-header">
            <div>
              <h3 class="uv__modal-title">{{ editing ? 'Editar usuario' : 'Nuevo usuario' }}</h3>
              <p class="uv__modal-sub">{{ editing ? 'Modificá los datos del miembro del equipo' : 'Completá los datos para crear la cuenta' }}</p>
            </div>
            <button class="uv__modal-close" @click="showModal = false">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>

          <div class="uv__modal-body">
            <div class="uv__form-grid">

              <div class="uv__field">
                <label class="uv__label">Nombre <span class="uv__req">*</span></label>
                <input class="uv__input" v-model.trim="form.first_name" placeholder="Juan" />
              </div>

              <div class="uv__field">
                <label class="uv__label">Apellido <span class="uv__req">*</span></label>
                <input class="uv__input" v-model.trim="form.last_name" placeholder="Pérez" />
              </div>

              <div class="uv__field uv__field--full">
                <label class="uv__label">Email <span class="uv__req">*</span></label>
                <input type="email" class="uv__input" v-model.trim="form.email" placeholder="usuario@club.org" />
                <span class="uv__hint">La contraseña inicial es <strong>123456Aa</strong></span>
              </div>

              <div class="uv__field uv__field--full">
                <label class="uv__label">Rol</label>
                <div class="uv__roles">
                  <button
                    v-for="r in ROLES" :key="r.value"
                    type="button"
                    class="uv__role-btn"
                    :class="{ 'uv__role-btn--active': form.role === r.value }"
                    :style="form.role === r.value ? roleStyle(r.value) : {}"
                    @click="form.role = r.value"
                  >
                    <i :class="['bi', r.icon]"></i>
                    {{ r.label }}
                  </button>
                </div>
              </div>

              <!-- Advertencia supervisor sin sede -->
              <div v-if="form.role === 'supervisor'" class="uv__field uv__field--full">
                <div class="uv__role-warn">
                  <i class="bi bi-exclamation-triangle-fill"></i>
                  <span>El supervisor necesita al menos una sede asignada para operar. Podés asignársela desde su perfil después de crearlo.</span>
                </div>
              </div>

              <!-- Sala para cultivador / manicura -->
              <template v-if="['cultivador', 'manicura'].includes(form.role)">
                <div class="uv__field uv__field--full">
                  <label class="uv__label">Sede</label>
                  <select class="uv__input" v-model="form.sede_id" @change="form.sala_id = ''">
                    <option value="">Seleccioná una sede…</option>
                    <option v-for="sede in sedesDisponibles" :key="sede.id" :value="sede.id">
                      {{ sede.nombre }}
                    </option>
                  </select>
                </div>
                <div v-if="form.sede_id && salasDeLaSede.length > 0" class="uv__field uv__field--full">
                  <label class="uv__label">Sala inicial <span class="uv__opt">(opcional)</span></label>
                  <select class="uv__input" v-model="form.sala_id">
                    <option value="">Sin sala asignada</option>
                    <option v-for="sala in salasDeLaSede" :key="sala.id" :value="sala.id">
                      {{ sala.nombre }}
                    </option>
                  </select>
                  <span class="uv__hint">
                    {{ form.role === 'manicura'
                      ? 'La manicura trabaja en una única sala. Podés cambiarla desde su perfil.'
                      : 'Podés asignar más salas desde el perfil del cultivador.' }}
                  </span>
                </div>
              </template>

            </div>
          </div>

          <div class="uv__modal-footer">
            <button class="uv__btn-ghost" @click="showModal = false">Cancelar</button>
            <button class="uv__btn-primary" :disabled="store.saving || !formValid" @click="save">
              <div v-if="store.saving" class="uv__spinner"></div>
              <i v-else class="bi bi-check-lg"></i>
              {{ editing ? 'Guardar cambios' : 'Crear usuario' }}
            </button>
          </div>

        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.uv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .uv { padding: 1.25rem 1rem 2rem; } }


/* Header */
.uv__header { display: flex; align-items: center; justify-content: space-between; gap: 1.25rem; margin-bottom: 2rem; flex-wrap: wrap; }
.uv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.uv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.uv__header-right { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }

/* Search */
.uv__search { position: relative; display: flex; align-items: center; }
.uv__search-icon { position: absolute; left: .875rem; color: #94a3b8; font-size: .85rem; pointer-events: none; }
.uv__search-input {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: .65rem .875rem .65rem 2.25rem;
  font-size: .875rem; color: #0f172a;
  width: 280px; outline: none;
  transition: border-color .15s;
}
.uv__search-input:focus { border-color: var(--c-role-admin); }
.uv__search-input::placeholder { color: #94a3b8; }
.uv__search-clear {
  position: absolute; right: .75rem; color: #94a3b8; cursor: pointer;
  display: flex; align-items: center; font-size: 1rem;
}
.uv__search-clear:hover { color: #0f172a; }

/* Buttons */
.uv__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: var(--c-role-admin); color: #fff; border: none;
  padding: .65rem 1.25rem; border-radius: 10px;
  font-size: .875rem; font-weight: 600; cursor: pointer;
  transition: background .15s; white-space: nowrap; text-decoration: none;
}
.uv__btn-primary:hover:not(:disabled) { background: #144a18; }
.uv__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.uv__btn-ghost {
  background: #fff; color: #64748b; border: 1.5px solid #e2e8f0;
  padding: .65rem 1.1rem; border-radius: 10px;
  font-size: .875rem; font-weight: 500; cursor: pointer;
}
.uv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }

/* Loading */
.uv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.uv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: var(--c-role-admin); border-radius: 50%; animation: uv-spin .7s linear infinite; }
@keyframes uv-spin { to { transform: rotate(360deg); } }

/* Empty */
.uv__empty { text-align: center; padding: 5rem 1rem; color: #94a3b8; }
.uv__empty-icon { font-size: 3rem; margin-bottom: 1rem; opacity: .4; }
.uv__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin: 0 0 .5rem; }
.uv__empty-desc { font-size: .875rem; margin: 0 0 1.25rem; }

/* Table */
.uv__table-wrap { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.uv__table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.uv__table thead th { padding: 10px 14px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; background: #fafafa; white-space: nowrap; }
.uv__table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; }
.uv__table tbody tr:last-child { border-bottom: none; }
.uv__table tbody tr:hover { background: #f8fafc; }
.uv__table td { padding: 10px 14px; vertical-align: middle; }

.uv__user-cell { display: flex; align-items: center; gap: .75rem; }
.uv__avatar {
  width: 32px; height: 32px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: .72rem; font-weight: 700; flex-shrink: 0;
}
.uv__cell-name { font-weight: 600; font-size: .875rem; color: #0f172a; }
.uv__cell-email { font-size: .75rem; color: #9ca3af; }

.uv__role-badge {
  display: inline-flex; align-items: center; gap: .35rem;
  font-size: .72rem; font-weight: 700; padding: .2em .6em;
  border-radius: 5px;
}

.uv__col-fecha { width: 140px; }
.uv__fecha { font-size: .78rem; color: #94a3b8; }

.uv__row-actions { display: flex; align-items: center; gap: .2rem; justify-content: flex-end; opacity: 0; transition: opacity .15s; }
.uv__table-row:hover .uv__row-actions { opacity: 1; }
.uv__row-btn {
  display: inline-flex; align-items: center; justify-content: center;
  width: 30px; height: 30px; border-radius: 7px;
  background: none; border: none; color: #64748b; cursor: pointer;
  font-size: .875rem; transition: all .15s; text-decoration: none;
}
.uv__row-btn:hover { background: #f1f5f9; color: #1e293b; }
.uv__row-btn--danger:hover { background: #fef2f2; color: #b91c1c; }

@media (max-width: 640px) {
  .uv__col-fecha, .uv__table thead th:nth-child(3), .uv__table td:nth-child(3) { display: none; }
  .uv__row-actions { opacity: 1; }
}

/* Modal */
.uv__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.4);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem; backdrop-filter: blur(3px);
}
.uv__modal {
  background: #fff; border-radius: 18px; width: 100%; max-width: 560px;
  max-height: 90vh; overflow-y: auto;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
  display: flex; flex-direction: column;
}
.uv__modal-header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; padding: 1.5rem 1.5rem 1.25rem;
  border-bottom: 1px solid #f1f5f9;
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.uv__modal-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin: 0; }
.uv__modal-sub { font-size: .78rem; color: #64748b; margin: .2rem 0 0; }
.uv__modal-close {
  background: #f1f5f9; border: none; width: 32px; height: 32px;
  border-radius: 9px; cursor: pointer; display: flex;
  align-items: center; justify-content: center;
  color: #64748b; font-size: .85rem; flex-shrink: 0;
  transition: all .15s;
}
.uv__modal-close:hover { background: #e2e8f0; color: #0f172a; }
.uv__modal-body { padding: 1.5rem; flex: 1; }
.uv__modal-footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1.1rem 1.5rem; border-top: 1px solid #f1f5f9;
  position: sticky; bottom: 0; background: #fff;
}

/* Form */
.uv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .uv__form-grid { grid-template-columns: 1fr; } }
.uv__field { display: flex; flex-direction: column; gap: .35rem; }
.uv__field--full { grid-column: 1 / -1; }
.uv__label { font-size: .78rem; font-weight: 600; color: #374151; }
.uv__req { color: #ef4444; }
.uv__opt { font-size: .7rem; font-weight: 400; color: #94a3b8; }
.uv__hint { font-size: .73rem; color: #64748b; }
.uv__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .875rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; outline: none;
  transition: border-color .15s;
}
.uv__input:focus { border-color: var(--c-role-admin); background: #fff; }

/* Roles selector */
.uv__roles { display: flex; flex-wrap: wrap; gap: .5rem; }
.uv__role-btn {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .45rem .875rem; border-radius: 8px;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  font-size: .8rem; font-weight: 500; cursor: pointer;
  color: #475569; transition: all .15s;
}
.uv__role-btn:hover { border-color: #cbd5e1; background: #f1f5f9; }
.uv__role-btn--active { font-weight: 700; }

/* Supervisor warn */
.uv__role-warn {
  display: flex;
  align-items: flex-start;
  gap: .5rem;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 9px;
  padding: .65rem .875rem;
  font-size: .78rem;
  color: #92400e;
  line-height: 1.5;
}
.uv__role-warn i { color: #d97706; flex-shrink: 0; margin-top: 2px; }

/* Spinner */
.uv__spinner {
  width: 15px; height: 15px;
  border: 2px solid rgba(255,255,255,.3);
  border-top-color: #fff; border-radius: 50%;
  animation: uv-spin .6s linear infinite;
}

/* Pagination */
.uv__pagination {
  display: flex; align-items: center; justify-content: space-between;
  padding: .75rem 1rem; border-top: 1px solid #f1f5f9; gap: 1rem; flex-wrap: wrap;
}
.uv__page-footer {
  padding: .65rem 1rem; border-top: 1px solid #f1f5f9;
  font-size: .75rem; color: #94a3b8; text-align: right;
}
.uv__page-info { font-size: .75rem; color: #94a3b8; }
.uv__page-nav { display: flex; gap: .25rem; align-items: center; }
.uv__page-btn {
  min-width: 32px; height: 32px; padding: 0 .5rem;
  border: 1.5px solid #e2e8f0; border-radius: 7px;
  background: #fff; font-size: .8rem; font-weight: 500;
  color: #475569; cursor: pointer; transition: all .15s;
  display: inline-flex; align-items: center; justify-content: center;
}
.uv__page-btn:hover:not(:disabled) { border-color: #94a3b8; color: #0f172a; }
.uv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.uv__page-btn--active {
  background: var(--c-role-admin); border-color: var(--c-role-admin);
  color: #fff; font-weight: 700;
}
.uv__page-btn--active:hover { background: var(--c-role-admin); color: #fff; }
</style>
