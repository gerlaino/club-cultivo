<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { listSalas, listSedes } from '../lib/api.js'

const router = useRouter()
const store  = useUsuariosStore()

const q             = ref("")
const showModal     = ref(false)
const editing       = ref(false)
const toast         = ref(null)
const toastTimer    = ref(null)
const todasLasSalas = ref([])
const todasLasSedes = ref([])

const form = ref({
  id: null, first_name: "", last_name: "", email: "",
  role: "cultivador", sede_id: "", sala_id: ""
})

const ROLES = [
  { value: 'admin',      label: 'Administrador', color: '#dc2626', bg: 'rgba(220,38,38,.1)',    icon: 'bi-shield-fill-check' },
  { value: 'medico',     label: 'Médico',        color: '#15803d', bg: 'rgba(21,128,61,.1)',    icon: 'bi-heart-pulse-fill'  },
  { value: 'agricultor', label: 'Agricultor',    color: '#0369a1', bg: 'rgba(3,105,161,.1)',    icon: 'bi-tree-fill'         },
  { value: 'cultivador', label: 'Cultivador',    color: '#0891b2', bg: 'rgba(8,145,178,.1)',    icon: 'bi-flower1'           },
  { value: 'abogado',    label: 'Abogado',       color: '#b45309', bg: 'rgba(180,83,9,.1)',     icon: 'bi-briefcase-fill'    },
  { value: 'auditor',    label: 'Auditor',       color: '#475569', bg: 'rgba(71,85,105,.1)',    icon: 'bi-clipboard-data-fill'},
]

const AVATAR_COLORS = [
  '#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#15803d',
]

function getRoleInfo(role) {
  return ROLES.find(r => r.value === role) || { label: role, color: '#475569', bg: 'rgba(71,85,105,.1)', icon: 'bi-person' }
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

const sedesDisponibles = computed(() => todasLasSedes.value)
const salasDeLaSede = computed(() =>
  todasLasSalas.value.filter(s =>
    s.sede?.id === form.value.sede_id &&
    ['produccion', 'mixta'].includes(s.sede?.tipo)
  )
)

function showToast(type, msg) {
  clearTimeout(toastTimer.value)
  toast.value = { type, msg }
  toastTimer.value = setTimeout(() => toast.value = null, 3500)
}

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
      showToast('success', 'Usuario actualizado correctamente.')
    } else {
      const nuevo = await store.create(payload)
      showModal.value = false
      showToast('success', 'Usuario creado. La contraseña inicial es 123456Aa.')
    }
  } catch (e) {
    showToast('error', store.error || 'Error al guardar.')
  }
}

