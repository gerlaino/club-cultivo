<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { listSuperAdminUsers, listSuperAdminClubs, createSuperAdminUser, deleteSuperAdminUser, resetSuperAdminUserPassword } from '../../lib/api.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { ROLES as ALL_ROLES, roleMeta } from '../../constants/roles.js'

const { confirm } = useConfirm()

const ROLES = ALL_ROLES.map(r => r.value)

const users   = ref([])
const clubs   = ref([])
const loading = ref(true)
const saving  = ref(false)
const search  = ref('')
const filterClub = ref('todos')
const filterRole = ref('todos')

// ── Paginación ────────────────────────────────────────────────────────────────
//
// La lista era completa y sin cortar: con la plataforma creciendo, entrar a Usuarios significa
// scrollear cientos de filas para ver las tres que importan, que son las últimas. El backend ya
// las manda con los ÚLTIMOS ARRIBA; acá se muestran de a 10.
const POR_PAGINA = 10
const pagina = ref(1)

const showCreate = ref(false)
const createError = ref(null)
// El campo arranca VACÍO. Venía precargado con '123456Aa', la misma clave para toda la plataforma:
// sabiendo el email de cualquiera se entraba. Ahora, si se deja vacío, el backend genera una
// temporal y dictable, y se muestra acá abajo una sola vez.
const form = ref({ email: '', first_name: '', last_name: '', role: 'admin', club_id: '' })
// La contraseña del último usuario creado, para poder dictarla. El endpoint la devuelve en claro a
// propósito: es temporal y Devise pide cambiarla al entrar.
const passwordCreada = ref(null)

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

const totalPaginas = computed(() => Math.max(1, Math.ceil(filtrados.value.length / POR_PAGINA)))
const pagina1 = computed(() => (pagina.value - 1) * POR_PAGINA)
const visibles = computed(() => filtrados.value.slice(pagina1.value, pagina1.value + POR_PAGINA))

// Al filtrar hay que volver a la primera página: si estabas en la 7 y el buscador deja 12
// resultados, la tabla quedaba VACÍA y parecía que la búsqueda no encontró nada.
watch([search, filterClub, filterRole], () => { pagina.value = 1 })

function irA(p) { pagina.value = Math.min(Math.max(1, p), totalPaginas.value) }

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
    passwordCreada.value = { email: data.email, password_inicial: data.password_inicial }
    showCreate.value = false
    form.value = { email: '', first_name: '', last_name: '', role: 'admin', club_id: '' }
  } catch (e) {
    createError.value = e?.response?.data?.errors?.join(', ') || 'Error al crear usuario'
  } finally {
    saving.value = false
  }
}

// Restablecer la contraseña de alguien. El caso que siempre termina en el panel de plataforma:
// el único admin de una organización pierde su clave y la pantalla de login todavía no ofrece
// "olvidé mi contraseña", así que no tiene cómo resolverlo solo.
//
// No se recupera nada —las contraseñas se guardan hasheadas—: se genera una nueva, dictable, y
// se muestra una vez para poder pasársela.
const reseteando = ref(null)

async function handleReset(u) {
  const ok = await confirm({
    title: `Restablecer la contraseña de ${u.email}?`,
    message: 'Se genera una nueva y te la mostramos para dictarla. La actual deja de funcionar ' +
             'en el acto: si la persona la tenía guardada en el navegador, no va a poder entrar ' +
             'hasta que use la nueva.',
    confirmText: 'Restablecer',
    variant: 'danger',
  })
  if (!ok) return

  reseteando.value = u.id
  try {
    const { data } = await resetSuperAdminUserPassword(u.id)
    passwordCreada.value = { email: data.email, password_inicial: data.password_inicial }
  } catch {
    createError.value = 'No se pudo restablecer la contraseña'
  } finally {
    reseteando.value = null
  }
}

