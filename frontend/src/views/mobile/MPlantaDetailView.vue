<template>
  <div v-if="loading" class="mpd--loading">
    <i class="bi bi-arrow-repeat mpd__spin" aria-hidden="true"></i>
  </div>

  <div v-else-if="!planta" class="mpd--empty">
    <div class="mpd__empty-title">Planta no encontrada</div>
    <div class="mpd__empty-desc">No existe una planta con este ID o no tenés acceso.</div>
    <button class="mpd__empty-back" @click="router.back()">← Volver</button>
  </div>

  <div class="mpd" v-else>

    <!-- Hero -->
    <div class="mpd__hero">
      <div class="mpd__hero-top">
        <span class="mpd__hero-estado" :style="{ background: estadoColor(planta.state) }">{{ estadoPlantaLabel(planta) }}</span>
        <button v-if="planta.codigo_qr" type="button" class="mpd__hero-etiqueta" :disabled="generandoEtiqueta" @click="imprimirEtiqueta(planta)">
          <i class="bi bi-qr-code" aria-hidden="true"></i> Etiqueta
        </button>
      </div>
      <h2 class="mpd__hero-nombre">
        {{ planta.nombre || planta.codigo_qr }}
        <span v-if="esPersonal && lote" class="mpd__chip" :class="lote.automatica ? 'mpd__chip--auto' : 'mpd__chip--foto'">{{ lote.automatica ? 'Auto' : 'Foto' }}</span>
      </h2>
      <div class="mpd__hero-meta">
        <span v-if="!esPersonal && planta.lote?.codigo">{{ planta.lote.codigo }}</span>
        <span v-if="!esPersonal && planta.genetica?.nombre" class="mpd__sep">·</span>
        <span v-if="planta.genetica?.nombre">{{ planta.genetica.nombre }}</span>
        <template v-if="esPersonal">
          <span class="mpd__sep">·</span><span>de {{ planta.origen === 'esqueje' ? 'esqueje' : 'semilla' }}</span>
          <template v-if="planta.lote?.sala?.nombre"><span class="mpd__sep">·</span><span>{{ planta.lote.sala.nombre }}</span></template>
        </template>
      </div>
      <!-- El reloj: una auto cuenta su ciclo entero; una foto, los días de la fase. -->
      <div v-if="esPersonal && ciclo" class="mpd__ciclo">
        <div class="mpd__ciclo-txt"><strong>{{ ciclo.dia }}</strong><span>{{ ciclo.de }}</span></div>
        <div v-if="ciclo.pct != null" class="mpd__ciclo-barra"><div :style="{ width: `${ciclo.pct}%` }"></div></div>
      </div>
    </div>

    <!-- Autocultivo: lo de todos los días, a un toque. Regar dice cuánto y con qué. -->
    <div v-if="esPersonal" class="mpd__rapidas">
      <button type="button" class="mpd__rapida mpd__rapida--principal" @click="showRiegoLote = true">
        <i class="bi bi-droplet-fill" aria-hidden="true"></i> Regar
      </button>
      <button type="button" class="mpd__rapida" :disabled="subiendoFoto" @click="pedirFoto"><i class="bi bi-camera" aria-hidden="true"></i> {{ subiendoFoto ? 'Subiendo…' : 'Foto' }}</button>
      <button type="button" class="mpd__rapida" @click="showRegistrar = true"><i class="bi bi-pencil" aria-hidden="true"></i> Nota</button>
      <button type="button" class="mpd__rapida" @click="showMas = true"><i class="bi bi-three-dots" aria-hidden="true"></i> Más</button>
    </div>

    <!-- Organización: como siempre (registrar + acciones), con la foto y el descarte andando. -->
    <div v-else class="mpd__actions">
      <button class="mpd__btn-registrar" @click="showRegistrar = true">
        <i class="bi bi-pencil-square"></i>
        Registrar actividad
      </button>
      <button class="mpd__btn-acciones" @click="showMas = true">
        <i class="bi bi-three-dots-vertical"></i>
        Acciones
      </button>
    </div>

    <!-- Lo que viene (lo calcula el backend: `proximo_paso` del lote). -->
    <div v-if="esPersonal && textoProximoPaso(lote)" class="mpd__card">
      <div class="mpd__card-title">Lo que viene</div>
      <p class="mpd__viene">{{ textoProximoPaso(lote) }}</p>
    </div>

    <!-- Fotos de la planta -->
    <div v-if="planta.fotos?.length" class="mpd__card">
      <div class="mpd__card-title">Fotos <span class="mpd__count">{{ planta.fotos.length }}</span></div>
      <div class="mpd__fotos">
        <a v-for="f in planta.fotos.slice(0, 9)" :key="f.id" :href="f.url" target="_blank" rel="noopener" class="mpd__foto">
          <img :src="f.url" :alt="`Foto del ${f.created_at_label}`" loading="lazy" />
        </a>
      </div>
    </div>

    <!-- Info básica (en una organización) -->
    <div v-if="!esPersonal" class="mpd__card">
      <div class="mpd__card-title">Información</div>
      <div class="mpd__info-grid">
        <div class="mpd__info-item">
          <span class="mpd__info-label">Código QR</span>
          <span class="mpd__info-val mpd__mono">{{ planta.codigo_qr || '—' }}</span>
        </div>
        <div class="mpd__info-item" v-if="planta.lote?.sala?.nombre">
          <span class="mpd__info-label">Sala</span>
          <span class="mpd__info-val">{{ planta.lote.sala.nombre }}</span>
        </div>
        <div class="mpd__info-item" v-if="planta.es_seleccion">
          <span class="mpd__info-label">Selección</span>
          <span class="mpd__info-val">Planta madre</span>
        </div>
      </div>
    </div>

    <!-- Último registro -->
    <div v-if="ultimoRegistro" class="mpd__card">
      <div class="mpd__card-title">Último registro</div>
      <div class="mpd__ultimo">
        <div class="mpd__ultimo-fecha">{{ formatFecha(ultimoRegistro.created_at) }}</div>
        <div v-if="ultimoRegistro.metadata?.estado_salud" class="mpd__ultimo-item">
          Salud: <strong>{{ saludLabel(ultimoRegistro.metadata.estado_salud) }}</strong>
        </div>
        <div v-if="ultimoRegistro.metadata?.altura_cm" class="mpd__ultimo-item">
          Altura: <strong>{{ ultimoRegistro.metadata.altura_cm }} cm</strong>
        </div>
        <div v-if="ultimoRegistro.description" class="mpd__ultimo-notas">{{ ultimoRegistro.description }}</div>
      </div>
    </div>

    <!-- Autocultivo: lo que recibió en los riegos (con las plantas que se cargaron junto con ella). -->
    <div v-if="esPersonal && planta.lote?.id" class="mpd__card">
      <div class="mpd__card-title">Lo que le diste en los riegos</div>
      <LoteNutricionSection :lote-id="planta.lote.id" :version="versionNutricion" :con-comparar="false" />
    </div>

    <!-- Historial reciente -->
    <div class="mpd__card">
      <div class="mpd__card-title">{{ esPersonal ? 'Diario' : 'Historial reciente' }}</div>
      <div v-if="!activities.length" class="mpd__hist-empty">Sin actividades registradas</div>
      <div v-else class="mpd__hist-list">
        <div v-for="a in activities.slice(0, 8)" :key="a.id" class="mpd__hist-item">
          <div class="mpd__hist-dot" :style="{ background: actColor(a.activity_type) }"></div>
          <div class="mpd__hist-info">
            <div class="mpd__hist-tipo">{{ actLabel(a.activity_type) }}</div>
            <div class="mpd__hist-fecha">{{ formatFecha(a.created_at) }}</div>
          </div>
          <div v-if="detalleAct(a)" class="mpd__hist-desc">{{ detalleAct(a) }}</div>
        </div>
      </div>
    </div>

    <!-- Autocultivo: cosechar ESTA planta; las otras que se cargaron con ella siguen. -->
    <button v-if="esPersonal && lote?.puede_cosechar && ['vegetativo', 'floracion'].includes(planta.state)" type="button"
            class="mpd__cosechar" @click="abrirCosecha">Cosechar esta planta</button>

    <!-- Más -->
    <SheetBottom v-model="showMas" :title="esPersonal ? 'Más' : 'Acciones'">
      <div class="mpd__mas">
        <button v-if="!esPersonal" type="button" class="mpd__mas-item" :disabled="subiendoFoto" @click="showMas = false; pedirFoto()">
          <i class="bi bi-camera" aria-hidden="true"></i> Agregar foto
        </button>
        <button v-if="esPersonal" type="button" class="mpd__mas-item" @click="abrirRenombrar">
          <i class="bi bi-pencil" aria-hidden="true"></i> Cambiarle el nombre
        </button>
        <RouterLink v-if="planta.lote?.id" :to="`/m/lote-m/${planta.lote.id}`" class="mpd__mas-item">
          <i class="bi bi-journal-text" aria-hidden="true"></i> {{ esPersonal ? 'Todo el registro (con las que se cargaron juntas)' : 'Ver el lote' }}
        </RouterLink>
        <button v-if="planta.state !== 'descartada' && planta.state !== 'cosechado'" type="button" class="mpd__mas-item mpd__mas-item--peligro" @click="showMas = false; showDescartar = true">
          <i class="bi bi-trash" aria-hidden="true"></i> Descartar planta
        </button>
      </div>
    </SheetBottom>

    <!-- Cambiar nombre -->
    <SheetBottom v-model="showRenombrar" title="Cambiarle el nombre">
      <div class="mpd__sheet">
        <label class="mpd__label" for="mpd-nombre">Nombre</label>
        <input id="mpd-nombre" v-model.trim="nuevoNombre" class="mpd__input" maxlength="60" />
        <button type="button" class="mpd__btn" :disabled="!nuevoNombre || guardando" @click="guardarNombre">{{ guardando ? 'Guardando…' : 'Guardar' }}</button>
      </div>
    </SheetBottom>

    <!-- Descartar (pide motivo, como en escritorio) -->
    <SheetBottom v-model="showDescartar" title="Descartar planta">
      <div class="mpd__sheet">
        <label class="mpd__label" for="mpd-motivo">¿Qué pasó?</label>
        <textarea id="mpd-motivo" v-model.trim="motivoDescarte" class="mpd__input mpd__textarea" rows="3" placeholder="No prendió, plaga, era macho…"></textarea>
        <button type="button" class="mpd__btn mpd__btn--peligro" :disabled="!motivoDescarte || guardando" @click="descartar">{{ guardando ? 'Descartando…' : 'Descartar' }}</button>
      </div>
    </SheetBottom>

    <!-- Cosechar una sola -->
    <SheetBottom v-model="showCosecha" :title="`Cosechar ${planta.nombre}`">
      <div class="mpd__sheet">
        <p v-if="(lote?.plants_count || 1) > 1" class="mpd__hint">Las otras plantas que se cargaron con ésta siguen como están.</p>
        <label class="mpd__label" for="mpd-humedo">Peso en húmedo <span class="mpd__opt">gramos, opcional</span></label>
        <input id="mpd-humedo" v-model.number="pesoHumedo" type="number" min="0" step="1" inputmode="decimal" class="mpd__input" placeholder="212" />
        <p class="mpd__hint">Si no la pesaste, dejalo vacío: el seco lo cargás cuando la secás. Conserva su QR para la etiqueta del secado o del frasco.</p>
        <button type="button" class="mpd__btn" :disabled="cosechando" @click="cosechar(false)">{{ cosechando ? 'Cosechando…' : 'Cosechar' }}</button>
        <button type="button" class="mpd__btn mpd__btn--linea" :disabled="cosechando" @click="cosechar(true)">Cosechar e imprimir etiqueta</button>
      </div>
    </SheetBottom>

    <!-- Modal registro planta (reutiliza el de la web) -->
    <RegistroPlantaModal
      v-model="showRegistrar"
      :planta="planta"
      :registros-hoy="registrosHoy"
      @saved="recargarActividades"
      @regar-lote="showRiegoLote = true"
    />
    <!-- El riego es del lote: desde la planta se abre el registro de riego de su lote. -->
    <RegistroLoteModal
      v-if="planta?.lote"
      v-model="showRiegoLote"
      :lote="planta.lote"
      accion-inicial="riego"
      @saved="versionNutricion++"
    />

    <input ref="inputFoto" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFoto" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPlant, getPlantActivities, getLote, addPlantFoto, updatePlant, descartarPlant, cosecharPlantas } from '../../lib/api'
