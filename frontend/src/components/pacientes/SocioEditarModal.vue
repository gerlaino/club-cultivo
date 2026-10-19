<template>
  <Teleport to="body">
    <Transition name="sem-modal">
      <!-- No se cierra tocando afuera: es un formulario largo y un toque de más perdía lo cargado. -->
      <div v-if="open" v-modal="cerrar" class="sem__overlay">
        <div class="sem__modal" role="dialog" aria-modal="true" aria-labelledby="sem-titulo">
          <header class="sem__header">
            <div class="sem__quien">
              <div class="sem__avatar">{{ iniciales }}</div>
              <div class="sem__quien-txt">
                <h2 id="sem-titulo" class="sem__title">Editar paciente</h2>
                <div class="sem__nombre">{{ nombre }}</div>
              </div>
            </div>
            <button class="sem__close" aria-label="Cerrar" @click="cerrar"><X :size="18" /></button>
          </header>

          <!-- Las mismas secciones que el alta, en solapas: se va directo a lo que hay que cambiar. -->
          <nav v-if="!cargando" class="sem__tabs" role="tablist">
            <button v-for="t in solapas" :key="t.key" type="button" role="tab" class="sem__tab"
                    :class="{ 'sem__tab--on': tab === t.key }" :aria-selected="tab === t.key" @click="tab = t.key">
              <i class="bi" :class="t.icono"></i>
              {{ t.label }}
              <span v-if="conError(t.key)" class="sem__tab-err" aria-label="Tiene algo para corregir"></span>
            </button>
          </nav>

          <div class="sem__body">
            <div v-if="cargando" class="sem__loading"><DsSpinner :size="18" /> Cargando paciente…</div>
            <template v-else>
              <SeccionPersona   v-show="tab === 'persona'"   :form="editForm" :errores="editErrores.persona" />
              <SeccionDomicilio v-show="tab === 'domicilio'" :form="editForm" />
              <SeccionReprocann v-show="tab === 'reprocann'" :form="editForm" :errores="editErrores.reprocann" :resultado="resultado" />
              <div v-show="tab === 'estado'" class="pf-seccion">
                <label class="pf-switch">
                  <input v-model="editForm.es_paciente" type="checkbox" :disabled="cerrado" />
                  <span class="pf-switch__track"></span>
                  <span>
                    <span class="pf-switch__t">{{ editForm.es_paciente ? 'Activo en la organización' : 'Inactivo (dado de baja)' }}</span>
                    <span class="pf-switch__d">
                      <template v-if="cerrado">Su REPROCANN está «{{ cerradoLabel }}»: para reactivarlo, «Volver a entrevistar» desde la ficha.</template>
                      <template v-else>Inactivo no puede retirar ni figura en los informes REPROCANN. Se reactiva acá mismo.</template>
                    </span>
                  </span>
                </label>
                <div class="pf-aviso">
                  <i class="bi bi-hourglass-split"></i>
                  <div><strong>Suspendido</strong> no se marca: lo pone el sistema solo a los 90 días sin retirar, y se va solo el día que vuelve a retirar.</div>
                </div>
                <hr class="pf-sep" />
                <div class="pf-campo" style="max-width:240px">
                  <label class="pf-label" for="sem-desc">Descuento por defecto <span class="pf-opc">en cada dispensa</span></label>
                  <div class="sem__pct">
                    <input id="sem-desc" v-model.number="editForm.descuento_porcentaje" class="pf-input" type="number" min="0" max="100" step="1" inputmode="numeric" />
                    <span>%</span>
                  </div>
                  <span class="pf-hint">0 = sin descuento.</span>
                </div>
              </div>
            </template>
          </div>

          <!-- El error va FUERA del cuerpo scrolleable, pegado a los botones: adentro quedaba al
               final de un formulario largo y, con el modal scrolleado arriba, no se veía. -->
          <div v-if="editError" class="sem__error" role="alert">
            <AlertCircle :size="15" :stroke-width="2.5" class="sem__error-ico" />
            <span>{{ editError }}</span>
          </div>
          <footer class="sem__footer">
            <button class="sem__btn-ghost" :disabled="editSaving" @click="cerrar">Cancelar</button>
            <button class="sem__btn-primary" :disabled="editSaving || cargando" @click="doSave">
              <DsSpinner v-if="editSaving" :size="14" />
              <Save v-else :size="14" :stroke-width="2" />
              {{ editSaving ? 'Guardando…' : 'Guardar cambios' }}
            </button>
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, watch, computed } from 'vue'
import { X, Save, AlertCircle } from 'lucide-vue-next'
import { useSocioEditar } from '../../composables/useSocioEditar.js'
import { useAuthStore } from '../../stores/auth.js'
import { usePacientesStore } from '../../stores/pacientes'
import DsSpinner from '../../design-system/components/Spinner.vue'
import SeccionPersona   from './formulario/SeccionPersona.vue'
import SeccionDomicilio from './formulario/SeccionDomicilio.vue'
import SeccionReprocann from './formulario/SeccionReprocann.vue'
import { reprocannCerrado } from './formulario/pacienteForm.js'
import { REPROCANN_SITUACION } from '../../composables/useSituacionPaciente.js'
import './formulario/formulario.css'