async function removeOne(u) {
  if (!confirm(`¿Eliminar a ${u.first_name || ''} ${u.last_name || ''}?\nEsta acción no se puede deshacer.`)) return
  try {
    await store.remove(u.id)
    showToast('success', 'Usuario eliminado.')
  } catch {
    showToast('error', store.error || 'No se pudo eliminar.')
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

    <!-- Toast -->
    <Transition name="uv-toast">
      <div v-if="toast" class="uv__toast" :class="`uv__toast--${toast.type}`">
        <i :class="toast.type === 'success' ? 'bi bi-check-circle-fill' : 'bi bi-exclamation-triangle-fill'"></i>
        {{ toast.msg }}
      </div>
    </Transition>

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

    <!-- Grid -->
    <div v-else class="uv__grid">
      <div v-for="u in filteredUsers" :key="u.id" class="uv__card">

        <!-- Franja de color del rol -->
        <div class="uv__card-bar" :style="{ background: getRoleInfo(u.role).color }"></div>

        <div class="uv__card-body">
          <!-- Avatar + info -->
          <div class="uv__card-top">
            <div class="uv__avatar" :style="{ background: getAvatarColor(u) }">
              {{ getInitials(u) }}
            </div>
            <div class="uv__card-info">
              <div class="uv__card-name">{{ u.first_name }} {{ u.last_name }}</div>
              <div class="uv__card-email">{{ u.email }}</div>
            </div>
          </div>

          <!-- Badge rol -->
          <div class="uv__role-badge" :style="{ background: getRoleInfo(u.role).bg, color: getRoleInfo(u.role).color }">
            <i :class="['bi', getRoleInfo(u.role).icon]"></i>
            {{ getRoleInfo(u.role).label }}
          </div>

          <!-- Acciones -->
          <div class="uv__card-actions">
            <RouterLink
              :to="{ name: 'usuario-detail', params: { id: u.id } }"
              class="uv__action uv__action--primary"
              title="Ver perfil"
            >
              <i class="bi bi-person-lines-fill"></i>
              Ver perfil
            </RouterLink>
            <button class="uv__action uv__action--ghost" @click="startEdit(u)" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>
            <button class="uv__action uv__action--danger" @click="removeOne(u)" title="Eliminar">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>

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
                    :style="form.role === r.value ? { background: r.bg, borderColor: r.color, color: r.color } : {}"
                    @click="form.role = r.value"
                  >
                    <i :class="['bi', r.icon]"></i>
                    {{ r.label }}
                  </button>
                </div>
              </div>

              <!-- Sala para cultivador -->
              <template v-if="form.role === 'cultivador'">
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
                  <span class="uv__hint">Podés asignar más salas desde el perfil del cultivador.</span>
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

/* Toast */
.uv__toast {
  position: fixed; top: 1.25rem; right: 1.25rem; z-index: 9999;
  display: flex; align-items: center; gap: .6rem;
  padding: .875rem 1.25rem; border-radius: 12px;
  font-size: .875rem; font-weight: 500;
  box-shadow: 0 8px 24px rgba(0,0,0,.15);
  max-width: 380px;
}
.uv__toast--success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; }
.uv__toast--error   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.uv-toast-enter-active, .uv-toast-leave-active { transition: all .25s ease; }
.uv-toast-enter-from, .uv-toast-leave-to { opacity: 0; transform: translateY(-10px); }

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
.uv__search-input:focus { border-color: #1b5e20; }
.uv__search-input::placeholder { color: #94a3b8; }
.uv__search-clear {
  position: absolute; right: .75rem; color: #94a3b8; cursor: pointer;
  display: flex; align-items: center; font-size: 1rem;
}
.uv__search-clear:hover { color: #0f172a; }

/* Buttons */
.uv__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
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
.uv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: uv-spin .7s linear infinite; }
@keyframes uv-spin { to { transform: rotate(360deg); } }

/* Empty */
.uv__empty { text-align: center; padding: 5rem 1rem; color: #94a3b8; }
.uv__empty-icon { font-size: 3rem; margin-bottom: 1rem; opacity: .4; }
.uv__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin: 0 0 .5rem; }
.uv__empty-desc { font-size: .875rem; margin: 0 0 1.25rem; }

/* Grid */
.uv__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.1rem;
}

/* Card */
.uv__card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 16px;
  overflow: hidden; transition: box-shadow .15s, transform .12s;
}
.uv__card:hover { box-shadow: 0 6px 20px rgba(0,0,0,.08); transform: translateY(-2px); }
.uv__card-bar { height: 4px; }
.uv__card-body { padding: 1.25rem; }

.uv__card-top { display: flex; align-items: center; gap: .875rem; margin-bottom: .875rem; }
.uv__avatar {
  width: 48px; height: 48px; border-radius: 13px;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: .95rem; font-weight: 800; flex-shrink: 0;
  letter-spacing: -.02em;
}
.uv__card-info { flex: 1; min-width: 0; }
.uv__card-name { font-size: .95rem; font-weight: 700; color: #0f172a; margin-bottom: .15rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.uv__card-email { font-size: .75rem; color: #64748b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.uv__role-badge {
  display: inline-flex; align-items: center; gap: .35rem;
  font-size: .72rem; font-weight: 700; padding: .25em .7em;
  border-radius: 6px; margin-bottom: 1rem;
}

.uv__card-actions { display: flex; gap: .5rem; }
.uv__action {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .5rem .875rem; border-radius: 8px;
  font-size: .8rem; font-weight: 600; cursor: pointer;
  transition: all .15s; border: none; text-decoration: none;
}
.uv__action--primary { background: #1b5e20; color: #fff; flex: 1; justify-content: center; }
.uv__action--primary:hover { background: #144a18; }
.uv__action--ghost { background: #f8fafc; color: #475569; border: 1px solid #e2e8f0; }
.uv__action--ghost:hover { background: #e2e8f0; color: #0f172a; }
.uv__action--danger { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
.uv__action--danger:hover { background: #fee2e2; }

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
.uv__input:focus { border-color: #1b5e20; background: #fff; }

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

/* Spinner */
.uv__spinner {
  width: 15px; height: 15px;
  border: 2px solid rgba(255,255,255,.3);
  border-top-color: #fff; border-radius: 50%;
  animation: uv-spin .6s linear infinite;
}
</style>