import { estadoPlantaLabel, textoProximoPaso } from '../../lib/loteHelpers'
import { achicarImagen } from '../../lib/imagenes.js'
import { useToast }          from '../../composables/useToast'
import { useUsoPersonal }    from '../../composables/useUsoPersonal.js'
import { useEtiquetaPlanta } from '../../composables/useEtiquetaPlanta.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'
import SheetBottom           from '../../components/cultivador/SheetBottom.vue'
import RegistroPlantaModal   from '../../components/plants/RegistroPlantaModal.vue'
import RegistroLoteModal     from '../../components/lotes/registro/RegistroLoteModal.vue'
import LoteNutricionSection  from '../../components/lotes/LoteNutricionSection.vue'

const route  = useRoute()
const router = useRouter()
const toast  = useToast()
const { esPersonal } = useUsoPersonal()
const { imprimir: imprimirEtiqueta, generando: generandoEtiqueta } = useEtiquetaPlanta()
const id = Number(route.params.id)

// Mismas etiquetas que la vista de escritorio (`SALUD_META`), que son los cinco valores del enum.
const SALUD_LABEL = { excelente: 'Excelente', bueno: 'Bueno', regular: 'Regular', malo: 'Malo', critico: 'Crítico' }
const saludLabel = (s) => SALUD_LABEL[s] || s || '—'