const props = defineProps({
  open:    { type: Boolean, default: false },
  socioId: { type: Number, required: true },
  // Con qué solapa abre (la ficha abre la de REPROCANN desde su tarjeta).
  solapa:  { type: String, default: 'persona' },
})
const emit = defineEmits(['update:open', 'saved'])

const auth  = useAuthStore()
const store = usePacientesStore()
const rol   = computed(() => auth.user?.role)
const isAdmin = computed(() => ['admin', 'super_admin'].includes(rol.value))

// Getter, no valor: desde la lista de pacientes el modal se reusa para distintos pacientes.
const { editForm, editSaving, editError, editErrores, openEdit, saveEdit } =
  useSocioEditar(() => props.socioId, { rol })

// El médico sólo toca la salud (15-oct-2026): ve únicamente la solapa REPROCANN.
const TODAS = [
  { key: 'persona',   label: 'Persona',   icono: 'bi-person-vcard' },
  { key: 'domicilio', label: 'Domicilio', icono: 'bi-geo-alt' },
  { key: 'reprocann', label: 'REPROCANN', icono: 'bi-patch-check' },
  { key: 'estado',    label: 'Estado',    icono: 'bi-toggle-on' },
]
const solapas = computed(() => isAdmin.value ? TODAS : TODAS.filter(t => t.key === 'reprocann'))
const tab = ref(props.solapa)

const conError = (key) => Object.keys(editErrores.value?.[key] || {}).length > 0
const cerrado = computed(() => reprocannCerrado(editForm.value))
const cerradoLabel = computed(() => REPROCANN_SITUACION[editForm.value._estado_original]?.label)
const resultado = computed(() => {
  const s = store.current
  if (!s?.reprocann_resultado_el) return null
  return { el: s.reprocann_resultado_el.split('-').reverse().join('/'), motivo: s.reprocann_resultado_motivo }
})
const nombre = computed(() => `${editForm.value.nombre || ''} ${editForm.value.apellido || ''}`.trim())
const iniciales = computed(() => ((editForm.value.nombre?.[0] || '') + (editForm.value.apellido?.[0] || '')).toUpperCase())

// El modal se abre tanto desde la ficha (donde el paciente ya está cargado) como desde la
// lista (donde no): se asegura de tener los datos completos antes de poblar el formulario.
const cargando = ref(false)
// `immediate`: desde la lista el componente se MONTA ya abierto.
watch(() => props.open, async (v) => {
  if (!v) return
  tab.value = solapas.value.some(t => t.key === props.solapa) ? props.solapa : solapas.value[0].key
  if (store.current?.id !== props.socioId) {
    cargando.value = true
    try { await store.fetchOne(props.socioId) } finally { cargando.value = false }
  }
  openEdit()
}, { immediate: true })

function cerrar() { if (!editSaving.value) emit('update:open', false) }

async function doSave() {
  const ok = await saveEdit()
  if (ok) {
    emit('saved')
    emit('update:open', false)
    return
  }
  // Lleva a la solapa donde está lo que hay que corregir.
  const conProblema = solapas.value.find(t => conError(t.key))
  if (conProblema) tab.value = conProblema.key
}
</script>

