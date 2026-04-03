<script setup>
import { ref, computed, onMounted } from 'vue'
import { listSuperAdminUsers, listSuperAdminClubs, createSuperAdminUser, deleteSuperAdminUser } from '../../lib/api.js'

const users   = ref([])
const clubs   = ref([])
const loading = ref(true)
const saving  = ref(false)
const search  = ref('')
const filterClub = ref('todos')
const filterRole = ref('todos')

const showCreate = ref(false)
const createError = ref(null)
const form = ref({ email: '', first_name: '', last_name: '', role: 'admin', club_id: '', password: '123456Aa' })

const ROLES = ['admin','medico','agricultor','cultivador','abogado','auditor']
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
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

const clubsMap = computed(() => Object.fromEntries(clubs.value.map(c => [c.id, c])))

const filtrados = computed(() => {
  let list = users.value
  if (filterClub.value !== 'todos') list = list.filter(u => String(u.club_id) === String(filterClub.value))
  if (filterRole.value !== 'todos') list = list.filter(u => u.role === filterRole.value)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(u =>
      u.email?.toLowerCase().includes(q) ||
      u.first_name?.toLowerCase().includes(q) ||
      u.last_name?.toLowerCase().includes(q) ||
      u.club_name?.toLowerCase().includes(q)
    )
  }
  return list
})

async function cargar() {
  const [usersRes, clubsRes] = await Promise.all([
    listSuperAdminUsers(),
    listSuperAdminClubs(),
  ])
  users.value = usersRes.data
  clubs.value = clubsRes.data
  loading.value = false
}

async function handleCreate() {
  if (!form.value.email || !form.value.club_id) {
    createError.value = 'Email y club son obligatorios'
    return
  }
  saving.value = true
  createError.value = null
  try {
    const { data } = await createSuperAdminUser(form.value)
    users.value.unshift(data)
    showCreate.value = false
    form.value = { email: '', first_name: '', last_name: '', role: 'admin', club_id: '', password: '123456Aa' }
  } catch (e) {
    createError.value = e?.response?.data?.errors?.join(', ') || 'Error al crear usuario'
  } finally {
    saving.value = false
  }
}

async function handleDelete(u) {
  if (!confirm(`¿Eliminar a ${u.email}? Esta acción no se puede deshacer.`)) return
  try {
    await deleteSuperAdminUser(u.id)
    users.value = users.value.filter(x => x.id !== u.id)
  } catch {}
}

onMounted(cargar)
</script>

<template>
  <div class="sau">

    <div class="sau__header">
      <div>
        <div class="sau__eyebrow">Gestión global</div>
        <h1 class="sau__title">Usuarios</h1>
      </div>
      <button class="sau__btn-primary" @click="showCreate = true">
        <i class="bi bi-person-plus"></i> Nuevo usuario
      </button>
    </div>

    <!-- Filtros -->
    <div class="sau__toolbar">
      <div class="sau__search-wrap">
        <i class="bi bi-search sau__search-icon"></i>
        <input v-model="search" class="sau__search" placeholder="Buscar por email, nombre, club…" />
      </div>
      <select v-model="filterRole" class="sau__select">
        <option value="todos">Todos los roles</option>
        <option v-for="r in ROLES" :key="r" :value="r">{{ roleMeta(r).label }}</option>
      </select>
    </div>

    <div v-if="loading" class="sau__loading">
      <div class="sau__ring"></div>
    </div>

    <div v-else class="sau__list">
      <div class="sau__list-header">
        <span>Usuario</span>
        <span>Club</span>
        <span>Rol</span>
        <span>Registrado</span>
        <span></span>
      </div>
      <div v-for="u in filtrados" :key="u.id" class="sau__row">
        <div class="sau__user-cell">
          <div class="sau__avatar">{{ (u.first_name?.[0] || u.email?.[0] || '?').toUpperCase() }}</div>
          <div>
            <div class="sau__nombre">{{ [u.first_name, u.last_name].filter(Boolean).join(' ') || '—' }}</div>
            <div class="sau__email">{{ u.email }}</div>
          </div>
        </div>
        <div class="sau__club">
          <RouterLink :to="{ name: 'sa-club-detail', params: { id: u.club_id } }" class="sau__club-link" v-if="u.club_name">
            {{ u.club_name }}
          </RouterLink>
          <span v-else class="sau__no-club">Sin club</span>
        </div>
        <div>
          <span class="sau__role-badge" :style="{ background: roleMeta(u.role).bg, color: roleMeta(u.role).color }">
            {{ roleMeta(u.role).label }}
          </span>
        </div>
        <div class="sau__date">{{ formatDate(u.created_at) }}</div>
        <div class="sau__actions">
          <button class="sau__delete-btn" @click="handleDelete(u)" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </div>
    </div>

    <div v-if="filtrados.length" class="sau__footer">{{ filtrados.length }} usuario{{ filtrados.length !== 1 ? 's' : '' }}</div>

    <!-- Modal crear usuario -->
    <Teleport to="body">
      <div v-if="showCreate" class="sau__overlay" @click.self="showCreate = false">
        <div class="sau__modal">
          <div class="sau__modal-header">
            <h3 class="sau__modal-title">Nuevo usuario</h3>
            <button class="sau__modal-close" @click="showCreate = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sau__modal-body">
            <div v-if="createError" class="sau__alert">{{ createError }}</div>
            <div class="sau__grid">
              <div class="sau__field">
                <label class="sau__label">Nombre</label>
                <input v-model.trim="form.first_name" class="sau__input" placeholder="Juan" />
              </div>
              <div class="sau__field">
                <label class="sau__label">Apellido</label>
                <input v-model.trim="form.last_name" class="sau__input" placeholder="García" />
              </div>
              <div class="sau__field sau__field--full">
                <label class="sau__label">Email <span style="color:#dc2626">*</span></label>
                <input v-model.trim="form.email" type="email" class="sau__input" placeholder="juan@club.com" />
              </div>
              <div class="sau__field">
                <label class="sau__label">Rol</label>
                <select v-model="form.role" class="sau__input">
                  <option v-for="r in ROLES" :key="r" :value="r">{{ roleMeta(r).label }}</option>
                </select>
              </div>
              <div class="sau__field">
                <label class="sau__label">Club <span style="color:#dc2626">*</span></label>
                <select v-model="form.club_id" class="sau__input">
                  <option value="">Seleccioná un club…</option>
                  <option v-for="c in clubs" :key="c.id" :value="c.id">{{ c.name }}</option>
                </select>
              </div>
              <div class="sau__field sau__field--full">
                <label class="sau__label">Contraseña inicial</label>
                <input v-model="form.password" class="sau__input" />
                <span style="font-size:.72rem;color:#94a3b8">El usuario deberá cambiarla al ingresar</span>
              </div>
            </div>
          </div>
          <div class="sau__modal-footer">
            <button class="sau__btn-ghost" @click="showCreate = false">Cancelar</button>
            <button class="sau__btn-primary" :disabled="saving" @click="handleCreate">
              <span v-if="saving" class="sau__spinner"></span>
              <i v-else class="bi bi-person-plus"></i>
              Crear usuario
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.sau { padding: 2rem 2rem 3rem; max-width: 1200px; }
.sau__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; }
.sau__eyebrow { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .1em; color: #94a3b8; margin-bottom: .35rem; }
.sau__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.04em; }