const planta     = ref(null)
const lote       = ref(null)
const activities = ref([])
const loading    = ref(true)
const showRegistrar = ref(false)
const showRiegoLote = ref(false)
const showMas       = ref(false)
const versionNutricion = ref(0)

const EC = { enraizado: 'var(--c-ink-500)', vegetativo: 'var(--c-leaf-600)', floracion: 'var(--c-gold-500)', cosechado: 'var(--c-rust-600)', descartada: 'var(--c-ink-500)' }
const estadoColor = e => EC[e] || 'var(--c-ink-500)'

// La planta ve también lo que se registró en su lote (riegos de la carpa, cambios de fase, notas):
// el backend los manda con `activity_type` del lote. Mostrar el código crudo («lote_fase») era un bug.
const AC = { registro_planta: 'var(--c-sky-600)', measurement: 'var(--c-leaf-600)', transplant: 'var(--c-amber-500)',
             registro_ambiental_lote: 'var(--c-sky-600)', lote_fase: 'var(--c-leaf-700)', lote_alerta: 'var(--c-rust-600)' }
const AL = { registro_planta: 'Registro', measurement: 'Medición', transplant: 'Trasplante',
             registro_ambiental_lote: 'Riego y registro', lote_fase: 'Cambio de fase', lote_actividad: 'Actividad',
             lote_alerta: 'Alerta', lote_nota: 'Nota', note: 'Nota', photo: 'Foto', watering: 'Riego', pruning: 'Poda', harvest: 'Cosecha' }
