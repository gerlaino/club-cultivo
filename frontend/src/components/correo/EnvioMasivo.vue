<script setup>
// Mandar un mismo mail a varias personas.
//
// La selección múltiple es de la INTERFAZ, nunca del `To:`. El backend arma un destinatario por
// persona y manda de a uno: con todos juntos, cada paciente recibiría el padrón completo de la
// organización —nombre y mail de todos los demás—, que es una fuga de datos de salud y no se
// puede deshacer.
import { ref, computed, onMounted } from 'vue'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { listPacientes, fetchEnviosMasivos, crearEnvioMasivo } from '../../lib/api.js'

const props = defineProps({
  plantillas:   { type: Array,  default: () => [] },
  organizacion: { type: String, default: '' },
})

const { success: toastOk, error: toastErr, warning: toastWarn } = useToast()
const { confirm } = useConfirm()

const destino     = ref('pacientes')   // 'pacientes' | 'libre'
const plantillaId = ref(null)
const asunto      = ref('')
const cuerpo      = ref('')
const emailsTexto = ref('')
const enviando    = ref(false)

const pacientes   = ref([])
const cargandoPac = ref(false)
const busqueda    = ref('')
const elegidos    = ref(new Set())

const historial = ref([])
const cupo      = ref({ limite: 0, restante: 0 })

/* ── Pacientes ───────────────────────────────────────────────── */
const pacientesFiltrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  const lista = pacientes.value
  if (!q) return lista
  return lista.filter(p => `${p.apellido} ${p.nombre} ${p.email || ''}`.toLowerCase().includes(q))
})

// Quién no tiene dirección se muestra igual, apagado y con el motivo: es información operativa
// —a esa persona hay que llamarla— y esconderla haría que el total no cierre sin explicación.
const sinEmail = computed(() => [...elegidos.value]
  .map(id => pacientes.value.find(p => p.id === id))
  .filter(p => p && !p.email))

const aEnviar = computed(() => destino.value === 'libre'
  ? emailsValidos.value.length
  : [...elegidos.value].filter(id => pacientes.value.find(p => p.id === id)?.email).length)

const emailsValidos = computed(() =>
  emailsTexto.value.split(/[\s,;]+/).map(e => e.trim()).filter(e => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)))

function alternar(p) {
  const s = new Set(elegidos.value)
  s.has(p.id) ? s.delete(p.id) : s.add(p.id)
  elegidos.value = s
}
function todos()   { elegidos.value = new Set(pacientesFiltrados.value.map(p => p.id)) }
function ninguno() { elegidos.value = new Set() }

/* ── Plantilla ───────────────────────────────────────────────── */
function aplicarPlantilla(id) {
  plantillaId.value = id
  const tpl = props.plantillas.find(p => p.id === id)
  if (!tpl) return
  // El texto va CRUDO, con las llaves: el backend lo resuelve contra cada paciente. Resolverlo
  // acá contra uno solo mandaría el nombre de esa persona a todo el mundo.
  asunto.value = tpl.asunto
  cuerpo.value = tpl.cuerpo
}

/* ── Enviar ──────────────────────────────────────────────────── */
async function enviar() {
  if (!asunto.value.trim() || !cuerpo.value.trim()) return toastErr('Poné asunto y cuerpo.')
  if (!aEnviar.value) return toastErr('No hay a quién mandarle.')

  const ok = await confirm({
    title: `¿Enviar a ${aEnviar.value} destinatario${aEnviar.value !== 1 ? 's' : ''}?`,
    message: 'Cada uno recibe su propio mail — nadie ve las direcciones de los demás. Un mail enviado no se puede deshacer.',
    confirmText: 'Enviar',
  })
  if (!ok) return

  enviando.value = true
  try {
    const { data } = await crearEnvioMasivo({
      destino:      destino.value,
      asunto:       asunto.value,
      cuerpo:       cuerpo.value,
      plantilla_mail_id: plantillaId.value,
      paciente_ids: destino.value === 'pacientes' ? [...elegidos.value] : [],
      emails:       destino.value === 'libre' ? emailsValidos.value : [],
    })
    toastOk(`Enviando a ${data.data.total} destinatarios`)
    if (data.salteados?.length) toastWarn(`Sin dirección de correo: ${data.salteados.join(', ')}`)
    asunto.value = ''; cuerpo.value = ''; emailsTexto.value = ''
    plantillaId.value = null; elegidos.value = new Set()
    cargarHistorial()
  } catch (e) {
    toastErr(e?.response?.data?.error || 'No se pudo enviar')
  } finally {
    enviando.value = false
  }
}