async function handleDelete(u) {
  const ok = await confirm({ title: `¿Eliminar a ${u.email}?`, message: 'Esta acción no se puede deshacer.', confirmText: 'Eliminar' })
  if (!ok) return
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

    <!-- La contraseña del recién creado. Se muestra UNA vez y hay que anotarla: no queda guardada
         en ningún lado en claro. Antes no hacía falta mostrarla porque era siempre la misma para
         toda la plataforma, que es exactamente el problema que esto resuelve. -->
    <div v-if="passwordCreada" class="sau__pass">
      <i class="bi bi-key"></i>
      <span>
        <strong>{{ passwordCreada.email }}</strong> — contraseña temporal:
        <code class="sau__pass-code">{{ passwordCreada.password_inicial }}</code>
        · dictásela ahora, no se vuelve a mostrar. La anterior ya no sirve.
      </span>
      <button class="sau__pass-x" aria-label="Cerrar" @click="passwordCreada = null">
        <i class="bi bi-x-lg"></i>
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
      <!-- El filtro por organización existía en el código y no estaba en la pantalla: se
           declaraba, se usaba para filtrar y no había forma de tocarlo. -->
      <select v-model="filterClub" class="sau__select">
        <option value="todos">Todas las organizaciones</option>
        <option v-for="c in clubs" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
    </div>

    <div v-if="loading" class="sau__loading">
      <DsSpinner />
    </div>

    <div v-else class="sau__list">
      <div class="sau__list-header">
        <span>Usuario</span>
        <span>Club</span>
        <span>Rol</span>
        <span>Registrado</span>
        <span></span>
      </div>
      <div v-for="u in visibles" :key="u.id" class="sau__row">
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
          <!-- SIEMPRE visible, al revés que el de borrar: es lo que se viene a buscar acá
               cuando alguien no puede entrar. -->
          <button class="sau__key-btn" :disabled="reseteando === u.id"
                  :title="`Restablecer la contraseña de ${u.email}`" @click="handleReset(u)">
            <DsSpinner v-if="reseteando === u.id" :size="12" />
            <i v-else class="bi bi-key"></i>
          </button>
          <button class="sau__delete-btn" @click="handleDelete(u)" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </div>
    </div>

    <div v-if="!loading && !filtrados.length" class="sau__vacio">
      No hay usuarios que coincidan con lo que buscaste.
    </div>

    <div v-if="filtrados.length" class="sau__footer">
      <span class="sau__footer-count">
        {{ pagina1 + 1 }}–{{ Math.min(pagina1 + POR_PAGINA, filtrados.length) }}
        de {{ filtrados.length }} usuario{{ filtrados.length !== 1 ? 's' : '' }}
      </span>
      <div v-if="totalPaginas > 1" class="sau__pager">
        <button class="sau__pager-btn" :disabled="pagina === 1" @click="irA(pagina - 1)">
          <i class="bi bi-chevron-left"></i>
        </button>
        <span class="sau__pager-pos">{{ pagina }} / {{ totalPaginas }}</span>
        <button class="sau__pager-btn" :disabled="pagina === totalPaginas" @click="irA(pagina + 1)">
          <i class="bi bi-chevron-right"></i>
        </button>
      </div>
    </div>

    <!-- Modal crear usuario -->
    <Teleport to="body">
      <div v-modal="() => showCreate = false" v-if="showCreate" class="sau__overlay" @click.self="showCreate = false">
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
            </div>
          </div>
          <div class="sau__modal-footer">
            <button class="sau__btn-ghost" @click="showCreate = false">Cancelar</button>
            <button class="sau__btn-primary" :disabled="saving" @click="handleCreate">
              <DsSpinner v-if="saving" :size="14" />
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
.sau__pass {
  display: flex; align-items: center; gap: .6rem;
  background: var(--c-amber-100); color: var(--c-slate-900);
  border: 1px solid var(--c-amber-500);
  border-radius: 10px; padding: .7rem 1rem; margin-bottom: 1rem;
  font-size: .82rem;
}
.sau__pass-code {
  font-family: var(--font-mono); font-weight: 700; font-size: .9rem;
  background: #fff; padding: .1rem .45rem; border-radius: 6px;
  user-select: all;
}
.sau__pass-x {
  margin-left: auto; background: none; border: 0; cursor: pointer;
  color: var(--c-slate-500); display: flex; padding: .2rem;
}
.sau__pass-x:hover { color: var(--c-slate-900); }

.sau { padding: 2rem 2.5rem 3rem; }
.sau__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; }
.sau__eyebrow { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .1em; color: var(--c-slate-400); margin-bottom: .35rem; }
.sau__title { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); margin: 0; letter-spacing: -.04em; }