const actColor = t => AC[t] || 'var(--c-ink-300)'
const actLabel = t => AL[t] || t || '—'

const registrosHoy = computed(() => {
  const hoy = new Date().toDateString()
  return activities.value.filter(a => new Date(a.created_at).toDateString() === hoy).map(a => a.activity_type)
})
const ultimoRegistro = computed(() => activities.value.find(a => a.activity_type === 'registro_planta'))

// El reloj de la planta: lo dice el backend (días de ciclo y objetivo del lote, días en fase de la planta).
const ciclo = computed(() => {
  const l = lote.value
  if (!l) return null
  if (l.automatica && l.dias_ciclo != null) {
    const obj = l.dias_ciclo_objetivo
    return { dia: `Día ${l.dias_ciclo}`, de: obj ? `de unos ${obj}` : 'de su ciclo', pct: obj ? Math.min(100, Math.round(l.dias_ciclo / obj * 100)) : null }
  }
  const p = planta.value
  const dias = p.state === 'floracion' && p.fecha_floracion ? diasDesde(p.fecha_floracion)
    : p.state === 'vegetativo' && p.fecha_vegetativo ? diasDesde(p.fecha_vegetativo)
    : p.dias_desde_germinacion
  return dias != null ? { dia: `Día ${Math.max(0, dias)}`, de: estadoPlantaLabel(p).toLowerCase(), pct: null } : null
})
function diasDesde(fecha) {
  const [y, m, d] = String(fecha).slice(0, 10).split('-').map(Number)
  const desde = new Date(y, m - 1, d)
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  return Math.max(0, Math.round((hoy - desde) / 86400000))
}