.sau__toolbar { display: flex; gap: .75rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.sau__search-wrap { position: relative; flex: 1; min-width: 240px; }
.sau__search-icon { position: absolute; left: .875rem; top: 50%; transform: translateY(-50%); color: #94a3b8; pointer-events: none; }
.sau__search { width: 100%; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .65rem .875rem .65rem 2.5rem; font-size: .875rem; color: #0f172a; box-sizing: border-box; }
.sau__search:focus { outline: none; border-color: #1b5e20; }
.sau__select { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .65rem .875rem; font-size: .82rem; color: #0f172a; cursor: pointer; }

.sau__loading { display: flex; justify-content: center; padding: 4rem; }
.sau__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: sau-spin .7s linear infinite; }
@keyframes sau-spin { to { transform: rotate(360deg); } }

.sau__list { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.sau__list-header { display: grid; grid-template-columns: 2fr 1.5fr 1fr 100px 50px; padding: .65rem 1.1rem; font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sau__row { display: grid; grid-template-columns: 2fr 1.5fr 1fr 100px 50px; align-items: center; padding: .75rem 1.1rem; border-bottom: 1px solid #f8fafc; transition: background .12s; }
.sau__row:last-child { border-bottom: none; }
.sau__row:hover { background: #fafbfc; }

.sau__user-cell { display: flex; align-items: center; gap: .75rem; }
.sau__avatar { width: 32px; height: 32px; border-radius: 50%; background: #f1f5f9; color: #475569; font-size: .75rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sau__nombre { font-size: .85rem; font-weight: 600; color: #0f172a; }
.sau__email  { font-size: .72rem; color: #94a3b8; font-family: monospace; }
.sau__club-link { font-size: .82rem; font-weight: 600; color: #0369a1; text-decoration: none; }
.sau__club-link:hover { text-decoration: underline; }
.sau__no-club { font-size: .78rem; color: #cbd5e1; }
.sau__role-badge { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; }
.sau__date { font-size: .75rem; color: #94a3b8; }
.sau__actions { display: flex; justify-content: flex-end; }
.sau__delete-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #94a3b8; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .8rem; transition: all .15s; opacity: 0; }
.sau__row:hover .sau__delete-btn { opacity: 1; }
.sau__delete-btn:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }

.sau__footer { text-align: right; font-size: .75rem; color: #94a3b8; margin-top: .75rem; }

/* Modal */
.sau__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.sau__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 520px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.sau__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; }
.sau__modal-title { font-size: 1.05rem; font-weight: 800; color: #0f172a; margin: 0; }
.sau__modal-close { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.sau__modal-close:hover { background: #e2e8f0; }
.sau__modal-body { padding: 1.25rem 1.4rem; }
.sau__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; }
.sau__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
.sau__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.sau__field { display: flex; flex-direction: column; gap: .35rem; }
.sau__field--full { grid-column: 1 / -1; }
.sau__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.sau__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .6rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; }
.sau__input:focus { outline: none; border-color: #1b5e20; }

.sau__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.sau__btn-primary:hover:not(:disabled) { background: #144a18; }
.sau__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.sau__btn-ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.sau__btn-ghost:hover { background: #f8fafc; }
.sau__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: sau-spin .6s linear infinite; }
</style>
