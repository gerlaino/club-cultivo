<template>
  <div class="acs">

    <div class="acs__header">
      <div>
        <h1 class="acs__title">Cosechas pendientes</h1>
        <p class="acs__sub">Lotes cosechados esperando ser asignados a un manicurador.</p>
      </div>
      <button class="acs__btn-refresh" :disabled="loading" @click="cargar">
        <RefreshCw :size="15" :stroke-width="2" :class="{ 'acs__spin': loading }" />
        Actualizar
      </button>
    </div>

    <div v-if="loading" class="acs__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!lotes.length" class="acs__empty">
      <Scissors :size="40" :stroke-width="1.25" />
      <p class="acs__empty-title">Sin cosechas pendientes</p>
      <p class="acs__empty-sub">Cuando el cultivador finalice una cosecha aparecerá aquí.</p>
    </div>

    <table v-else class="acs__table">
      <thead>
        <tr>
          <th>Lote</th>
          <th>Genética</th>
          <th>Días cosechado</th>
          <th>Plantas</th>
          <th>Peso bruto al corte</th>
          <th>Fecha cosecha</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="lote in paginados" :key="lote.id" class="acs__row"
            @click="$router.push(`/lotes/${lote.id}`)">
          <td>
            <RouterLink :to="`/lotes/${lote.id}`" class="acs__lote-link">
              {{ lote.codigo }}
            </RouterLink>
          </td>
          <td>
            <span v-if="lote.genetica" class="acs__cepa">
              <Dna :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}
            </span>
            <span v-else class="acs__nd">—</span>
          </td>
          <td>
            <span class="acs__pill acs__pill--amber">{{ diasCosechado(lote) }}</span>
          </td>
          <td>
            <span class="acs__pill acs__pill--blue">{{ lote.plants_count_cosechadas || lote.plants_count }} plantas</span>
          </td>
          <td>
            <span v-if="lote.peso_final_g" class="acs__peso">
              <Scale :size="13" :stroke-width="2" /> {{ lote.peso_final_g }}g
            </span>
            <span v-else class="acs__nd">—</span>
          </td>
          <td class="acs__fecha">{{ fmtFecha(lote.updated_at) }}</td>
          <td class="acs__actions" @click.stop>
            <button class="acs__btn-asignar" @click="abrirModal(lote)">
              <UserCheck :size="14" :stroke-width="2" />
              Asignar manicurador
            </button>
          </td>
        </tr>
      </tbody>
    </table>

    <div v-if="totalPages > 1" class="acs__pager">
      <button class="acs__pager-btn" :disabled="page <= 1" @click="page--">«</button>
      <span class="acs__pager-info">{{ page }} / {{ totalPages }}</span>
      <button class="acs__pager-btn" :disabled="page >= totalPages" @click="page++">»</button>
    </div>

    <!-- Modal asignación -->
    <Teleport to="body">
      <Transition name="acs-fade">
        <div v-if="modalLote" class="acs-overlay" @click.self="cerrarModal">
          <div class="acs-modal">

            <div class="acs-modal__header">
              <div class="acs-modal__ico"><UserCheck :size="20" :stroke-width="1.75" /></div>
              <div>
                <h2 class="acs-modal__title">Asignar manicurador</h2>
                <p class="acs-modal__sub">Lote <strong>{{ modalLote.codigo }}</strong> · {{ modalLote.genetica?.nombre }}</p>
              </div>
              <button class="acs-modal__close" @click="cerrarModal"><X :size="18" :stroke-width="2" /></button>
            </div>

            <div class="acs-modal__body">
              <div v-if="loadingManicuradores" class="acs-modal__loading">
                <DsSpinner :size="14" /> Cargando manicuradores…
              </div>
              <div v-else-if="!manicuradores.length" class="acs-modal__empty">
                No hay usuarios con rol de manicura en la organización.
              </div>
              <template v-else>
                <label class="acs-label">Manicurador <span class="acs-req">*</span></label>
                <div class="acs-modal__options">
                  <label
                    v-for="u in manicuradores"
                    :key="u.id"
                    class="acs-modal__option"
                    :class="{ 'acs-modal__option--sel': seleccionado === u.id }"
                  >
                    <input type="radio" :value="u.id" v-model="seleccionado" class="acs-modal__radio" />
                    <div class="acs-modal__option-body">
                      <span class="acs-modal__option-nombre">{{ u.first_name || u.email }}</span>
                      <span class="acs-modal__option-email">{{ u.email }}</span>
                    </div>
                  </label>
                </div>
              </template>

              <div v-if="errorModal" class="acs-modal__error">
                <AlertCircle :size="14" :stroke-width="2" /> {{ errorModal }}
              </div>
            </div>

            <div class="acs-modal__footer">
              <button class="acs-modal__btn-cancel" @click="cerrarModal">Cancelar</button>
              <button
                class="acs-modal__btn-confirm"
                :disabled="!seleccionado || saving"
                @click="confirmar"
              >
                <DsSpinner v-if="saving" :size="12" />
                <UserCheck v-else :size="14" :stroke-width="2" />
                Asignar
              </button>
            </div>

          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { RefreshCw, Scissors, UserCheck, Scale, Dna, X, AlertCircle } from 'lucide-vue-next'