async function cargar() {
  try {
    const [pr, ar] = await Promise.all([getPlant(id), getPlantActivities(id)])
    planta.value     = pr.data
    activities.value = ar.data || []
    if (planta.value?.lote?.id) {
      try { lote.value = (await getLote(planta.value.lote.id)).data } catch { lote.value = null }
    }
  } catch { /* queda lo que había */ } finally { loading.value = false }
}
onMounted(cargar)
useRecargaEnCambios(['plantas', 'lotes'], cargar)

async function recargarActividades() {
  const { data } = await getPlantActivities(id)
  activities.value = data || []
}

// Un riego de la carpa dice lo que recibió ESTA planta (si se regó por planta) y con qué valores.
function detalleAct(a) {
  const m = a.metadata || {}
  if (a.activity_type !== 'registro_ambiental_lote') return a.description || ''
  const partes = []
  if (m.riego_planta?.texto) partes.push(m.riego_planta.texto)
  if (m.ph) partes.push(`pH ${m.ph}`)
  if (m.ec) partes.push(`EC ${m.ec}`)
  if (m.temperatura) partes.push(`${m.temperatura} °C`)
  if (m.humedad) partes.push(`${m.humedad} %`)
  if (a.description) partes.push(a.description)
  return partes.join(' · ')
}