<style scoped>
.sem__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); display: flex; align-items: center; justify-content: center; z-index: 800; padding: 1rem; }
.sem__modal { background: var(--c-paper, #fff); border-radius: var(--r-xl); width: 100%; max-width: 680px; height: min(760px, 92vh); display: flex; flex-direction: column; box-shadow: var(--sh-3); overflow: hidden; }
.sem__header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.5rem; }
.sem__quien { display: flex; align-items: center; gap: .85rem; min-width: 0; }
.sem__avatar { flex-shrink: 0; width: 42px; height: 42px; border-radius: 50%; display: grid; place-items: center; background: var(--c-leaf-800); color: #fff; font-weight: 700; }
.sem__quien-txt { min-width: 0; }
.sem__title { font-size: .75rem; font-weight: 700; margin: 0; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .06em; }
.sem__nombre { font-size: 1.1rem; font-weight: 700; color: var(--c-slate-900); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sem__close { background: none; border: none; color: var(--c-slate-400); cursor: pointer; width: 40px; height: 40px; border-radius: var(--r-md); display: grid; place-items: center; }
.sem__close:hover { background: var(--c-slate-100); color: var(--c-slate-900); }

.sem__tabs { display: flex; gap: .25rem; padding: 0 1.5rem; border-bottom: 1px solid var(--c-slate-200); overflow-x: auto; scrollbar-width: none; }
.sem__tabs::-webkit-scrollbar { display: none; }
.sem__tab { position: relative; display: inline-flex; align-items: center; gap: .45rem; padding: .75rem .9rem; min-height: 44px; background: none; border: 0;
  border-bottom: 2px solid transparent; margin-bottom: -1px; color: var(--c-slate-500); font: inherit; font-size: .88rem; font-weight: 600; cursor: pointer; white-space: nowrap; }
.sem__tab:hover { color: var(--c-slate-900); }
.sem__tab--on { color: var(--c-leaf-800); border-bottom-color: var(--c-leaf-800); }
.sem__tab-err { width: 7px; height: 7px; border-radius: 50%; background: var(--c-rust-600); }

.sem__body { padding: 1.5rem; flex: 1; overflow-y: auto; }
.sem__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2rem; color: var(--c-slate-500); font-size: .85rem; }
.sem__pct { display: flex; align-items: center; gap: .5rem; font-weight: 700; color: var(--c-slate-500); }
.sem__pct .pf-input { max-width: 120px; }

.sem__error { display: flex; align-items: flex-start; gap: .5rem; padding: .75rem 1.5rem; background: var(--c-rust-100); border-top: 1px solid var(--c-rust-100);
  font-size: .84rem; font-weight: 500; color: var(--c-rust-600); line-height: 1.45; }
.sem__error-ico { flex-shrink: 0; margin-top: .1rem; }
.sem__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid var(--c-slate-100); background: var(--c-slate-50); }
.sem__btn-primary { white-space: nowrap; display: inline-flex; align-items: center; gap: .45rem; min-height: 44px; background: var(--c-leaf-800); color: #fff; border: none; padding: 0 1.25rem; border-radius: var(--r-md); font: inherit; font-size: .9rem; font-weight: 700; cursor: pointer; }
.sem__btn-primary:hover:not(:disabled) { background: var(--c-leaf-900); }
.sem__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.sem__btn-ghost { white-space: nowrap; display: inline-flex; align-items: center; min-height: 44px; background: var(--c-paper, #fff); color: var(--c-slate-700); border: 1px solid var(--c-slate-300); padding: 0 1.1rem; border-radius: var(--r-md); font: inherit; font-size: .9rem; font-weight: 600; cursor: pointer; }
.sem__btn-ghost:hover { border-color: var(--c-slate-500); }
.sem__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }

/* Teléfono: pantalla completa, con los botones siempre a mano. */
@media (max-width: 640px) {
  .sem__overlay { padding: 0; align-items: stretch; }
  .sem__modal { max-width: none; height: 100dvh; border-radius: 0; }
  .sem__header { padding: .85rem 1rem; padding-top: calc(.85rem + env(safe-area-inset-top)); }
  .sem__tabs { padding: 0 .5rem; }
  .sem__body { padding: 1.1rem 1rem; }
  .sem__footer { padding: .75rem 1rem calc(.75rem + env(safe-area-inset-bottom)); }
  .sem__footer button { flex: 1; justify-content: center; }
}

.sem-modal-enter-active, .sem-modal-leave-active { transition: opacity .2s; }
.sem-modal-enter-from, .sem-modal-leave-to { opacity: 0; pointer-events: none; }
.sem-modal-enter-active .sem__modal, .sem-modal-leave-active .sem__modal { transition: transform .2s; }
.sem-modal-enter-from .sem__modal, .sem-modal-leave-to .sem__modal { transform: translateY(12px); }
</style>