import { listLotes, listUsers, asignarManicurador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()

const lotes             = ref([])
const loading           = ref(true)
const manicuradores     = ref([])

const PER_PAGE   = 10
const page       = ref(1)
const paginados  = computed(() => lotes.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE))
const totalPages = computed(() => Math.max(1, Math.ceil(lotes.value.length / PER_PAGE)))
watch(lotes, () => { page.value = 1 })
const loadingManicuradores = ref(false)

const modalLote   = ref(null)
const seleccionado = ref(null)
const saving      = ref(false)
const errorModal  = ref('')

const fmtFecha = (d) => d
  ? new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
  : '—'

// Días que lleva cosechado el lote (desde que entró al estado cosecha).
const diasCosechado = (lote) => {
  const d = lote.dias_en_estado
  if (d == null) return '—'
  if (d === 0) return 'Hoy'
  return `${d} día${d === 1 ? '' : 's'}`
}

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'cosecha' })
    lotes.value = Array.isArray(data) ? data : []
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

async function cargarManicuradores() {
  loadingManicuradores.value = true
  try {
    const { data } = await listUsers()
    manicuradores.value = (data?.data || [])
      .filter(u => ['manicura', 'admin', 'supervisor'].includes(u.role))
  } catch {
    manicuradores.value = []
  } finally {
    loadingManicuradores.value = false
  }
}

function abrirModal(lote) {
  modalLote.value  = lote
  seleccionado.value = null
  errorModal.value   = ''
  if (!manicuradores.value.length) cargarManicuradores()
}

function cerrarModal() {
  modalLote.value = null
}

async function confirmar() {
  if (!seleccionado.value) return
  saving.value   = true
  errorModal.value = ''
  try {
    await asignarManicurador(modalLote.value.id, seleccionado.value)
    toast.success('Manicurador asignado — lote en manicura')
    cerrarModal()
    await cargar()
  } catch (e) {
    errorModal.value = e.response?.data?.error || 'Error al asignar'
  } finally {
    saving.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.acs {
  padding: var(--sp-6);
  max-width: 1100px;
  margin: 0 auto;
}

.acs__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
}
.acs__title {
  font-size: var(--fs-18);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0 0 4px;
}
.acs__sub {
  font-size: var(--fs-13);
  color: var(--c-ink-400);
  margin: 0;
}
.acs__btn-refresh {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600);
  padding: .45rem .9rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
  flex-shrink: 0;
}
.acs__btn-refresh:hover:not(:disabled) { border-color: var(--c-ink-400); }
.acs__btn-refresh:disabled { opacity: .5; cursor: not-allowed; }
.acs__spin { animation: acs-spin .7s linear infinite; }
@keyframes acs-spin { to { transform: rotate(360deg); } }

.acs__loading {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: calc(100vh - 56px);
}
.acs__empty {
  text-align: center;
  padding: var(--sp-12) var(--sp-4);
  color: var(--c-ink-300);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--sp-2);
}
.acs__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-600); }
.acs__empty-sub { font-size: var(--fs-13); color: var(--c-ink-400); }

