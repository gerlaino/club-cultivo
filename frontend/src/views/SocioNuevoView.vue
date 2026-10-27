<script setup>
// EL ALTA DE UN PACIENTE, POR PASOS (19-oct-2026). Persona → Domicilio → REPROCANN → Turno y
// confirmar. Pasos y no solapas porque el alta se hace una vez y en orden; la edición usa las MISMAS
// secciones en solapas (`SocioEditarModal`). Cada paso valida lo suyo antes de seguir, y el DNI
// repetido se avisa en el primero, no al final.
import { ref, computed, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import { useToast } from '../composables/useToast.js'
import { listPacientes } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import LinkPortalNuevo from '../components/pacientes/LinkPortalNuevo.vue'
import SeccionPersona   from '../components/pacientes/formulario/SeccionPersona.vue'
import SeccionDomicilio from '../components/pacientes/formulario/SeccionDomicilio.vue'
import SeccionReprocann from '../components/pacientes/formulario/SeccionReprocann.vue'
import SeccionTurno     from '../components/pacientes/formulario/SeccionTurno.vue'
import {
  formVacio, aPayload, validarPersona, validarReprocann, edad, dniLegible,
  OPCIONES_VINCULADO, ESTADOS_ADHERENTE, esAdherente,
} from '../components/pacientes/formulario/pacienteForm.js'
import '../components/pacientes/formulario/formulario.css'

const router = useRouter()
const route  = useRoute()
// Dentro del shell del teléfono (`/m`) la barra de botones va arriba de su barra de solapas.
const enShell = computed(() => route.path.startsWith('/m/'))
const store  = usePacientesStore()
const auth   = useAuthStore()
const club   = useClubStore()
const toast  = useToast()

const form  = ref(formVacio())
const turno = ref(null)
const errores = ref({})
const duplicado = ref(null)
const errorGeneral = ref(null)
const mandarBienvenida = ref(false)

const esAdmin = computed(() => ['admin', 'super_admin'].includes(auth.user?.role))
// El turno lo da administración (la agenda de los médicos es suya) y sólo con el módulo médico.
const ofreceTurno = computed(() => esAdmin.value && club.data?.features?.medico === true)
const puedeMandarBienvenida = computed(() => esAdmin.value && club.data?.features?.mailer === true)

const PASOS = computed(() => [
  { key: 'persona',   titulo: 'Persona',   sub: 'Identidad y contacto',     icono: 'bi-person-vcard' },
  { key: 'domicilio', titulo: 'Domicilio', sub: 'Opcional',                 icono: 'bi-geo-alt' },
  { key: 'reprocann', titulo: 'REPROCANN', sub: 'Vínculo y estado',         icono: 'bi-patch-check' },
  { key: 'cierre',    titulo: ofreceTurno.value ? 'Turno y confirmar' : 'Confirmar',
    sub: ofreceTurno.value ? 'Entrevista opcional' : 'Revisá y creá', icono: 'bi-check2-circle' },
])
const paso = ref(0)
const visitado = ref(0)
const actual = computed(() => PASOS.value[paso.value])
const esUltimo = computed(() => paso.value === PASOS.value.length - 1)

// ── Validación de cada paso ────────────────────────────────────────────────────
const verificandoDni = ref(false)
let dniVerificado = null
let enCurso = null // { dni, promesa }: el blur del campo y el «Siguiente» piden lo mismo una sola vez

// Al salir del campo arranca la consulta; el clic en «Siguiente» que viene justo después la ESPERA
// (si apagara el botón, el clic caería sobre un botón apagado y parecería que no hace nada).
function verificarDni() {
  const dni = (form.value.dni || '').replace(/\D/g, '')
  if (!/^\d{7,9}$/.test(dni)) { duplicado.value = null; return Promise.resolve(true) }
  if (dniVerificado === dni) return Promise.resolve(!duplicado.value)
  if (enCurso?.dni === dni) return enCurso.promesa
  verificandoDni.value = true
  const promesa = listPacientes({ dni, limite: 1 })
    .then(({ data }) => {
      const p = (data?.data || [])[0]
      duplicado.value = p ? { id: p.id, nombre: `${p.nombre} ${p.apellido}`.trim() } : null
      dniVerificado = dni
      return !duplicado.value
    })
    .catch(() => { duplicado.value = null; return true }) // si no se pudo mirar, el backend igual lo frena al crear
    .finally(() => { verificandoDni.value = false; enCurso = null })
  enCurso = { dni, promesa }
  return promesa
}

async function pasoValido(i) {
  const key = PASOS.value[i].key
  let e = {}
  if (key === 'persona') e = validarPersona(form.value)
  if (key === 'reprocann') e = validarReprocann(form.value)
  errores.value = e
  if (Object.keys(e).length) return false
  if (key === 'persona') return verificarDni()
  return true
}

// Un doble clic mientras se mira el DNI no salta dos pasos.
let avanzando = false
async function siguiente() {
  if (avanzando) return
  avanzando = true
  try {
    if (!(await pasoValido(paso.value))) { enfocarError(); return }
    if (esUltimo.value) return await crear()
    paso.value += 1
    visitado.value = Math.max(visitado.value, paso.value)
    arriba()
  } finally {
    avanzando = false
  }
}
function atras() { if (paso.value > 0) { paso.value -= 1; errores.value = {}; arriba() } }
async function irA(i) {
  if (i === paso.value || i > visitado.value) return
  if (i > paso.value && !(await pasoValido(paso.value))) return
  paso.value = i; arriba()
}

const cuerpo = ref(null)
function arriba() {
  nextTick(() => {
    cuerpo.value?.scrollIntoView({ block: 'start', behavior: 'smooth' })
    cuerpo.value?.querySelector('input:not([type=checkbox]), button[role=radio]')?.focus({ preventScroll: true })
  })
}
function enfocarError() {
  nextTick(() => cuerpo.value?.querySelector('.pf-input--err')?.focus())
}

// ── El resumen (lo que se va a crear, dicho en palabras) ───────────────────────────
const opcionVinc = computed(() => OPCIONES_VINCULADO.find(o => o.value === form.value.opcion_reprocann))
const resumenReprocann = computed(() => {
  if (esAdherente(form.value)) {
    const e = ESTADOS_ADHERENTE.find(x => x.value === form.value.reprocann_estado)?.label || 'Vigente'
    return { titulo: `Adherente · ${e}`, detalle: 'Su REPROCANN lo tramita su organización. Puede retirar.' }
  }
  return { titulo: `Vinculado · ${opcionVinc.value?.label}`, detalle: opcionVinc.value?.ayuda }
})
const domicilioTexto = computed(() => {
  const f = form.value
  const l1 = [f.domicilio_calle, f.domicilio_altura].filter(Boolean).join(' ')
  const pd = [f.domicilio_piso && `Piso ${f.domicilio_piso}`, f.domicilio_depto && `Depto ${f.domicilio_depto}`].filter(Boolean).join(' ')
  return [l1, pd, f.domicilio_barrio, f.domicilio_ciudad].filter(Boolean).join(', ')
})
const turnoTexto = computed(() => {
  if (!turno.value) return null
  const d = new Date(turno.value.fecha_hora)
  return `${d.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })}, ${turno.value.fecha_hora.slice(11, 16)} · ${turno.value.medico_nombre}`
})
const nombreCompleto = computed(() => `${form.value.nombre} ${form.value.apellido}`.trim())
const iniciales = computed(() => ((form.value.nombre?.[0] || '') + (form.value.apellido?.[0] || '')).toUpperCase() || '?')
const anios = computed(() => edad(form.value.fecha_nacimiento))

// Lo que el riel muestra debajo de cada paso ya hecho.
function resumenPaso(key) {
  if (key === 'persona' && form.value.nombre) return [nombreCompleto.value, form.value.dni && `DNI ${dniLegible(form.value.dni)}`].filter(Boolean).join(' · ')
  if (key === 'domicilio') return domicilioTexto.value || 'Sin cargar'
  if (key === 'reprocann') return resumenReprocann.value.titulo
  return ''
}

// ── Crear ─────────────────────────────────────────────────────────────────────────
const credenciales = ref(null)
const irAlFinal    = ref(null)
function cerrarCredenciales() {
  credenciales.value = null
  if (irAlFinal.value) router.push(irAlFinal.value)
}

async function crear() {
  errorGeneral.value = null
  const payload = aPayload(form.value)
  Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
  delete payload.es_paciente
  delete payload.descuento_porcentaje
  try {
    const { paciente, aviso, acceso } = await store.create(payload, {
      enviarBienvenida: puedeMandarBienvenida.value && mandarBienvenida.value && !!form.value.email,
      turno: turno.value ? { medico_id: turno.value.medico_id, fecha_hora: turno.value.fecha_hora,
                             duracion_minutos: turno.value.duracion_minutos, tipo: turno.value.tipo } : null,
    })
    toast.success(turno.value ? `${nombreCompleto.value} quedó dado de alta, con su turno.` : `${nombreCompleto.value} quedó dado de alta.`)
    if (aviso) toast.warning(aviso)
    const destino = { name: 'paciente-detail', params: { id: paciente.id } }
    // El link del portal se muestra ANTES de irse, para mandárselo ya (27-oct-2026). Si se cierra
    // sin mandarlo, desde la ficha se genera otro.
    if (acceso?.link) {
      credenciales.value = { ...acceso.link, nombre: nombreCompleto.value }
      irAlFinal.value = destino
      return
    }
    if (acceso?.error) toast.warning(`El paciente se creó, pero no se pudo generar el link de su portal: ${acceso.error}`)
    router.push(destino)
  } catch (e) {
    errorGeneral.value = e.response?.status === 402
      ? (e.response.data?.mensaje || 'Llegaron al límite de pacientes del plan.')
      : (store.error || 'No se pudo crear el paciente.')
  }
}

function onEnter(ev) {
  if (ev.target?.tagName === 'TEXTAREA' || ev.isComposing) return
  if (ev.target?.closest?.('.dp')) return // el calendario maneja su Enter
  ev.preventDefault()
  siguiente()
}
</script>

<template>
  <div class="alta" :class="{ 'alta--shell': enShell }">
    <LinkPortalNuevo :datos="credenciales" @cerrar="cerrarCredenciales" />

    <header class="alta__head">
      <RouterLink to="/pacientes" class="alta__back"><i class="bi bi-arrow-left"></i> Pacientes</RouterLink>
      <h1 class="alta__title">Nuevo paciente</h1>
      <!-- En el teléfono el riel no entra: paso, título y una barra. -->
      <div class="alta__movil" aria-hidden="true">
        <span class="alta__movil-n">Paso {{ paso + 1 }} de {{ PASOS.length }}</span>
        <span class="alta__movil-t">{{ actual.titulo }}</span>
        <div class="alta__barra"><div class="alta__barra-in" :style="{ width: `${((paso + 1) / PASOS.length) * 100}%` }"></div></div>
      </div>
    </header>

    <div class="alta__layout">
      <!-- Riel de pasos (compu). Los hechos muestran lo cargado y se puede volver a ellos. -->
      <nav class="alta__riel" aria-label="Pasos del alta">
        <ol>
          <li v-for="(p, i) in PASOS" :key="p.key">
            <button type="button" class="riel__paso"
                    :class="{ 'riel__paso--on': i === paso, 'riel__paso--hecho': i < paso || (i <= visitado && i !== paso) }"
                    :disabled="i > visitado" :aria-current="i === paso ? 'step' : undefined" @click="irA(i)">
              <span class="riel__n">
                <i v-if="i < paso" class="bi bi-check-lg"></i>
                <template v-else>{{ i + 1 }}</template>
              </span>
              <span class="riel__txt">
                <span class="riel__t">{{ p.titulo }}</span>
                <span class="riel__d">{{ i < paso && resumenPaso(p.key) ? resumenPaso(p.key) : p.sub }}</span>
              </span>
            </button>
          </li>
        </ol>
        <!-- Así va a quedar: la tarjeta del paciente, que se arma mientras se carga. -->
        <div class="riel__ficha" :class="{ 'riel__ficha--vacia': !form.nombre && !form.apellido }">
          <div class="riel__avatar">{{ iniciales }}</div>
          <div class="riel__ficha-txt">
            <div class="riel__nombre">{{ nombreCompleto || 'Paciente nuevo' }}</div>
            <div class="riel__meta">
              <span v-if="form.dni">DNI {{ dniLegible(form.dni) }}</span>
              <span v-if="anios !== null"> · {{ anios }} años</span>
            </div>
            <div v-if="paso >= 2" class="riel__pills">
              <span class="pf-pill pf-pill--ok">Activo</span>
              <span class="pf-pill pf-pill--off">{{ esAdherente(form) ? 'Adherente' : 'Vinculado' }}</span>
            </div>
          </div>
        </div>
      </nav>

      <main class="alta__main">
        <form class="alta__card" novalidate @submit.prevent="siguiente" @keydown.enter="onEnter">
          <div ref="cuerpo" class="alta__card-head">
            <span class="alta__card-ico"><i class="bi" :class="actual.icono"></i></span>
            <div>
              <h2 class="alta__card-t">{{ actual.titulo }}</h2>
              <p class="alta__card-d">
                <template v-if="actual.key === 'persona'">Los datos del documento. Con esto ya se lo puede encontrar en la lista y en el mostrador.</template>
                <template v-else-if="actual.key === 'domicilio'">Si no lo tenés a mano, seguí: se completa después desde su ficha.</template>
                <template v-else-if="actual.key === 'reprocann'">De esto depende qué sigue: si hay que darle entrevista, si está en trámite o si ya puede retirar.</template>
                <template v-else>Revisá que esté todo bien antes de crearlo.</template>
              </p>
            </div>
          </div>

          <div class="alta__card-body">
            <SeccionPersona v-if="actual.key === 'persona'" :form="form" :errores="errores" :duplicado="duplicado"
                            autofocus @dni-listo="verificarDni" />
            <SeccionDomicilio v-else-if="actual.key === 'domicilio'" :form="form" con-entrega />
            <SeccionReprocann v-else-if="actual.key === 'reprocann'" :form="form" :errores="errores" />
            <div v-else class="pf-seccion">
              <SeccionTurno v-if="ofreceTurno" v-model="turno" />

              <div class="resumen">
                <p class="pf-sub">Resumen</p>
                <dl class="resumen__lista">
                  <div class="resumen__fila">
                    <dt><i class="bi bi-person-vcard"></i> Persona</dt>
                    <dd>
                      <strong>{{ nombreCompleto }}</strong><template v-if="form.apodo"> «{{ form.apodo }}»</template>
                      <span class="resumen__sec">DNI {{ dniLegible(form.dni) }}<template v-if="anios !== null"> · {{ anios }} años</template></span>
                      <span v-if="form.telefono || form.email" class="resumen__sec">{{ [form.telefono, form.email].filter(Boolean).join(' · ') }}</span>
                    </dd>
                    <button type="button" class="resumen__editar" @click="irA(0)">Cambiar</button>
                  </div>
                  <div class="resumen__fila">
                    <dt><i class="bi bi-geo-alt"></i> Domicilio</dt>
                    <dd>{{ domicilioTexto || 'Sin cargar' }}</dd>
                    <button type="button" class="resumen__editar" @click="irA(1)">Cambiar</button>
                  </div>
                  <div class="resumen__fila">
                    <dt><i class="bi bi-patch-check"></i> REPROCANN</dt>
                    <dd>
                      <strong>{{ resumenReprocann.titulo }}</strong>
                      <span v-if="form.reprocann_numero && (esAdherente(form) || ['aprobado','vencido'].includes(form.opcion_reprocann))" class="resumen__sec">
                        N° {{ form.reprocann_numero }}<template v-if="form.reprocann_vencimiento"> · vence {{ form.reprocann_vencimiento.split('-').reverse().join('/') }}</template>
                      </span>
                      <span class="resumen__sec">{{ resumenReprocann.detalle }}</span>
                    </dd>
                    <button type="button" class="resumen__editar" @click="irA(2)">Cambiar</button>
                  </div>
                  <div v-if="ofreceTurno" class="resumen__fila">
                    <dt><i class="bi bi-calendar-event"></i> Turno</dt>
                    <dd>{{ turnoTexto || 'Sin turno por ahora' }}</dd>
                  </div>
                </dl>
              </div>

              <label v-if="puedeMandarBienvenida" class="pf-switch">
                <input v-model="mandarBienvenida" type="checkbox" :disabled="!form.email" />
                <span class="pf-switch__track"></span>
                <span>
                  <span class="pf-switch__t">Mandarle el mail de bienvenida</span>
                  <span class="pf-switch__d">{{ form.email ? `A ${form.email}, con la plantilla de la organización.` : 'Hace falta su mail (paso 1).' }}</span>
                </span>
              </label>
            </div>

            <div v-if="errorGeneral" class="pf-aviso pf-aviso--danger" role="alert" style="margin-top:1.25rem">
              <i class="bi bi-exclamation-triangle"></i><div>{{ errorGeneral }}</div>
            </div>
          </div>

          <footer class="alta__acciones">
            <button v-if="paso > 0" type="button" class="btn-sec" @click="atras"><i class="bi bi-arrow-left"></i> Atrás</button>
            <RouterLink v-else to="/pacientes" class="btn-sec">Cancelar</RouterLink>
            <button v-if="actual.key === 'domicilio' && !domicilioTexto" type="button" class="btn-link" @click="siguiente">Saltear</button>
            <button type="submit" class="btn-pri" :disabled="store.saving">
              <DsSpinner v-if="store.saving" :size="15" />
              <template v-if="esUltimo">
                <i v-if="!store.saving" class="bi bi-person-check"></i>
                {{ store.saving ? 'Creando…' : turno ? 'Crear con su turno' : 'Crear paciente' }}
              </template>
              <template v-else>Siguiente <i class="bi bi-arrow-right"></i></template>
            </button>
          </footer>
        </form>
      </main>
    </div>
  </div>
</template>

<style scoped>
.alta { max-width: 1080px; margin: 0 auto; padding: 2rem 1.5rem 3rem; }
.alta__head { margin-bottom: 1.5rem; }
.alta__back { display: inline-flex; align-items: center; gap: .4rem; font-size: .82rem; font-weight: 600; color: var(--c-slate-500); text-decoration: none; }
.alta__back:hover { color: var(--c-slate-900); }
.alta__title { font-family: var(--font-display); font-size: 2rem; font-weight: 700; letter-spacing: -.03em; color: var(--c-slate-900); margin: .5rem 0 0; line-height: 1.1; }
.alta__movil { display: none; }

.alta__main { min-width: 0; }
.alta__layout { display: grid; grid-template-columns: 280px minmax(0, 1fr); gap: 2rem; align-items: start; }

/* ── Riel ── */
.alta__riel { position: sticky; top: 1.5rem; display: flex; flex-direction: column; gap: 1.5rem; }
.alta__riel ol { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; position: relative; }
.alta__riel li { position: relative; }
.alta__riel li:not(:last-child)::after { content: ''; position: absolute; left: 17px; top: 44px; bottom: -6px; width: 2px; background: var(--c-slate-200); }
.riel__paso { display: flex; gap: .85rem; align-items: flex-start; width: 100%; text-align: left; padding: .45rem .5rem .9rem 0; background: none; border: 0; cursor: pointer; font: inherit; color: inherit; border-radius: var(--r-md); }
.riel__paso:disabled { cursor: default; }
.riel__n { flex-shrink: 0; width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; font-weight: 700; font-size: .88rem;
  background: var(--c-paper, #fff); border: 2px solid var(--c-slate-200); color: var(--c-slate-400); position: relative; z-index: 1; transition: all var(--t-base); }
.riel__paso--hecho .riel__n { background: var(--c-leaf-100); border-color: var(--c-leaf-600); color: var(--c-leaf-800); }
.riel__paso--on .riel__n { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; box-shadow: 0 0 0 4px var(--c-leaf-100); }
.riel__txt { display: flex; flex-direction: column; min-width: 0; padding-top: .35rem; }
.riel__t { font-weight: 700; font-size: .92rem; color: var(--c-slate-400); }
.riel__paso--on .riel__t, .riel__paso--hecho .riel__t { color: var(--c-slate-900); }
.riel__d { font-size: .76rem; color: var(--c-slate-500); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 220px; }
.riel__paso:not(:disabled):not(.riel__paso--on):hover .riel__t { text-decoration: underline; }

.riel__ficha { display: flex; gap: .75rem; padding: 1rem; border-radius: var(--r-lg); background: var(--c-paper, #fff); border: 1px solid var(--c-slate-200); box-shadow: var(--sh-1); transition: opacity var(--t-base); }
.riel__ficha--vacia { opacity: .55; }
.riel__avatar { flex-shrink: 0; width: 44px; height: 44px; border-radius: 50%; display: grid; place-items: center; background: var(--c-leaf-800); color: #fff; font-weight: 700; letter-spacing: .02em; }
.riel__ficha-txt { min-width: 0; }
.riel__nombre { font-weight: 700; color: var(--c-slate-900); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.riel__meta { font-size: .76rem; color: var(--c-slate-500); font-family: var(--font-mono); }
.riel__pills { display: flex; gap: .35rem; flex-wrap: wrap; margin-top: .45rem; }

/* ── Tarjeta del paso ── */
.alta__card { background: var(--c-paper, #fff); border: 1px solid var(--c-slate-200); border-radius: var(--r-xl); box-shadow: var(--sh-1); overflow: hidden; }
.alta__card-head { display: flex; gap: 1rem; align-items: flex-start; padding: 1.5rem 1.75rem 0; scroll-margin-top: 1rem; }
.alta__card-ico { flex-shrink: 0; width: 44px; height: 44px; border-radius: var(--r-lg); display: grid; place-items: center; background: var(--c-leaf-50); color: var(--c-leaf-800); font-size: 1.2rem; }
.alta__card-t { margin: 0; font-size: 1.25rem; font-weight: 700; color: var(--c-slate-900); letter-spacing: -.01em; }
.alta__card-d { margin: .25rem 0 0; font-size: .86rem; color: var(--c-slate-500); line-height: 1.5; }
.alta__card-body { padding: 1.5rem 1.75rem 1.75rem; }

.alta__acciones { display: flex; align-items: center; gap: .75rem; padding: 1rem 1.75rem; border-top: 1px solid var(--c-slate-100); background: var(--c-slate-50); }
.alta__acciones .btn-pri { margin-left: auto; }

.btn-pri, .btn-sec, .btn-link { display: inline-flex; align-items: center; justify-content: center; gap: .45rem; min-height: 44px; padding: 0 1.25rem;
  border-radius: var(--r-md); font: inherit; font-weight: 700; font-size: .9rem; cursor: pointer; text-decoration: none; transition: all var(--t-fast); }
.btn-pri { background: var(--c-leaf-800); color: #fff; border: 0; min-width: 150px; }
.btn-pri:hover:not(:disabled) { background: var(--c-leaf-900); }
.btn-pri:disabled { opacity: .6; cursor: not-allowed; }
.btn-sec { background: var(--c-paper, #fff); color: var(--c-slate-700); border: 1px solid var(--c-slate-300); }
.btn-sec:hover { border-color: var(--c-slate-500); color: var(--c-slate-900); }
.btn-link { background: none; border: 0; color: var(--c-slate-500); padding: 0 .5rem; font-weight: 600; }
.btn-link:hover { color: var(--c-slate-900); text-decoration: underline; }

/* ── Resumen ── */
.resumen { border: 1px solid var(--c-slate-200); border-radius: var(--r-lg); padding: 1rem 1.1rem; display: flex; flex-direction: column; gap: .75rem; }
.resumen__lista { margin: 0; display: flex; flex-direction: column; }
.resumen__fila { display: grid; grid-template-columns: 130px minmax(0, 1fr) auto; gap: .75rem; padding: .7rem 0; border-top: 1px solid var(--c-slate-100); align-items: start; }
.resumen__fila:first-child { border-top: 0; padding-top: 0; }
.resumen__fila dt { font-size: .78rem; font-weight: 700; color: var(--c-slate-500); display: flex; gap: .4rem; align-items: center; }
.resumen__fila dd { margin: 0; font-size: .9rem; color: var(--c-slate-900); display: flex; flex-direction: column; gap: .15rem; min-width: 0; }
.resumen__sec { font-size: .8rem; color: var(--c-slate-500); line-height: 1.4; }
.resumen__editar { background: none; border: 0; color: var(--c-leaf-700); font: inherit; font-size: .8rem; font-weight: 700; cursor: pointer; padding: 0; }
.resumen__editar:hover { text-decoration: underline; }

/* ── Teléfono ── */
@media (max-width: 860px) {
  .alta { padding: 1rem 1rem 6.5rem; }
  .alta__title { font-size: 1.5rem; }
  .alta__layout { grid-template-columns: 1fr; gap: 0; }
  .alta__riel { display: none; }
  .alta__movil { display: grid; grid-template-columns: auto 1fr; gap: .15rem .6rem; margin-top: .85rem; align-items: baseline; }
  .alta__movil-n { font-size: .75rem; font-weight: 700; color: var(--c-leaf-700); text-transform: uppercase; letter-spacing: .05em; }
  .alta__movil-t { font-size: .9rem; font-weight: 700; color: var(--c-slate-900); }
  .alta__barra { grid-column: 1 / -1; height: 4px; border-radius: var(--r-pill); background: var(--c-slate-200); overflow: hidden; margin-top: .45rem; }
  .alta__barra-in { height: 100%; background: var(--c-leaf-700); border-radius: inherit; transition: width var(--t-base); }
  .alta__card { border-radius: var(--r-lg); }
  .alta__card-head { padding: 1.1rem 1.1rem 0; }
  .alta__card-ico { width: 38px; height: 38px; font-size: 1rem; }
  .alta__card-t { font-size: 1.1rem; }
  .alta__card-body { padding: 1.1rem; }
  /* Los botones quedan al alcance del pulgar, siempre visibles. */
  .alta__acciones { position: fixed; left: 0; right: 0; bottom: 0; z-index: 50; padding: .75rem 1rem calc(.75rem + env(safe-area-inset-bottom));
    background: var(--c-paper, #fff); border-top: 1px solid var(--c-slate-200); box-shadow: 0 -4px 16px rgba(15, 23, 42, .06); }
  .alta--shell .alta__acciones { bottom: var(--oi-bottom, 72px); padding-bottom: .75rem; }
  .alta--shell { padding-bottom: 6rem; }
  .alta__acciones .btn-pri { flex: 1; }
  .resumen__fila { grid-template-columns: 1fr auto; }
  .resumen__fila dt { grid-column: 1 / -1; }
  .resumen__fila dd { grid-column: 1; }
}
</style>