.sau__toolbar { display: flex; gap: .75rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.sau__search-wrap { position: relative; flex: 1; min-width: 240px; }
.sau__search-icon { position: absolute; left: .875rem; top: 50%; transform: translateY(-50%); color: var(--c-slate-400); pointer-events: none; }
.sau__search { width: 100%; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .65rem .875rem .65rem 2.5rem; font-size: .875rem; color: var(--c-slate-900); box-sizing: border-box; }
.sau__search:focus { outline: none; border-color: #1b5e20; }
.sau__select { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .65rem .875rem; font-size: .82rem; color: var(--c-slate-900); cursor: pointer; }

.sau__loading { display: flex; justify-content: center; align-items: center; padding: 4rem; }

.sau__list { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.sau__list-header { display: grid; grid-template-columns: 2fr 1.5fr 1fr 100px 76px; padding: .65rem 1.1rem; font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); border-bottom: 1px solid var(--c-slate-100); background: #fafbfc; }
.sau__row { display: grid; grid-template-columns: 2fr 1.5fr 1fr 100px 76px; align-items: center; padding: .75rem 1.1rem; border-bottom: 1px solid var(--c-slate-50); transition: background .12s; }
.sau__row:last-child { border-bottom: none; }
.sau__row:hover { background: #fafbfc; }

.sau__user-cell { display: flex; align-items: center; gap: .75rem; }
.sau__avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--c-slate-100); color: var(--c-slate-600); font-size: .75rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sau__nombre { font-size: .85rem; font-weight: 600; color: var(--c-slate-900); }
.sau__email  { font-size: .72rem; color: var(--c-slate-400); font-family: monospace; }
.sau__club-link { font-size: .82rem; font-weight: 600; color: #0369a1; text-decoration: none; }
.sau__club-link:hover { text-decoration: underline; }
.sau__no-club { font-size: .78rem; color: var(--c-slate-300); }
.sau__role-badge { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; }
.sau__date { font-size: .75rem; color: var(--c-slate-400); }
.sau__actions { display: flex; justify-content: flex-end; gap: .35rem; }
.sau__key-btn {
  width: 28px; height: 28px; border-radius: 7px;
  border: 1px solid var(--c-slate-200); background: var(--c-slate-50); color: var(--c-slate-500);
  display: flex; align-items: center; justify-content: center; cursor: pointer;
  font-size: .8rem; transition: all .15s;
}
.sau__key-btn:hover:not(:disabled) { background: #fff7ed; color: #b45309; border-color: #fed7aa; }
.sau__key-btn:disabled { opacity: .5; cursor: not-allowed; }
.sau__delete-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid var(--c-slate-200); background: var(--c-slate-50); color: var(--c-slate-400); display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .8rem; transition: all .15s; opacity: 0; }
.sau__row:hover .sau__delete-btn { opacity: 1; }
.sau__delete-btn:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }

.sau__footer {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  font-size: .75rem; color: var(--c-slate-400); margin-top: .75rem;
}
.sau__footer-count { margin-left: auto; }
.sau__pager { display: flex; align-items: center; gap: .35rem; }
.sau__pager-btn {
  width: 28px; height: 28px; border-radius: 7px; border: 1px solid var(--c-slate-200);
  background: #fff; color: var(--c-slate-600); cursor: pointer;
  display: flex; align-items: center; justify-content: center; font-size: .75rem;
}
.sau__pager-btn:hover:not(:disabled) { background: var(--c-slate-50); }
.sau__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.sau__pager-pos { font-variant-numeric: tabular-nums; font-weight: 600; color: var(--c-slate-500); }
.sau__vacio {
  text-align: center; padding: 2.5rem 1rem; font-size: .85rem; color: var(--c-slate-400);
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
}

/* Modal */
.sau__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.sau__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 520px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.sau__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid var(--c-slate-100); }
.sau__modal-title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.sau__modal-close { background: var(--c-slate-100); border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--c-slate-500); }
.sau__modal-close:hover { background: var(--c-slate-200); }
.sau__modal-body { padding: 1.25rem 1.4rem; }
.sau__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid var(--c-slate-100); }
.sau__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
.sau__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.sau__field { display: flex; flex-direction: column; gap: .35rem; }
.sau__field--full { grid-column: 1 / -1; }
.sau__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.sau__input { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .6rem .875rem; font-size: .875rem; color: var(--c-slate-900); width: 100%; box-sizing: border-box; }
.sau__input:focus { outline: none; border-color: #1b5e20; }

.sau__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.sau__btn-primary:hover:not(:disabled) { background: #144a18; }
.sau__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.sau__btn-ghost { background: transparent; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.sau__btn-ghost:hover { background: var(--c-slate-50); }
</style>