/* Table */
.acs__table {
  width: 100%;
  border-collapse: collapse;
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  overflow: hidden;
  font-size: var(--fs-13);
}
.acs__table th {
  text-align: left;
  padding: 10px 14px;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: var(--c-ink-400);
  background: var(--c-slate-50);
  border-bottom: 1.5px solid var(--c-ink-100);
}
.acs__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1.25rem 0 .5rem; }
.acs__pager-btn { background: #fff; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-700); padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.acs__pager-btn:hover:not(:disabled) { border-color: #7c3aed; color: #7c3aed; }
.acs__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.acs__pager-info { font-size: .82rem; color: var(--c-ink-500); font-weight: 600; min-width: 50px; text-align: center; }
.acs__row {
  border-bottom: 1px solid var(--c-ink-100);
  transition: background .1s;
  cursor: pointer;
}
.acs__row:last-child { border-bottom: none; }
.acs__row:hover { background: var(--c-slate-50); }
.acs__row td { padding: 12px 14px; vertical-align: middle; }

.acs__lote-link {
  font-family: monospace;
  font-weight: 700;
  color: var(--c-leaf-700);
  text-decoration: none;
  font-size: var(--fs-13);
}
.acs__lote-link:hover { text-decoration: underline; }
.acs__cepa {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  color: var(--c-ink-700);
}
.acs__nd { color: var(--c-ink-300); }
.acs__pill {
  display: inline-flex;
  align-items: center;
  padding: .18em .6em;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
}
.acs__pill--blue { background: #dbeafe; color: #1d4ed8; }
.acs__pill--amber { background: #fef3c7; color: #b45309; }
.acs__peso {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-weight: 600;
  color: var(--c-ink-800);
}
.acs__fecha { color: var(--c-ink-400); font-size: 12px; }
.acs__actions { text-align: right; }

.acs__btn-asignar {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-leaf-700);
  color: #fff;
  border: none;
  padding: .4rem .85rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  transition: background .15s;
}
.acs__btn-asignar:hover { background: var(--c-leaf-800); }

/* Modal */
.acs-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: var(--sp-4);
}
.acs-modal {
  background: var(--c-paper);
  border-radius: var(--r-xl);
  width: 100%;
  max-width: 440px;
  box-shadow: var(--sh-4);
  overflow: hidden;
}
.acs-modal__header {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: 1.1rem 1.25rem .9rem;
  border-bottom: 1px solid var(--c-ink-100);
}
.acs-modal__ico {
  width: 36px; height: 36px;
  background: #dcfce7;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--c-leaf-700);
  flex-shrink: 0;
}
.acs-modal__title { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.acs-modal__sub { font-size: var(--fs-13); color: var(--c-ink-500); margin: 2px 0 0; }
.acs-modal__close {
  margin-left: auto;
  background: none;
  border: none;
  color: var(--c-ink-400);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
}
.acs-modal__close:hover { background: var(--c-ink-100); }
.acs-modal__body { padding: 1.1rem 1.25rem; display: flex; flex-direction: column; gap: var(--sp-3); }
.acs-modal__footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--sp-2);
  padding: .875rem 1.25rem;
  border-top: 1px solid var(--c-ink-100);
}
.acs-modal__loading {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  color: var(--c-ink-400);
  font-size: var(--fs-13);
}
.acs-modal__empty { font-size: var(--fs-13); color: var(--c-ink-400); }
.acs-label { font-size: 12px; font-weight: 600; color: var(--c-ink-600); text-transform: uppercase; letter-spacing: .04em; }
.acs-req { color: #ef4444; }
.acs-modal__options { display: flex; flex-direction: column; gap: var(--sp-2); }
.acs-modal__option {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border: 1.5px solid var(--c-ink-150, var(--c-ink-200));
  border-radius: var(--r-md);
  cursor: pointer;
  transition: border-color .15s, background .15s;
}
.acs-modal__option:hover { border-color: var(--c-leaf-400); background: var(--c-leaf-50); }
.acs-modal__option--sel { border-color: var(--c-leaf-600); background: #f0fdf4; }
.acs-modal__radio { accent-color: var(--c-leaf-700); }
.acs-modal__option-body { display: flex; flex-direction: column; gap: 1px; }
.acs-modal__option-nombre { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.acs-modal__option-email { font-size: 12px; color: var(--c-ink-400); }
.acs-modal__error {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  font-size: var(--fs-13);
  color: #dc2626;
  background: #fef2f2;
  padding: var(--sp-3);
  border-radius: var(--r-md);
}
.acs-modal__btn-cancel {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600);
  padding: .42rem .85rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
}
.acs-modal__btn-confirm {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-leaf-700);
  color: #fff;
  border: none;
  padding: .42rem .9rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
}
.acs-modal__btn-confirm:hover:not(:disabled) { background: var(--c-leaf-800); }
.acs-modal__btn-confirm:disabled { opacity: .5; cursor: not-allowed; }

.acs-fade-enter-active, .acs-fade-leave-active { transition: opacity .15s; }
.acs-fade-enter-from, .acs-fade-leave-to { opacity: 0; }
</style>
