<template>
  <div class="msal" v-if="sala">

    <!-- Hero -->
    <div class="msal__hero" :style="{ background: kindGradient(sala.kind) }">
      <div class="msal__hero-kind">{{ kindEmoji(sala.kind) }} {{ kindLabel(sala.kind) }}</div>
      <h2 class="msal__hero-nombre">{{ sala.nombre }}</h2>
      <div class="msal__hero-meta">
        <span>{{ sala.sede?.nombre }}</span>
        <span v-if="lotes.length" class="msal__sep">·</span>
        <span v-if="lotes.length">{{ lotes.length }} lote{{ lotes.length !== 1 ? 's' : '' }}</span>
        <template v-if="sala.m2">
          <span class="msal__sep">·</span>
          <span>{{ sala.m2 }} m²</span>
        </template>
      </div>
    </div>

    <!-- Acciones -->
    <div class="msal__actions">
      <button class="msal__btn-registrar" @click="abrirRegistro()">
        <i class="bi bi-pencil-square"></i>
        {{ esPersonal ? 'Registrar el espacio' : 'Registrar sala' }}
      </button>
      <button class="msal__btn-acciones" @click="showAcciones = true">
        <i class="bi bi-three-dots-vertical"></i>
        Más
      </button>
    </div>

    <!-- Lotes de esta sala -->
    <div class="msal__section-title">Lotes activos</div>
    <div v-if="!lotes.length" class="msal__empty">Sin lotes activos</div>
    <div v-else class="msal__list">
      <RouterLink
        v-for="lote in lotes"
        :key="lote.id"
        :to="`/m/lote-m/${lote.id}`"
        class="msal__card"
      >
        <div class="msal__card-stripe" :style="{ background: estadoColor(lote.estado) }"></div>
        <div class="msal__card-body">
          <div class="msal__card-top">
            <span class="msal__codigo">{{ lote.codigo }}</span><span v-if="lote.automatica" class="chip-auto">Auto</span>
            <span class="msal__badge" :style="{ background: estadoColor(lote.estado)+'20', color: estadoColor(lote.estado) }">
              {{ estadoLabel(lote.estado) }}
            </span>
          </div>
          <div class="msal__card-meta">
            <span>{{ lote.genetica?.nombre || '—' }}</span>
            <span class="msal__dot">·</span>
            <span>{{ lote.plants_count || 0 }} plantas</span>
          </div>
          <div v-if="textoProximoPaso(lote)" class="msal__card-prox">{{ textoProximoPaso(lote) }}</div>
        </div>
        <i class="bi bi-chevron-right msal__chevron"></i>
      </RouterLink>
    </div>

    <!-- Modal registro sala (reutiliza el de la web) -->
    <RegistroSalaModal
      v-model="showRegistroSala"
      :sala="sala"
      :accion-inicial="accionInicial"
    />

    <!-- Sheet: Más acciones -->
    <SheetBottom v-model="showAcciones" title="Acciones">
      <div class="msal__accion-list">
        <button class="msal__accion-item" @click="abrirNuevoLote">
          <span class="msal__accion-ico">➕</span>
          <span class="msal__accion-lbl">Crear lote</span>
          <i class="bi bi-chevron-right msal__accion-arr"></i>
        </button>
        <button class="msal__accion-item" @click="abrirFoto">
          <span class="msal__accion-ico">📷</span>
          <span class="msal__accion-lbl">Tomar foto</span>
          <i class="bi bi-chevron-right msal__accion-arr"></i>
        </button>
        <button class="msal__accion-item" @click="abrirNota">
          <span class="msal__accion-ico">📝</span>
          <span class="msal__accion-lbl">Agregar nota</span>
          <i class="bi bi-chevron-right msal__accion-arr"></i>
        </button>
        <!-- Pasar el espacio de vegetativo a floración: la operación más común de una carpa, y
             hasta el 22-sep-2026 vivía SÓLO en el escritorio. El que cultiva en casa está en el
             teléfono. Mismo endpoint y misma confirmación que la ficha de escritorio. -->
        <button v-if="puedeCambiarFase" class="msal__accion-item" :disabled="cambiandoFase" @click="cambiarFase()">
          <span class="msal__accion-ico">🔄</span>
          <span class="msal__accion-lbl">Pasar a {{ faseLabel(faseDestino) }}</span>
          <i class="bi bi-chevron-right msal__accion-arr"></i>
        </button>
        <button v-if="puedeEditar" class="msal__accion-item" @click="abrirEditar">
          <span class="msal__accion-ico">✏️</span>
          <span class="msal__accion-lbl">Editar {{ salaTxt.corta }}</span>
          <i class="bi bi-chevron-right msal__accion-arr"></i>
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: editar el espacio. Nombre y metros: lo único que cambia con el tiempo. La fase
         va por «Pasar a …», que mueve los lotes y avisa. -->
    <SheetBottom v-model="showEditar" :title="`Editar ${salaTxt.corta}`">
      <div class="msal__sheet-body">
        <div class="msal__field">
          <label class="msal__label">Nombre</label>
          <input v-model.trim="editForm.nombre" class="msal__input" />
        </div>
        <div class="msal__field">
          <label class="msal__label">¿Cuánto mide? <span class="msal__opt">(m², opcional)</span></label>
          <input v-model.number="editForm.m2" type="number" min="0" step="0.1" class="msal__input" :placeholder="esPersonal ? '1' : '4'" />
          <p class="msal__hint">Con esto el rendimiento se puede leer en g/m² y compararse con la ficha de la genética.</p>
        </div>
        <p v-if="editError" class="msal__error">{{ editError }}</p>
        <button class="msal__btn-guardar" :disabled="guardandoEdit || !editForm.nombre" @click="guardarEditar">
          {{ guardandoEdit ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Crear lote. Nuevo o «ya lo tenía» (23-sep-2026): el teléfono sólo sabía crear uno
         que arrancaba hoy, y ni eso — mandaba el estado `semilla`, que no existe, y el backend lo
         rechazaba siempre. La regla es la del escritorio (`NuevoLoteModal`), con la sala fija. -->
    <SheetBottom v-model="showNuevoLote" title="Crear lote">
      <div class="msal__sheet-body">
        <div class="msal__seg" role="radiogroup" aria-label="Qué lote es">
          <button type="button" class="msal__seg-b" :class="{ 'is-on': tipoLote === 'nuevo' }" id="msal-lote-nuevo"
                  role="radio" :aria-checked="tipoLote === 'nuevo'" :disabled="salaVieneDeAntes"
                  @click="!salaVieneDeAntes && (tipoLote = 'nuevo')">Lote nuevo</button>
          <button type="button" class="msal__seg-b" :class="{ 'is-on': tipoLote === 'existente' }" id="msal-lote-existente"
                  role="radio" :aria-checked="tipoLote === 'existente'" @click="tipoLote = 'existente'">Ya lo tenía</button>
        </div>
        <p v-if="salaVieneDeAntes" class="msal__hint">
          En {{ salaTxt.Corta === 'Sala' ? 'una sala' : 'un espacio' }} de floración un lote no nace: viene de antes. Contá cuánto lleva.
        </p>

        <div class="msal__field">
          <label class="msal__label">¿Cómo {{ tipoLote === 'nuevo' ? 'arranca' : 'arrancó' }}?</label>
          <div class="msal__pills">
            <button type="button" class="msal__pill" :class="{ 'is-on': loteForm.origen === 'semilla' }" @click="loteForm.origen = 'semilla'">🌱 Semilla</button>
            <button type="button" class="msal__pill" :class="{ 'is-on': loteForm.origen === 'esqueje' }" @click="loteForm.origen = 'esqueje'">🪴 Esqueje</button>
          </div>
        </div>

        <template v-if="tipoLote === 'existente'">
          <div class="msal__field">
            <label class="msal__label" for="msal-estado">¿En qué fase está?</label>
            <select id="msal-estado" v-model="heredadoEstado" class="msal__input" :disabled="estadosPermitidos.length === 1">
              <option v-for="e in estadosPermitidos" :key="e.value" :value="e.value">{{ e.label }}</option>
            </select>
          </div>
          <div class="msal__dias">
            <div class="msal__field">
              <label class="msal__label" for="msal-dias-raiz">Días enraizando</label>
              <input id="msal-dias-raiz" v-model.number="heredadoDias.semilla_esqueje" type="number" min="0" max="999" inputmode="numeric" class="msal__input" />
            </div>
            <div v-if="['vegetativo', 'floracion'].includes(heredadoEstado)" class="msal__field">
              <label class="msal__label" for="msal-dias-vege">Días en vegetativo</label>
              <input id="msal-dias-vege" v-model.number="heredadoDias.vegetativo" type="number" min="0" max="999" inputmode="numeric" class="msal__input" />
            </div>
            <div v-if="heredadoEstado === 'floracion'" class="msal__field">
              <label class="msal__label" for="msal-dias-flora">Días en floración</label>
              <input id="msal-dias-flora" v-model.number="heredadoDias.floracion" type="number" min="0" max="999" inputmode="numeric" class="msal__input" />
            </div>
          </div>
          <p class="msal__hint">
            <template v-if="inicioEstimado">Arrancó el <strong>{{ inicioEstimado }}</strong>, según los días que cargaste.</template>
            <template v-else>Cargá cuántos días lleva en cada fase: con eso se calcula cuándo arrancó.</template>
          </p>
        </template>
        <div v-else class="msal__field">
          <label class="msal__label" for="msal-inicio">Fecha de inicio</label>
          <input id="msal-inicio" v-model="loteForm.start_date" type="date" :max="hoy" class="msal__input" />
          <span class="msal__hint">Arranca enraizando.</span>
        </div>

        <div class="msal__field">
          <label class="msal__label" for="msal-plantas">Cantidad de plantas</label>
          <input id="msal-plantas" v-model.number="loteForm.plants_count" type="number" min="1" max="5000" inputmode="numeric" class="msal__input" placeholder="1" />
        </div>
        <div class="msal__field">
          <label class="msal__label">Genética <span class="msal__opt">opcional</span></label>
          <select v-model="loteForm.genetica_id" class="msal__input">
            <option value="">Sin especificar</option>
            <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}</option>
          </select>
        </div>
        <div class="msal__field">
          <label class="msal__label">Notas <span class="msal__opt">opcional</span></label>
          <textarea v-model.trim="loteForm.notes" class="msal__input msal__textarea" rows="2" placeholder="Observaciones sobre el lote…"></textarea>
        </div>
        <div v-if="loteError" class="msal__error">{{ loteError }}</div>
        <button class="msal__btn-confirmar" :disabled="savingLote" @click="guardarNuevoLote">
          <i v-if="!savingLote" class="bi bi-check2-circle"></i>
          {{ savingLote ? 'Creando…' : 'Crear lote' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Nota de sala -->
    <SheetBottom v-model="showNota" title="📝 Nota de sala">
      <div class="msal__sheet-body">
        <div class="msal__field">
          <label class="msal__label">Nota</label>
          <textarea v-model="notaContenido" class="msal__input msal__textarea" rows="4" placeholder="Escribí tu observación…"></textarea>
        </div>
        <div v-if="notaError" class="msal__error">{{ notaError }}</div>
        <button class="msal__btn-confirmar" :disabled="savingNota" @click="guardarNota">
          <i v-if="!savingNota" class="bi bi-check2-circle"></i>
          {{ savingNota ? 'Guardando…' : 'Guardar nota' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Fotos del cuarto -->
    <template v-if="fotos.length">
      <div class="msal__section-title">Fotos <span class="msal__count">{{ fotos.length }}</span></div>
      <div class="msal__fotos">
        <a v-for="f in fotos" :key="f.id" :href="f.url" target="_blank" class="msal__foto">
          <img :src="f.url" :alt="f.filename" loading="lazy" />
          <span class="msal__foto-fecha">{{ f.created_at_label }}</span>
        </a>
      </div>
    </template>

    <!-- Input foto oculto -->
    <input ref="fotoInput" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFoto" />
  </div>
  <div v-else-if="loading" class="msal msal--loading"><i class="bi bi-arrow-repeat msal__spin"></i></div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { textoProximoPaso } from '../../lib/loteHelpers.js'
import { getSala, listLotes, createSalaNota, createLote, createLoteHeredado, listGeneticas,
         listFotosSala, uploadFotoSala } from '../../lib/api'
import { useToast }       from '../../composables/useToast'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'
import SheetBottom        from '../../components/cultivador/SheetBottom.vue'
import RegistroSalaModal  from '../../components/salas/RegistroSalaModal.vue'
import { hoyISO } from '../../utils/dates.js'
import { updateSala, cambiarFaseSala } from '../../lib/api'
import { textoCambioDeFase } from '../../lib/textoCambioDeFase.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useAuthStore } from '../../stores/auth'
import { achicarImagen } from '../../lib/imagenes.js'

const route  = useRoute()
const router = useRouter()
const { esPersonal, sala: salaTxt } = useUsoPersonal()
const toast = useToast()
const id    = Number(route.params.id)

const sala    = ref(null)
const lotes   = ref([])
const loading = ref(true)

const showRegistroSala = ref(false)
const { confirm } = useConfirm()
const auth = useAuthStore()

// ── Cambiar la fase del espacio y editarlo, desde el teléfono ────────────────
// La regla de quién puede y sobre qué salas es la misma que en escritorio.
const puedeCambiarFase = computed(() =>
  ['admin', 'supervisor', 'cultivador'].includes(auth.user?.role) &&
  ['vegetativo', 'floracion'].includes(sala.value?.kind))
const puedeEditar  = computed(() => ['admin', 'supervisor'].includes(auth.user?.role) || esPersonal.value)
const faseDestino  = computed(() => (sala.value?.kind === 'vegetativo' ? 'floracion' : 'vegetativo'))
const faseLabel    = (f) => ({ vegetativo: 'Vegetativo', floracion: 'Floración' }[f] || f)
const cambiandoFase = ref(false)

async function cambiarFase(confirmado = false) {
  cambiandoFase.value = true
  try {
    const { data } = await cambiarFaseSala(id, confirmado ? { confirmar_cambio_fase: true } : {})
    showAcciones.value = false
    sala.value = { ...sala.value, kind: data.nueva_fase }
    try { lotes.value = ((await listLotes(id)).data || []).filter(l => l.estado !== 'finalizado') } catch { /* la fase ya cambió */ }
    toast.success(data.lotes_afectados
      ? `${salaTxt.value.Corta} en ${faseLabel(data.nueva_fase)} — ${data.lotes_afectados} lote${data.lotes_afectados === 1 ? '' : 's'}`
      : `${salaTxt.value.Corta} en ${faseLabel(data.nueva_fase)}`)
  } catch (e) {
    const data = e?.response?.data
    if (data?.requiere_confirmacion) {
      cambiandoFase.value = false
      if (await confirm({ ...textoCambioDeFase(data), variant: 'danger' })) return cambiarFase(true)
      return
    }
    toast.error(data?.error || data?.errors?.[0] || 'No se pudo cambiar la fase.')
  } finally {
    cambiandoFase.value = false
  }
}

const showEditar    = ref(false)
const editForm      = ref({ nombre: '', m2: null })
const editError     = ref('')
const guardandoEdit = ref(false)

function abrirEditar() {
  editForm.value = { nombre: sala.value?.nombre || '', m2: sala.value?.m2 ?? null }
  editError.value = ''
  showAcciones.value = false
  showEditar.value = true
}

async function guardarEditar() {
  guardandoEdit.value = true
  editError.value = ''
  try {
    const { data } = await updateSala(id, { nombre: editForm.value.nombre, m2: editForm.value.m2 || null })
    sala.value = { ...sala.value, ...data }
    showEditar.value = false
    toast.success('Guardado ✓')
  } catch (e) {
    editError.value = e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'No se pudo guardar'
  } finally {
    guardandoEdit.value = false
  }
}
// Desde el botón se elige adentro; desde el «+» del teléfono llega `?accion=ambiental` y abre
// derecho en ese formulario.
const accionInicial    = ref(null)
function abrirRegistro(accion = null) { accionInicial.value = accion; showRegistroSala.value = true }
const showAcciones     = ref(false)
const showNuevoLote    = ref(false)
const showNota         = ref(false)
const savingLote       = ref(false)
const savingNota       = ref(false)
const loteError        = ref(null)
const notaError        = ref(null)
const notaContenido    = ref('')
const fotoInput        = ref(null)

const geneticas    = ref([])
// ── Crear lote: nuevo o «ya lo tenía» ─────────────────────────────────────────
// Un lote NUEVO nace ENRAIZANDO, venga de semilla o de esqueje (el origen es un eje aparte de la
// fase), y por eso no puede nacer en una sala de floración. Uno que YA EXISTÍA entra en la fase en
// que está —sólo las que esta sala admite— con los días que lleva en cada una, y el backend
// calcula desde cuándo (`heredado`). La tabla sala⇔fase la manda el backend en /me.
const hoy = hoyISO()
const ESTADOS_HEREDADO = [
  { value: 'enraizado',  label: 'Enraizando' },
  { value: 'vegetativo', label: 'Vegetativo' },
  { value: 'floracion',  label: 'Floración' },
]
const KINDS_POR_ESTADO_FALLBACK = {
  enraizado:  ['vegetativo', 'mixta', 'clon', 'madre'],
  vegetativo: ['vegetativo', 'mixta', 'clon', 'madre'],
  floracion:  ['floracion',  'mixta'],
}
const tipoLote       = ref('nuevo')
const heredadoEstado = ref('vegetativo')
const heredadoDias   = ref({ semilla_esqueje: 0, vegetativo: 0, floracion: 0 })
const salaVieneDeAntes = computed(() => sala.value?.kind === 'floracion')
const geneticaElegida  = computed(() => geneticas.value.find(g => String(g.id) === String(loteForm.value.genetica_id)))
const estadosPermitidos = computed(() => {
  const reglas = auth.user?.reglas_cultivo || {}
  const tabla  = (geneticaElegida.value?.automatica && reglas.kinds_sala_por_estado_automatica) ||
                 reglas.kinds_sala_por_estado || KINDS_POR_ESTADO_FALLBACK
  const kind = sala.value?.kind
  const ok = ESTADOS_HEREDADO.filter(e => (tabla[e.value] || []).includes(kind))
  return ok.length ? ok : ESTADOS_HEREDADO
})
const inicioEstimado = computed(() => {
  const e = heredadoEstado.value, d = heredadoDias.value
  let total = Number(d.semilla_esqueje) || 0
  if (['vegetativo', 'floracion'].includes(e)) total += Number(d.vegetativo) || 0
  if (e === 'floracion') total += Number(d.floracion) || 0
  if (total <= 0) return ''
  const f = new Date(); f.setDate(f.getDate() - total)
  return f.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
})

function emptyLoteForm() {
  return {
    origen:       'semilla',
    start_date:   hoyISO(),
    plants_count: 1,
    genetica_id:  '',
    grow_type:    'sustrato',
    notes:        '',
  }
}
const loteForm = ref(emptyLoteForm())

const KIND_GRADIENT = {
  vegetativo: 'linear-gradient(135deg,#0f2417,#1b5e20)',
  floracion:  'linear-gradient(135deg,#1c1028,#4a1d96)',
  cosecha:    'linear-gradient(135deg,#1c0000,#7f1d1d)',
  cosechado:  'linear-gradient(135deg,#1c0000,#7f1d1d)',
  manicura:   'linear-gradient(135deg,#1c1500,#78350f)',
  curado:     'linear-gradient(135deg,#0c1a33,#1e3a8a)',
  madre:      'linear-gradient(135deg,#042f2e,#0f766e)',
  mixta:      'linear-gradient(135deg,#1e293b,#334155)',
}
const KIND_EMOJI = { vegetativo:'🍃', floracion:'🌸', cosecha:'🌾', cosechado:'🌾', manicura:'✂️', curado:'💊', madre:'🌱', mixta:'🏠' }
const KIND_LABEL = { vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', cosechado:'Cosecha', manicura:'Manicura', curado:'Curado', madre:'Madres', mixta:'Mixta' }
const EC = { semilla:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', curado:'#2563eb' }
const EL = { enraizado: 'Enraizado', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', curado:'Curado' }

const kindGradient = k => KIND_GRADIENT[k] || 'linear-gradient(135deg,#0f172a,#1e293b)'
const kindEmoji    = k => KIND_EMOJI[k] || '🏠'
const kindLabel    = k => KIND_LABEL[k] || k || '—'
const estadoColor  = e => EC[e] || '#64748b'
const estadoLabel  = e => EL[e] || e || '—'

function abrirNuevoLote() {
  loteForm.value  = emptyLoteForm()
  loteError.value = null
  tipoLote.value  = salaVieneDeAntes.value ? 'existente' : 'nuevo'
  heredadoDias.value   = { semilla_esqueje: 0, vegetativo: 0, floracion: 0 }
  heredadoEstado.value = estadosPermitidos.value.find(e => e.value === (sala.value?.kind === 'floracion' ? 'floracion' : 'vegetativo'))?.value
                         || estadosPermitidos.value[0].value
  showAcciones.value  = false
  showNuevoLote.value = true
}

async function guardarNuevoLote() {
  const n = Number(loteForm.value.plants_count)
  if (!Number.isInteger(n) || n < 1) { loteError.value = 'Poné cuántas plantas tiene: al menos 1.'; return }
  savingLote.value = true; loteError.value = null
  try {
    const payload = { ...loteForm.value }
    if (!payload.genetica_id) delete payload.genetica_id
    let data
    if (tipoLote.value === 'existente') {
      delete payload.start_date
      const d = heredadoDias.value
      ;({ data } = await createLoteHeredado(sala.value.id, { ...payload, estado: heredadoEstado.value }, {
        dias_semilla_esqueje: Number(d.semilla_esqueje) || 0,
        dias_vegetativo:      Number(d.vegetativo) || 0,
        dias_floracion:       Number(d.floracion) || 0,
      }))
    } else {
      ;({ data } = await createLote(sala.value.id, { ...payload, estado: 'enraizado' }))
    }
    lotes.value.unshift(data)
    toast.success('Lote creado')
    showNuevoLote.value = false
  } catch (e) {
    loteError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Error al crear lote'
  } finally { savingLote.value = false }
}

function abrirFoto() {
  showAcciones.value = false
  fotoInput.value?.click()
}

// Antes esto era un placeholder VACÍO: el botón abría la cámara, sacabas la foto y no pasaba nada
// —ni se guardaba ni avisaba—. Ahora sube de verdad.
async function subirFoto(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return

  subiendoFoto.value = true
  try {
    const fd = new FormData()
    fd.append('foto', await achicarImagen(file))
    await uploadFotoSala(id, fd)
    toast.success('Foto guardada')
    await cargarFotos()
  } catch (err) {
    toast.error(err?.response?.data?.mensaje || err?.response?.data?.error || 'No se pudo subir la foto')
  } finally { subiendoFoto.value = false }
}

const fotos        = ref([])
const subiendoFoto = ref(false)
async function cargarFotos() {
  try { const { data } = await listFotosSala(id); fotos.value = data || [] } catch { fotos.value = [] }
}

function abrirNota() {
  notaContenido.value = ''
  notaError.value     = null
  showAcciones.value  = false
  showNota.value      = true
}

async function guardarNota() {
  if (!notaContenido.value.trim()) { notaError.value = 'Escribí algo antes de guardar'; return }
  savingNota.value = true; notaError.value = null
  try {
    await createSalaNota(id, { nota: { contenido: notaContenido.value } })
    toast.success('Nota guardada')
    showNota.value = false
    notaContenido.value = ''
  } catch { notaError.value = 'Error al guardar' } finally { savingNota.value = false }
}

onMounted(async () => {
  try {
    const [salaRes, lotesRes, geneticasRes] = await Promise.allSettled([getSala(id), listLotes(id), listGeneticas()])
    if (salaRes.status === 'fulfilled') sala.value = salaRes.value.data
    if (lotesRes.status === 'fulfilled')
      lotes.value = (lotesRes.value.data || []).filter(l => l.estado !== 'finalizado')
    if (geneticasRes.status === 'fulfilled') geneticas.value = geneticasRes.value.data || []
  } catch {} finally { loading.value = false }
  cargarFotos()
  // Llegó desde el «+» con una acción: abre el registro en ese formulario y limpia la URL.
  const accion = route.query.accion
  if (accion && sala.value) {
    router.replace({ path: route.path })
    abrirRegistro(String(accion))
  }
})
</script>

<style scoped>
.msal { padding: 0 0 2rem; }
.msal--loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.msal__spin { font-size: 2rem; color: var(--c-slate-400); animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.msal__hero { padding: 1.25rem 1rem 1.1rem; }
.msal__hero-kind   { font-size: .72rem; font-weight: 700; color: rgba(255,255,255,.7); margin-bottom: .4rem; text-transform: uppercase; letter-spacing: .06em; }
.msal__hero-nombre { font-size: 1.25rem; font-weight: 800; color: #fff; margin: 0 0 .3rem; }
.msal__hero-meta   { font-size: .78rem; color: rgba(255,255,255,.6); display: flex; gap: .4rem; }
.msal__sep { opacity: .4; }

.msal__actions { display: flex; gap: .75rem; padding: 1rem; }
.msal__btn-registrar {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none; padding: .875rem;
  border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.msal__btn-acciones {
  display: flex; align-items: center; gap: .4rem;
  background: #fff; color: #374151; border: 1.5px solid var(--c-slate-200);
  padding: .875rem 1rem; border-radius: 12px;
  font-size: .875rem; font-weight: 600; cursor: pointer; white-space: nowrap;
  -webkit-tap-highlight-color: transparent;
}

.msal__section-title { font-size: .7rem; font-weight: 700; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .06em; padding: .75rem 1rem .5rem; }
.msal__empty { padding: .75rem 1rem; color: var(--c-slate-400); font-size: .82rem; text-align: center; }
.msal__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.msal__card { display: flex; align-items: center; background: #fff; border-radius: 14px; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; overflow: hidden; -webkit-tap-highlight-color: transparent; }
.msal__card-stripe { width: 4px; align-self: stretch; flex-shrink: 0; }
.msal__card-body { flex: 1; padding: .875rem .75rem; min-width: 0; }
.msal__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.msal__codigo { font-size: .92rem; font-weight: 800; color: var(--c-slate-900); font-family: monospace; }
.msal__badge { font-size: .62rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }
.msal__card-meta { font-size: .72rem; color: var(--c-slate-500); display: flex; gap: .3rem; }
.msal__card-prox { font-size: .72rem; font-weight: 600; color: var(--c-leaf-700, #2d4a3e); margin-top: .15rem; }
.msal__dot { color: #d1d5db; }
.msal__chevron { color: #d1d5db; font-size: .8rem; padding-right: .875rem; flex-shrink: 0; }

/* Acciones sheet */
.msal__accion-list { display: flex; flex-direction: column; gap: 2px; }
.msal__accion-item {
  display: flex; align-items: center; gap: .875rem;
  height: 56px; padding: 0 .5rem;
  border-radius: 10px; border: none; background: none;
  font-size: .95rem; font-weight: 500; color: var(--c-slate-900);
  cursor: pointer; text-align: left; width: 100%;
  -webkit-tap-highlight-color: transparent;
  transition: background .1s;
}
.msal__accion-item:active { background: var(--c-slate-100); }
.msal__accion-ico { font-size: 1.2rem; width: 28px; text-align: center; flex-shrink: 0; }
.msal__accion-lbl { flex: 1; }
.msal__accion-arr { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }

/* Sheet contenido */
.msal__sheet-body { display: flex; flex-direction: column; gap: .875rem; }
.msal__field { display: flex; flex-direction: column; gap: .3rem; }
.msal__label {
  font-size: .72rem; font-weight: 700; color: #374151;
  text-transform: uppercase; letter-spacing: .04em;
  display: flex; align-items: center; gap: .4rem;
}
.msal__opt { font-weight: 400; text-transform: none; color: var(--c-slate-400); font-size: .68rem; }
.msal__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200);
  border-radius: 9px; padding: .65rem .875rem;
  font-size: .9rem; color: var(--c-slate-900); outline: none;
  width: 100%; box-sizing: border-box;
}
.msal__input:focus { border-color: #1b5e20; }
.msal__textarea { resize: none; font-family: inherit; }
.msal__row2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.msal__hint { font-size: .72rem; color: var(--c-slate-400); line-height: 1.35; }
.msal__btn-guardar {
  width: 100%; padding: .8rem; border: none; border-radius: 12px; background: #1b5e20; color: #fff;
  font-size: .9rem; font-weight: 700; cursor: pointer;
}
.msal__btn-guardar:disabled { opacity: .5; }
.msal__error {
  background: #fef2f2; color: #dc2626;
  border: 1px solid #fecaca; border-radius: 8px;
  padding: .5rem .75rem; font-size: .8rem;
}
.msal__btn-confirmar {
  width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .9rem; border-radius: 12px;
  font-size: .95rem; font-weight: 700; cursor: pointer;
}
.msal__btn-confirmar:disabled { opacity: .6; }
.msal__seg { display: grid; grid-template-columns: 1fr 1fr; border: 1.5px solid var(--c-slate-200); border-radius: 10px; overflow: hidden; }
.msal__seg-b { background: #fff; border: none; padding: .6rem .5rem; font-size: .85rem; font-weight: 700; color: var(--c-slate-600); font-family: inherit; }
.msal__seg-b + .msal__seg-b { border-left: 1.5px solid var(--c-slate-200); }
.msal__seg-b.is-on { background: #1b5e20; color: #fff; }
.msal__seg-b:disabled { opacity: .45; }
.msal__pills { display: flex; gap: .5rem; }
.msal__pill { flex: 1; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem; font-size: .85rem; font-weight: 600; color: var(--c-slate-700); font-family: inherit; }
.msal__pill.is-on { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.msal__dias { display: grid; grid-template-columns: repeat(auto-fit, minmax(96px, 1fr)); gap: .5rem; }
.msal__info-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 9px; padding: .6rem .875rem; font-size: .8rem; color: #15803d; }
</style>

<style scoped>
.msal__fotos {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(104px, 1fr));
  gap: .45rem; padding: 0 .75rem .75rem;
}
.msal__foto { position: relative; display: block; border-radius: 10px; overflow: hidden; }
.msal__foto img { width: 100%; aspect-ratio: 1; object-fit: cover; display: block; }
.msal__foto-fecha {
  position: absolute; left: 0; right: 0; bottom: 0;
  background: linear-gradient(transparent, rgba(0,0,0,.65));
  color: #fff; font-size: .6rem; padding: .5rem .35rem .2rem;
}
</style>