function formatFecha(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

// ── Foto: se hacía sólo en escritorio y el botón del teléfono decía «usá la web». Una foto es de
// todos los días: tiene que estar acá. Se achica antes de subir (`lib/imagenes.js`).
const inputFoto = ref(null)
const subiendoFoto = ref(false)
function pedirFoto() { inputFoto.value?.click() }
async function subirFoto(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  subiendoFoto.value = true
  try {
    const fd = new FormData()
    fd.append('foto', await achicarImagen(file))
    await addPlantFoto(id, fd)
    planta.value = (await getPlant(id)).data
    toast.success('Foto guardada')
  } catch (err) {
    toast.error(err?.response?.data?.mensaje || err?.response?.data?.error || 'No se pudo subir la foto')
  } finally { subiendoFoto.value = false }
}

// ── Nombre y descarte ─────────────────────────────────────────────────────────────────────────
const guardando = ref(false)
const showRenombrar = ref(false)
const nuevoNombre = ref('')
function abrirRenombrar() { nuevoNombre.value = planta.value?.nombre || ''; showMas.value = false; showRenombrar.value = true }
async function guardarNombre() {
  guardando.value = true
  try {
    await updatePlant(id, { nombre: nuevoNombre.value })
    planta.value = { ...planta.value, nombre: nuevoNombre.value }
    showRenombrar.value = false
    toast.success('Nombre cambiado')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo cambiar el nombre')
  } finally { guardando.value = false }
}

const showDescartar = ref(false)
const motivoDescarte = ref('')
async function descartar() {
  guardando.value = true
  try {
    await descartarPlant(id, motivoDescarte.value)
    showDescartar.value = false
    toast.success('Planta descartada')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo descartar')
  } finally { guardando.value = false }
}

// ── Cosechar ESTA planta (`cosechar_plantas` con una sola): las otras del lote siguen. ───────
const showCosecha = ref(false)
const pesoHumedo  = ref(null)
const cosechando  = ref(false)
function abrirCosecha() { pesoHumedo.value = null; showCosecha.value = true }
async function cosechar(conEtiqueta) {
  cosechando.value = true
  try {
    const payload = { plantas_ids: [id] }
    if (Number(pesoHumedo.value) > 0) payload.peso_total_g = Number(pesoHumedo.value)
    await cosecharPlantas(planta.value.lote.id, payload)
    showCosecha.value = false
    toast.success(`${planta.value.nombre} cosechada`)
    if (conEtiqueta) await imprimirEtiqueta(planta.value)
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo cosechar')
  } finally { cosechando.value = false }
}
</script>

<style scoped>
.mpd { padding: 0 0 2rem; }
.mpd--loading, .mpd--empty { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .5rem; padding: 3rem 1rem; text-align: center; color: var(--c-ink-500); }
.mpd__spin { font-size: 1.6rem; animation: mpd-spin .8s linear infinite; }
@keyframes mpd-spin { to { transform: rotate(360deg); } }
.mpd__empty-title { font-weight: 700; color: var(--c-ink-900); }
.mpd__empty-desc { font-size: .85rem; }
.mpd__empty-back { margin-top: .5rem; border: 0; background: none; color: var(--c-leaf-700); font-weight: 600; }

.mpd__hero { background: linear-gradient(135deg, var(--c-leaf-900), var(--c-leaf-700)); color: var(--c-slate-50); padding: 18px 16px 20px; border-radius: 0 0 22px 22px; display: flex; flex-direction: column; gap: 8px; }
.mpd__hero-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.mpd__hero-estado { font-size: .72rem; font-weight: 700; padding: 3px 10px; border-radius: 999px; color: var(--c-slate-50); }
.mpd__hero-etiqueta { min-height: 36px; padding: 0 12px; border-radius: 10px; border: 1px solid rgba(255, 255, 255, .4); background: transparent; color: inherit; font: inherit; font-size: .82rem; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }
.mpd__hero-nombre { margin: 0; font-size: 1.6rem; font-weight: 800; letter-spacing: -.02em; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.mpd__hero-meta { font-size: .86rem; opacity: .9; display: flex; flex-wrap: wrap; gap: 4px; }
.mpd__sep { opacity: .6; }
.mpd__chip { font-size: .7rem; font-weight: 700; padding: 3px 9px; border-radius: 999px; }
.mpd__chip--auto { background: var(--c-amber-100); color: var(--c-gold-500); }
.mpd__chip--foto { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mpd__ciclo { display: flex; flex-direction: column; gap: 6px; margin-top: 4px; }
.mpd__ciclo-txt { display: flex; justify-content: space-between; font-size: .86rem; }
.mpd__ciclo-txt span { opacity: .8; }
.mpd__ciclo-barra { height: 8px; border-radius: 4px; background: rgba(255, 255, 255, .18); overflow: hidden; }
.mpd__ciclo-barra div { height: 100%; border-radius: 4px; background: var(--c-leaf-300); }

.mpd__rapidas { display: grid; grid-template-columns: 1.3fr 1fr 1fr 1fr; gap: 8px; padding: 14px 16px 4px; }
.mpd__rapida {
  min-height: 60px; border-radius: 14px; border: 1px solid var(--c-leaf-100); background: var(--c-slate-50); color: var(--c-ink-900);
  font: inherit; font-size: .82rem; font-weight: 600; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px;
}
.mpd__rapida i { font-size: 1.15rem; color: var(--c-leaf-700); }
.mpd__rapida--principal { border: 2px solid var(--c-leaf-700); background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mpd__rapida--principal i { color: var(--c-sky-600); }

.mpd__actions { display: flex; gap: 8px; padding: 14px 16px 4px; }
.mpd__btn-registrar { flex: 1; min-height: 48px; border-radius: 12px; border: 0; background: var(--c-leaf-700); color: var(--c-slate-50); font: inherit; font-weight: 700; display: flex; align-items: center; justify-content: center; gap: 8px; }
.mpd__btn-acciones { min-height: 48px; padding: 0 14px; border-radius: 12px; border: 1px solid var(--c-ink-300); background: var(--c-slate-50); font: inherit; font-weight: 600; display: flex; align-items: center; gap: 6px; }

.mpd__card { margin: 12px 16px 0; padding: 14px; background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); border-radius: 14px; }
.mpd__card-title { font-size: .78rem; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; color: var(--c-ink-700); margin-bottom: 8px; }
.mpd__count { font-weight: 600; color: var(--c-ink-500); }
.mpd__viene { margin: 0; font-weight: 600; color: var(--c-ink-900); }
.mpd__fotos { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
.mpd__foto { aspect-ratio: 1; border-radius: 10px; overflow: hidden; background: var(--c-leaf-100); }
.mpd__foto img { width: 100%; height: 100%; object-fit: cover; display: block; }
.mpd__info-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.mpd__info-item { display: flex; flex-direction: column; gap: 2px; }
.mpd__info-label { font-size: .72rem; color: var(--c-ink-500); }
.mpd__info-val { font-size: .88rem; font-weight: 600; color: var(--c-ink-900); }
.mpd__mono { font-family: var(--font-mono, monospace); font-size: .78rem; word-break: break-all; }
.mpd__ultimo { display: flex; flex-direction: column; gap: 4px; font-size: .88rem; }
.mpd__ultimo-fecha { font-size: .76rem; color: var(--c-ink-500); }
.mpd__ultimo-item { color: var(--c-ink-900); }
.mpd__hist-info { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.mpd__ultimo-notas { color: var(--c-ink-700); }
.mpd__hist-empty { font-size: .86rem; color: var(--c-ink-500); }
.mpd__hist-list { display: flex; flex-direction: column; gap: 10px; }
.mpd__hist-item { display: grid; grid-template-columns: 10px minmax(0, 1fr); gap: 4px 10px; align-items: start; }
.mpd__hist-dot { width: 10px; height: 10px; border-radius: 50%; margin-top: 5px; }
.mpd__hist-tipo { font-size: .88rem; font-weight: 600; }
.mpd__hist-fecha { font-size: .74rem; color: var(--c-ink-500); }
.mpd__hist-desc { grid-column: 2; font-size: .84rem; color: var(--c-ink-700); }

.mpd__cosechar { margin: 16px 16px 0; width: calc(100% - 32px); min-height: 52px; border-radius: 14px; border: 2px solid var(--c-leaf-700); background: var(--c-slate-50); color: var(--c-leaf-800); font: inherit; font-weight: 700; }

.mpd__mas { display: flex; flex-direction: column; }
.mpd__mas-item { min-height: 52px; display: flex; align-items: center; gap: 12px; padding: 0 4px; border: 0; border-bottom: 1px solid var(--c-ink-100); background: none; font: inherit; color: var(--c-ink-900); text-decoration: none; text-align: left; }
.mpd__mas-item--peligro { color: var(--c-rust-600); }
.mpd__sheet { display: flex; flex-direction: column; gap: 10px; }
.mpd__label { font-size: .82rem; font-weight: 600; color: var(--c-ink-700); }
.mpd__opt { font-weight: 400; color: var(--c-ink-500); }
.mpd__input { min-height: 46px; padding: 0 12px; border: 1px solid var(--c-ink-300); border-radius: 12px; font: inherit; font-size: 1rem; }
.mpd__textarea { padding: 10px 12px; }
.mpd__hint { margin: 0; font-size: .84rem; color: var(--c-ink-700); line-height: 1.4; }
.mpd__btn { min-height: 50px; border-radius: 12px; border: 0; background: var(--c-leaf-700); color: var(--c-slate-50); font: inherit; font-weight: 700; }
.mpd__btn:disabled { opacity: .5; }
.mpd__btn--linea { background: var(--c-slate-50); color: var(--c-ink-900); border: 1px solid var(--c-ink-300); }
.mpd__btn--peligro { background: var(--c-rust-600); }
</style>