async function cargarHistorial() {
  try {
    const { data } = await fetchEnviosMasivos()
    historial.value = data.data || []
    cupo.value      = data.cupo || cupo.value
  } catch { /* sin módulo o sin permiso: la sección no se muestra */ }
}

onMounted(async () => {
  cargarHistorial()
  cargandoPac.value = true
  try {
    const { data } = await listPacientes({ limite: 500 })
    const arr = Array.isArray(data) ? data : (data.data || [])
    pacientes.value = arr
  } catch { pacientes.value = [] } finally { cargandoPac.value = false }
})

const ESTADOS = {
  pendiente:  { label: 'En cola',   clase: 'em__chip--espera' },
  enviando:   { label: 'Enviando',  clase: 'em__chip--espera' },
  completado: { label: 'Enviado',   clase: 'em__chip--ok' },
  fallido:    { label: 'Falló',     clase: 'em__chip--mal' },
}
const estadoDe = (e) => ESTADOS[e] || { label: e, clase: '' }
// Escribir las llaves literales dentro de una interpolación rompe el parser de Vue: lee el
// `{{` de adentro como una interpolación nueva.
const EJEMPLO_VARIABLE = '{{nombre}}'
const fecha = (d) => d ? new Date(d).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'
</script>

<template>
  <div class="em">
    <!-- A quién -->
    <div class="em__tabs">
      <button class="em__tab" :class="{ 'em__tab--on': destino === 'pacientes' }" @click="destino = 'pacientes'">
        <i class="bi bi-people"></i> A pacientes
      </button>
      <button class="em__tab" :class="{ 'em__tab--on': destino === 'libre' }" @click="destino = 'libre'">
        <i class="bi bi-envelope"></i> A otras direcciones
      </button>
    </div>

    <!-- Pacientes -->
    <div v-if="destino === 'pacientes'" class="em__dest">
      <div class="em__buscar">
        <i class="bi bi-search"></i>
        <input v-model="busqueda" class="em__inp" placeholder="Buscar por nombre, apellido o mail…" />
        <button class="em__lnk" @click="todos">Todos</button>
        <button class="em__lnk" @click="ninguno">Ninguno</button>
      </div>
      <div v-if="cargandoPac" class="em__cargando"><DsSpinner :size="16" /> Cargando pacientes…</div>
      <ul v-else class="em__lista">
        <li v-for="p in pacientesFiltrados" :key="p.id" class="em__pac"
            :class="{ 'em__pac--sin': !p.email }">
          <label class="em__pac-lbl">
            <input type="checkbox" :checked="elegidos.has(p.id)" @change="alternar(p)" />
            <span class="em__pac-nom">{{ p.apellido }}, {{ p.nombre }}</span>
            <span class="em__pac-mail">{{ p.email || 'sin dirección de correo' }}</span>
          </label>
        </li>
      </ul>
    </div>

    <!-- Direcciones libres -->
    <div v-else class="em__dest">
      <label class="em__fld">
        <span class="em__lbl">Direcciones</span>
        <textarea v-model="emailsTexto" class="em__ta" rows="3"
                  placeholder="proveedor@ejemplo.com, otro@ejemplo.com"></textarea>
        <span class="em__hint">Separadas por coma, espacio o salto de línea. Acá no se usan variables: no hay paciente detrás.</span>
      </label>
    </div>

    <!-- Qué -->
    <div v-if="plantillas.length && destino === 'pacientes'" class="em__tpls">
      <span class="em__lbl">Usar una plantilla</span>
      <div class="em__tpl-chips">
        <button v-for="t in plantillas" :key="t.id" class="em__tpl"
                :class="{ 'em__tpl--on': plantillaId === t.id }" @click="aplicarPlantilla(t.id)">
          {{ t.nombre }}
        </button>
      </div>
    </div>

    <label class="em__fld">
      <span class="em__lbl">Asunto</span>
      <input v-model="asunto" class="em__inp em__inp--full" placeholder="Asunto del mail" />
    </label>
    <label class="em__fld">
      <span class="em__lbl">Mensaje</span>
      <textarea v-model="cuerpo" class="em__ta" rows="7" placeholder="Escribí el mensaje…"></textarea>
      <span v-if="destino === 'pacientes'" class="em__hint">
        Las variables como <code>{{ EJEMPLO_VARIABLE }}</code> se resuelven para cada paciente: cada uno recibe el suyo.
      </span>
    </label>

    <div v-if="sinEmail.length" class="em__aviso">
      <i class="bi bi-exclamation-triangle-fill"></i>
      <span>
        <strong>{{ sinEmail.length }}</strong> de los elegidos no tiene dirección de correo y queda afuera:
        {{ sinEmail.map(p => `${p.nombre} ${p.apellido}`).join(', ') }}.
      </span>
    </div>

    <div class="em__pie">
      <div class="em__cuenta">
        <strong>{{ aEnviar }}</strong> destinatario{{ aEnviar !== 1 ? 's' : '' }}
        <span class="em__cupo">· te quedan {{ cupo.restante }} de {{ cupo.limite }} envíos hoy</span>
      </div>
      <button class="em__btn" :disabled="enviando || !aEnviar" @click="enviar">
        <DsSpinner v-if="enviando" :size="14" />
        <i v-else class="bi bi-send"></i>
        {{ enviando ? 'Enviando…' : 'Enviar' }}
      </button>
    </div>

    <!-- Historial -->
    <div v-if="historial.length" class="em__hist">
      <span class="em__lbl">Últimos envíos</span>
      <div class="em__hist-tabla">
        <div v-for="h in historial" :key="h.id" class="em__hist-fila">
          <span class="em__hist-fecha">{{ fecha(h.created_at) }}</span>
          <span class="em__hist-asunto">{{ h.asunto }}</span>
          <span class="em__chip" :class="estadoDe(h.estado).clase">{{ estadoDe(h.estado).label }}</span>
          <span class="em__hist-nums">
            {{ h.enviados }}/{{ h.total }}
            <span v-if="h.fallidos" class="em__hist-mal">· {{ h.fallidos }} sin entregar</span>
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.em { display: flex; flex-direction: column; gap: 1rem; }

.em__tabs { display: flex; gap: .4rem; }
.em__tab { display: inline-flex; align-items: center; gap: .35rem; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .45rem .85rem; font-size: .82rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; transition: all .15s; }
.em__tab--on { background: var(--brand-primary, #1b5e20); border-color: var(--brand-primary, #1b5e20); color: #fff; }

.em__dest { display: flex; flex-direction: column; gap: .5rem; }
.em__buscar { display: flex; align-items: center; gap: .5rem; }
.em__buscar i { color: var(--c-slate-400); }
.em__lnk { background: none; border: none; font-size: .78rem; font-weight: 600; color: var(--brand-primary, #1b5e20); cursor: pointer; padding: 0 .2rem; }
.em__lnk:hover { text-decoration: underline; }

.em__fld { display: flex; flex-direction: column; gap: .3rem; }
.em__lbl { font-size: .78rem; font-weight: 600; color: var(--c-slate-700); }
/* El buscador convive con dos enlaces en la misma fila, así que no se estira; el asunto sí. */
.em__inp--full { flex: 1 1 auto; }
.em__inp, .em__ta { width: 100%; box-sizing: border-box; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .5rem .7rem; font-size: .85rem; color: var(--c-slate-900); font-family: inherit; }
.em__inp:focus, .em__ta:focus { outline: none; border-color: var(--brand-primary, #1b5e20); box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.em__ta { resize: vertical; line-height: 1.6; }
.em__hint { font-size: .72rem; color: var(--c-slate-400); line-height: 1.5; }
.em__hint code { background: var(--c-slate-100); padding: .05em .3em; border-radius: 4px; font-size: .95em; }

.em__cargando { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: var(--c-slate-500); padding: .75rem 0; }
.em__lista { list-style: none; margin: 0; padding: 0; max-height: 260px; overflow-y: auto; border: 1px solid var(--c-slate-200); border-radius: 9px; }
.em__pac { border-bottom: 1px solid var(--c-slate-100); }
.em__pac:last-child { border-bottom: none; }
.em__pac-lbl { display: flex; align-items: center; gap: .55rem; padding: .5rem .7rem; cursor: pointer; font-size: .82rem; }
.em__pac-lbl:hover { background: var(--c-slate-50); }
.em__pac-nom { font-weight: 600; color: var(--c-slate-900); }
.em__pac-mail { margin-left: auto; font-size: .76rem; color: var(--c-slate-400); }
/* Sin dirección se ve, apagado: hay que saber a quién llamar por teléfono. */
.em__pac--sin .em__pac-nom { color: var(--c-slate-400); }
.em__pac--sin .em__pac-mail { color: #b45309; }

.em__tpls { display: flex; flex-direction: column; gap: .35rem; }
.em__tpl-chips { display: flex; flex-wrap: wrap; gap: .35rem; }
.em__tpl { background: var(--c-slate-100); border: 1px solid var(--c-slate-200); border-radius: 7px; padding: .25rem .6rem; font-size: .78rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; }
.em__tpl--on { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; }

.em__aviso { display: flex; align-items: flex-start; gap: .5rem; padding: .65rem .875rem; background: #fffbeb; border: 1px solid #fde68a; border-radius: 9px; font-size: .8rem; color: #b45309; line-height: 1.5; }

.em__pie { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; padding-top: .25rem; border-top: 1px solid var(--c-slate-100); }
.em__cuenta { font-size: .82rem; color: var(--c-slate-700); }
.em__cupo { color: var(--c-slate-400); font-size: .76rem; }
.em__btn { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .55rem 1.2rem; border-radius: 9px; font-size: .85rem; font-weight: 700; cursor: pointer; }
.em__btn:hover:not(:disabled) { background: #144a18; }
.em__btn:disabled { opacity: .5; cursor: not-allowed; }

.em__hist { display: flex; flex-direction: column; gap: .35rem; padding-top: .5rem; border-top: 1px solid var(--c-slate-100); }
.em__hist-tabla { display: flex; flex-direction: column; }
.em__hist-fila { display: grid; grid-template-columns: 96px 1fr auto auto; align-items: center; gap: .6rem; padding: .45rem 0; border-bottom: 1px solid var(--c-slate-50); font-size: .78rem; }
.em__hist-fila:last-child { border-bottom: none; }
@media (max-width: 640px) { .em__hist-fila { grid-template-columns: 1fr auto; } }
.em__hist-fecha { color: var(--c-slate-400); font-variant-numeric: tabular-nums; }
.em__hist-asunto { color: var(--c-slate-900); font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.em__hist-nums { color: var(--c-slate-500); font-variant-numeric: tabular-nums; }
.em__hist-mal { color: #b45309; }
.em__chip { font-size: .68rem; font-weight: 700; padding: .12em .5em; border-radius: 5px; white-space: nowrap; }
.em__chip--ok     { background: #f0fdf4; color: #15803d; }
.em__chip--espera { background: #eff6ff; color: #1d4ed8; }
.em__chip--mal    { background: #fef2f2; color: #dc2626; }
</style>
