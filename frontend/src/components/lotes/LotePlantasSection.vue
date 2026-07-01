<template>
  <div class="lps__section">
    <!-- Toggle header -->
    <button class="lps__toggle" @click="expanded = !expanded">
      <div class="lps__toggle-left">
        <span class="lps__emoji">🪴</span>
        <span class="lps__title">Plantas del lote</span>
        <span class="lps__pill">{{ plantasActivas.length }}</span>
        <span v-if="plantasCosechadas.length" class="lps__pill lps__pill--cosechada">{{ plantasCosechadas.length }} cosechadas</span>
      </div>
      <div class="lps__toggle-right" @click.stop>
        <button
          v-if="(canEdit || isCultivador) && lote.estado === 'floracion' && plantasActivas.length > 0"
          class="lps__btn-sm lps__btn-sm--cosecha"
          title="Registrar cosecha parcial"
          @click="$emit('cosechar')"
        >🌿 Cosechar</button>
        <!-- Toggle vista -->
        <div v-if="plantList.length > 0" class="lps__view-toggle">
          <button class="lps__view-btn" :class="{ 'lps__view-btn--active': viewMode === 'lista' }" title="Vista lista" @click="viewMode = 'lista'">
            <i class="bi bi-list-ul"></i>
          </button>
          <button class="lps__view-btn" :class="{ 'lps__view-btn--active': viewMode === 'layout' }" title="Vista layout" @click="viewMode = 'layout'">
            <i class="bi bi-grid-3x3-gap"></i>
          </button>
        </div>
        <template v-if="plantList.length > 0">
          <button
            class="lps__btn-sm lps__btn-sm--qr"
            :disabled="printingLabels || downloadingLabels"
            title="Imprimir etiquetas QR"
            @click="imprimirEtiquetas"
          >
            <i class="bi" :class="printingLabels ? 'bi-hourglass-split' : 'bi-printer'"></i>
            {{ printingLabels ? 'Generando…' : 'Imprimir' }}
          </button>
          <button
            class="lps__btn-sm lps__btn-sm--dl"
            :disabled="printingLabels || downloadingLabels"
            title="Descargar etiquetas QR como archivo HTML"
            @click="descargarEtiquetas"
          >
            <i class="bi" :class="downloadingLabels ? 'bi-hourglass-split' : 'bi-download'"></i>
            {{ downloadingLabels ? 'Generando…' : 'Descargar' }}
          </button>
        </template>
        <button v-if="canEdit || isCultivador" class="lps__btn-sm" @click="openAddPlanta">
          <i class="bi bi-plus-lg"></i>
        </button>
        <i class="bi lps__chevron" :class="expanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
      </div>
    </button>

    <!-- Body -->
    <div v-show="expanded" class="lps__body">
      <div v-if="plantsStore.loading" class="lps__placeholder">Cargando plantas…</div>
      <EmptyState v-else-if="!plantList.length" icon="🪴" title="Sin plantas" message="Sin plantas registradas en este lote." compact>
        <template #actions>
          <button v-if="canEdit || isCultivador" class="lps__btn-outline" @click="openAddPlanta">
            <i class="bi bi-plus-lg"></i> Agregar primera planta
          </button>
        </template>
      </EmptyState>

      <!-- Vista layout: plant cards -->
      <template v-else-if="viewMode === 'layout'">
        <div class="lps__plant-grid">
          <RouterLink
            v-for="(p, i) in plantList" :key="p.id"
            :to="{ name: 'planta-detalle', params: { id: p.id } }"
            class="lps__pcard"
            :class="{
              'lps__pcard--cosechada': p.state === 'cosechado',
              'lps__pcard--descartada': p.state === 'descartada',
            }"
          >
            <!-- Fondo: foto real o ilustración SVG por estadío -->
            <div
              class="lps__pcard-bg"
              :style="p.foto_url
                ? { backgroundImage: `url(${p.foto_url})` }
                : { background: PLANT_STAGE_GRADIENT[p.state] || PLANT_STAGE_GRADIENT.vegetativo }"
            ></div>
            <div class="lps__pcard-overlay"></div>

            <!-- Número de planta -->
            <div class="lps__pcard-num">#{{ i + 1 }}</div>

            <!-- Ilustración cuando no hay foto -->
            <div v-if="!p.foto_url" class="lps__pcard-illustration">
              <svg v-if="p.state === 'floracion'" viewBox="0 0 40 70" xmlns="http://www.w3.org/2000/svg" class="lps__psvg">
                <line x1="20" y1="68" x2="20" y2="22" stroke="#86efac" stroke-width="2.5" stroke-linecap="round"/>
                <ellipse cx="9"  cy="50" rx="11" ry="5" fill="#4ade80" opacity=".9" transform="rotate(-25 9 50)"/>
                <ellipse cx="31" cy="50" rx="11" ry="5" fill="#4ade80" opacity=".9" transform="rotate(25 31 50)"/>
                <ellipse cx="8"  cy="38" rx="10" ry="4" fill="#22c55e" opacity=".85" transform="rotate(-32 8 38)"/>
                <ellipse cx="32" cy="38" rx="10" ry="4" fill="#22c55e" opacity=".85" transform="rotate(32 32 38)"/>
                <ellipse cx="20" cy="18" rx="7" ry="11" fill="#a16207"/>
                <ellipse cx="11" cy="26" rx="5" ry="9" fill="#92400e" opacity=".9"/>
                <ellipse cx="29" cy="26" rx="5" ry="9" fill="#92400e" opacity=".9"/>
                <line x1="18" y1="10" x2="16" y2="6" stroke="#fbbf24" stroke-width="1.5"/>
                <line x1="22" y1="9"  x2="24" y2="5" stroke="#fbbf24" stroke-width="1.5"/>
              </svg>
              <svg v-else-if="['semilla','germinacion','esqueje'].includes(p.state)" viewBox="0 0 40 70" xmlns="http://www.w3.org/2000/svg" class="lps__psvg">
                <line x1="20" y1="68" x2="20" y2="42" stroke="#86efac" stroke-width="2.5" stroke-linecap="round"/>
                <ellipse cx="13" cy="48" rx="9" ry="5" fill="#4ade80" opacity=".9" transform="rotate(-30 13 48)"/>
                <ellipse cx="27" cy="48" rx="9" ry="5" fill="#4ade80" opacity=".9" transform="rotate(30 27 48)"/>
                <ellipse cx="20" cy="40" rx="7" ry="5" fill="#22c55e" opacity=".85"/>
              </svg>
              <svg v-else-if="['cosechado','curado','finalizado'].includes(p.state)" viewBox="0 0 40 70" xmlns="http://www.w3.org/2000/svg" class="lps__psvg">
                <line x1="20" y1="68" x2="20" y2="10" stroke="#9ca3af" stroke-width="2.5" stroke-linecap="round"/>
                <ellipse cx="10" cy="52" rx="10" ry="4" fill="#6b7280" opacity=".6" transform="rotate(20 10 52)"/>
                <ellipse cx="30" cy="52" rx="10" ry="4" fill="#6b7280" opacity=".6" transform="rotate(-20 30 52)"/>
                <ellipse cx="11" cy="38" rx="8"  ry="3" fill="#4b5563" opacity=".6" transform="rotate(25 11 38)"/>
                <ellipse cx="29" cy="38" rx="8"  ry="3" fill="#4b5563" opacity=".6" transform="rotate(-25 29 38)"/>
                <ellipse cx="20" cy="12" rx="5"  ry="8" fill="#374151" opacity=".7"/>
              </svg>
              <!-- Default: vegetativo -->
              <svg v-else viewBox="0 0 40 70" xmlns="http://www.w3.org/2000/svg" class="lps__psvg">
                <line x1="20" y1="68" x2="20" y2="16" stroke="#86efac" stroke-width="2.5" stroke-linecap="round"/>
                <ellipse cx="9"  cy="54" rx="11" ry="5" fill="#4ade80" opacity=".9" transform="rotate(-20 9 54)"/>
                <ellipse cx="31" cy="54" rx="11" ry="5" fill="#4ade80" opacity=".9" transform="rotate(20 31 54)"/>
                <ellipse cx="8"  cy="40" rx="10" ry="4" fill="#22c55e" opacity=".85" transform="rotate(-28 8 40)"/>
                <ellipse cx="32" cy="40" rx="10" ry="4" fill="#22c55e" opacity=".85" transform="rotate(28 32 40)"/>
                <ellipse cx="10" cy="27" rx="9"  ry="4" fill="#16a34a" opacity=".8" transform="rotate(-35 10 27)"/>
                <ellipse cx="30" cy="27" rx="9"  ry="4" fill="#16a34a" opacity=".8" transform="rotate(35 30 27)"/>
                <ellipse cx="20" cy="17" rx="8"  ry="6" fill="#15803d" opacity=".9"/>
              </svg>
            </div>

            <!-- Footer de la tarjeta -->
            <div class="lps__pcard-footer">
              <div class="lps__pcard-nombre">{{ p.nombre || `Planta #${i + 1}` }}</div>
              <div class="lps__pcard-estado" :style="{ background: estadoPlanta(p).color + '33', color: estadoPlanta(p).color === '#64748b' ? '#cbd5e1' : '#fff' }">
                {{ estadoPlanta(p).emoji }} {{ estadoPlanta(p).label }}
              </div>
            </div>

          </RouterLink>
        </div>

        <!-- Leyenda de estados presentes -->
        <div v-if="layoutLeyenda.length" class="lps__layout-legend">
          <div v-for="item in layoutLeyenda" :key="item.state" class="lps__legend-item">
            <span class="lps__legend-dot" :style="{ background: item.color }"></span>
            <span class="lps__legend-label">{{ item.emoji }} {{ item.label }}</span>
            <span class="lps__legend-cnt">{{ item.count }}</span>
          </div>
        </div>
      </template>

      <!-- Vista lista: fila por planta -->
      <template v-else>
        <div class="lps__list">
          <RouterLink
            v-for="(p, i) in plantasMostradas" :key="p.id"
            :to="{ name: 'planta-detalle', params: { id: p.id } }"
            class="lps__planta"
          >
            <div class="lps__planta-num">{{ (plantasPage - 1) * plantasPerPage + i + 1 }}</div>
            <div class="lps__planta-dot" :style="{ background: estadoPlanta(p).color }"></div>
            <div class="lps__planta-info">
              <div class="lps__planta-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
              <div class="lps__planta-qr">{{ p.codigo_qr || '—' }}</div>
            </div>
            <span class="lps__planta-estado" :style="{ background: estadoPlanta(p).color + '18', color: estadoPlanta(p).color }">
              {{ estadoPlanta(p).emoji }} {{ estadoPlanta(p).label }}
            </span>
            <i class="bi bi-chevron-right lps__planta-arrow"></i>
          </RouterLink>
        </div>

        <Paginator
          v-if="plantasActivas.length > plantasPerPage"
          v-model:page="plantasPage"
          v-model:perPage="plantasPerPage"
          :total="plantasActivas.length"
          :pageSizes="[10, 25, 50]"
        />

        <!-- Cosechadas: lista plana paginada (la pasada se muestra por fila) -->
        <template v-if="plantasCosechadas.length">
          <div class="lps__cosecha-grupo-header">
            <span class="lps__cosecha-grupo-label">🌿 Cosechadas</span>
            <span class="lps__cosecha-grupo-count">{{ plantasCosechadas.length }} planta{{ plantasCosechadas.length !== 1 ? 's' : '' }}</span>
          </div>
          <div class="lps__list">
            <RouterLink
              v-for="p in plantasCosechadasMostradas" :key="p.id"
              :to="{ name: 'planta-detalle', params: { id: p.id } }"
              class="lps__planta lps__planta--cosechada"
            >
              <div class="lps__planta-dot" :style="{ background: estadoPlanta(p).color }"></div>
              <div class="lps__planta-info">
                <div class="lps__planta-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
                <div class="lps__planta-qr">{{ p.codigo_qr || '—' }}<span v-if="p.pasada_cosecha"> · Cosecha {{ p.pasada_cosecha }}</span></div>
              </div>
              <span class="lps__planta-estado" :style="{ background: estadoPlanta(p).color + '18', color: estadoPlanta(p).color }">
                {{ estadoPlanta(p).emoji }} {{ estadoPlanta(p).label }}
              </span>
              <i class="bi bi-chevron-right lps__planta-arrow"></i>
            </RouterLink>
          </div>
          <Paginator
            v-if="plantasCosechadas.length > plantasPerPage"
            v-model:page="cosechadasPage"
            v-model:perPage="plantasPerPage"
            :total="plantasCosechadas.length"
            :pageSizes="[10, 25, 50]"
          />
        </template>
      </template>
    </div>

    <!-- Modal: Agregar planta -->
    <Teleport to="body">
      <div v-if="showAddPlanta" class="lps__overlay">
        <div class="lps__modal">
          <div class="lps__modal-header">
            <div>
              <h3 class="lps__modal-title">🪴 Agregar planta</h3>
              <p class="lps__modal-sub">{{ lote?.codigo }} · ID autogenerado</p>
            </div>
            <button class="lps__modal-close" @click="showAddPlanta = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="lps__modal-body">
            <div v-if="plantaError" class="lps__alert">{{ plantaError }}</div>
            <div v-if="lote?.genetica" class="lps__info-box">
              <span>🧬 Genética heredada del lote:</span>
              <strong>{{ lote.genetica.nombre }}</strong>
            </div>
            <div class="lps__grid">
              <div class="lps__field">
                <label class="lps__label">Estado inicial</label>
                <select class="lps__input" v-model="plantaForm.state">
                  <option value="germinacion">🌰 Semilla/Germinación</option>
                  <option value="esqueje">✂️ Esqueje</option>
                  <option value="vegetativo">🍃 Vegetativo</option>
                  <option value="floracion">🌸 Floración</option>
                </select>
              </div>
              <div class="lps__field">
                <label class="lps__label">Origen</label>
                <select class="lps__input" v-model="plantaForm.origen">
                  <option value="semilla">🌰 Semilla</option>
                  <option value="esqueje">✂️ Esqueje</option>
                  <option value="division">🪴 División</option>
                </select>
              </div>
            </div>
          </div>
          <div class="lps__modal-footer">
            <button class="lps__btn-ghost" :disabled="savingPlanta" @click="showAddPlanta = false">Cancelar</button>
            <button class="lps__btn-primary" :disabled="savingPlanta" @click="guardarPlanta">
              <DsSpinner v-if="savingPlanta" :size="14" />
              <i v-else class="bi bi-plus-lg"></i>Agregar planta
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { RouterLink } from 'vue-router'
import { usePlantsStore } from '../../stores/plants'
import { useClubStore }   from '../../stores/club'
import { createPlant } from '../../lib/api'
import { useQRCode } from '../../composables/useQRCode.js'
import { useToast } from '../../composables/useToast.js'
import { pm, em, STATE_MAP } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'
import Paginator  from '../ui/Paginator.vue'
import DsSpinner  from '../../design-system/components/Spinner.vue'

const props = defineProps({
  lote:        { type: Object,  required: true },
  loteId:      { type: Number,  required: true },
  canEdit:     { type: Boolean, default: false },
  isCultivador:{ type: Boolean, default: false },
})
const emit = defineEmits(['cosechar'])

const plantsStore  = usePlantsStore()
const clubStore    = useClubStore()
const toast        = useToast()
const { generatePNG } = useQRCode()

const PLANT_STAGE_GRADIENT = {
  semilla:    'linear-gradient(160deg, #166534 0%, #14532d 100%)',
  germinacion:'linear-gradient(160deg, #166534 0%, #064e3b 100%)',
  esqueje:    'linear-gradient(160deg, #0f766e 0%, #134e4a 100%)',
  vegetativo: 'linear-gradient(160deg, #15803d 0%, #166534 100%)',
  floracion:  'linear-gradient(160deg, #92400e 0%, #78350f 100%)',
  cosechado:  'linear-gradient(160deg, #1e3a8a 0%, #1e1b4b 100%)',
  descartada: 'linear-gradient(160deg, #374151 0%, #1f2937 100%)',
}

const expanded       = ref(true)
const viewMode       = ref('lista')
const plantasPage    = ref(1)
const cosechadasPage = ref(1)
const plantasPerPage = ref(10)

// Post-manicura el lote avanza (en_manicura/curado/finalizado) pero las plantas
// quedan congeladas en 'cosechado' (Plant no tiene esos estados). Para el display
// mostramos el estado del LOTE, que es lo que refleja la realidad.
function estadoPlanta(p) {
  if (p.state === 'cosechado' && ['en_manicura', 'curado', 'finalizado'].includes(props.lote?.estado)) {
    return em(props.lote.estado)
  }
  return pm(p.state)
}
const showAddPlanta  = ref(false)
const savingPlanta   = ref(false)
const plantaError    = ref(null)
const plantaForm     = ref({ state: 'vegetativo', origen: 'semilla' })

const plantList = computed(() => plantsStore.byLote(props.loteId))
const plantasActivas    = computed(() => plantList.value.filter(p => !['cosechado', 'descartada'].includes(p.state)))
const plantasCosechadas = computed(() => plantList.value.filter(p => p.state === 'cosechado'))
const plantasMostradas  = computed(() => {
  const start = (plantasPage.value - 1) * plantasPerPage.value
  return plantasActivas.value.slice(start, start + plantasPerPage.value)
})
const layoutCols = computed(() => {
  const n = plantList.value.length
  if (n <= 6)  return n
  if (n <= 12) return 4
  if (n <= 30) return 6
  if (n <= 60) return 8
  return 10
})

const layoutLeyenda = computed(() => {
  const counts = {}
  for (const p of plantList.value) {
    counts[p.state] = (counts[p.state] || 0) + 1
  }
  return Object.entries(counts).map(([state, count]) => {
    const meta = (state === 'cosechado' && ['en_manicura', 'curado', 'finalizado'].includes(props.lote?.estado))
      ? em(props.lote.estado) : pm(state)
    return { state, count, ...meta }
  })
})

// Cosechadas ordenadas por pasada y paginadas (la pasada se muestra por fila).
const plantasCosechadasOrdenadas = computed(() =>
  [...plantasCosechadas.value].sort((a, b) => (a.pasada_cosecha || '—').localeCompare(b.pasada_cosecha || '—'))
)
const plantasCosechadasMostradas = computed(() => {
  const start = (cosechadasPage.value - 1) * plantasPerPage.value
  return plantasCosechadasOrdenadas.value.slice(start, start + plantasPerPage.value)
})

function openAddPlanta() {
  plantaForm.value  = { state: STATE_MAP[props.lote?.estado] || 'vegetativo', origen: 'semilla' }
  plantaError.value = null
  showAddPlanta.value = true
}

async function guardarPlanta() {
  if (!props.lote) return
  savingPlanta.value = true
  plantaError.value  = null
  try {
    const count  = plantList.value.length + 1
    const nombre = `${props.lote.codigo}-P${String(count).padStart(3, '0')}`
    const { data } = await createPlant({
      lote_id:     props.lote.id,
      nombre,
      state:       plantaForm.value.state,
      origen:      plantaForm.value.origen,
      genetica_id: props.lote.genetica_id || undefined,
    })
    plantsStore.addToLote(props.loteId, data)
    showAddPlanta.value = false
  } catch (e) {
    plantaError.value = e?.response?.data?.errors?.join(', ') || 'Error al agregar planta'
  } finally {
    savingPlanta.value = false
  }
}

const printingLabels    = ref(false)
const downloadingLabels = ref(false)

function _esc(s) { return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])) }
function _fechaCorta(d) {
  if (!d) return null
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d))
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null
}

async function generarHTMLEtiquetas() {
  const origen   = window.location.origin
  const clubName = clubStore.data?.name || ''
  const loteCode = props.lote?.codigo || 'lote'
  const genetica = props.lote?.genetica?.nombre || props.lote?.strain || '—'
  const inicio   = _fechaCorta(props.lote?.start_date)

  const labels = await Promise.all(
    plantList.value
      .filter(p => p.codigo_qr)
      .map(async p => {
        const dataUrl = await generatePNG(`${origen}/p/${p.codigo_qr}`, {
          width: 180, margin: 1,
          color: { dark: '#1b5e20', light: '#ffffff' },
        })
        return { nombre: p.nombre || p.codigo_qr, dataUrl }
      })
  )

  return { html: `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Etiquetas QR — ${_esc(loteCode)}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  @page { size: A4; margin: 8mm; }
  body { font-family: -apple-system, sans-serif; background: #fff; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3mm; }
  .label {
    width: 100%; display: flex; align-items: center; gap: 2.5mm;
    border: 0.4px solid #bbb; border-radius: 2mm; padding: 2.5mm;
    page-break-inside: avoid; break-inside: avoid;
  }
  .label img { width: 22mm; height: 22mm; flex-shrink: 0; display: block; }
  .label-data { display: flex; flex-direction: column; gap: .6mm; min-width: 0; }
  .label-code { font-size: 10pt; font-weight: 700; font-family: monospace; color: #0f172a; line-height: 1.1; }
  .label-gen  { font-size: 8.5pt; font-weight: 600; color: #15803d; line-height: 1.15; }
  .label-meta { font-size: 7.5pt; color: #475569; line-height: 1.2; }
  .label-club { font-size: 6.5pt; color: #94a3b8; line-height: 1.2; }
</style>
</head>
<body>
<div class="grid">
${labels.map(l => `
  <div class="label">
    <img src="${l.dataUrl}" alt="${_esc(l.nombre)}" />
    <div class="label-data">
      <div class="label-code">${_esc(l.nombre)}</div>
      <div class="label-gen">🌿 ${_esc(genetica)}</div>
      <div class="label-meta">Lote ${_esc(loteCode)}${inicio ? ` · inicio ${inicio}` : ''}</div>
      <div class="label-club">${_esc(clubName)}</div>
    </div>
  </div>`).join('')}
</div>
</body>
</html>`, loteCode }
}

async function imprimirEtiquetas() {
  if (!plantList.value.length || printingLabels.value) return
  printingLabels.value = true
  try {
    const { html } = await generarHTMLEtiquetas()
    const win = window.open('', '_blank', 'width=800,height=900')
    if (!win) { toast.error('Permitir ventanas emergentes para imprimir'); return }
    win.document.write(html)
    win.document.close()
    setTimeout(() => { win.print() }, 600)
  } catch {
    toast.error('Error al generar etiquetas')
  } finally {
    printingLabels.value = false
  }
}

async function descargarEtiquetas() {
  if (!plantList.value.length || downloadingLabels.value) return
  downloadingLabels.value = true
  try {
    const { html, loteCode } = await generarHTMLEtiquetas()
    const blob = new Blob([html], { type: 'text/html;charset=utf-8' })
    const url  = URL.createObjectURL(blob)
    const a    = document.createElement('a')
    a.href     = url
    a.download = `etiquetas-${loteCode}.html`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  } catch {
    toast.error('Error al descargar etiquetas')
  } finally {
    downloadingLabels.value = false
  }
}

defineExpose({ closeAddPlanta: () => { showAddPlanta.value = false } })
</script>

<style scoped>
.lps__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; margin-top: 1rem; }
.lps__toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; gap: .5rem; padding: .8rem 1rem; background: none; border: none; cursor: pointer; text-align: left; transition: background .1s; }
.lps__toggle:hover { background: #f9fdfb; }
.lps__toggle-left  { display: flex; align-items: center; gap: .6rem; flex: 1; min-width: 0; }
.lps__toggle-right { display: flex; align-items: center; gap: .4rem; flex-shrink: 0; }
.lps__emoji  { font-size: 1rem; }
.lps__title  { font-size: .875rem; font-weight: 700; color: #1a1a1a; }
.lps__pill   { display: inline-flex; align-items: center; background: #e8f5e9; color: #1b5e20; font-size: .72rem; font-weight: 700; padding: .1em .55em; border-radius: 999px; }
.lps__pill--cosechada { background: #eff6ff; color: #1d4ed8; }
.lps__chevron { font-size: .75rem; color: #60725d; }
.lps__body  { border-top: 1px solid #e8f0e9; }
.lps__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }

/* Buttons */
.lps__btn-sm { display: inline-flex; align-items: center; gap: .3rem; background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .35rem .65rem; border-radius: 7px; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lps__btn-sm:hover { background: #1b5e20; color: #fff; }
.lps__btn-sm--cosecha { background: #dcfce7; border-color: #86efac; color: #15803d; }
.lps__btn-sm--cosecha:hover { background: #15803d; color: #fff; }
.lps__btn-sm--qr { background: #eff6ff; border-color: #bfdbfe; color: #1d4ed8; }
.lps__btn-sm--qr:hover:not(:disabled) { background: #1d4ed8; color: #fff; }
.lps__btn-sm--qr:disabled { opacity: .6; cursor: not-allowed; }
.lps__btn-sm--dl { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; }
.lps__btn-sm--dl:hover:not(:disabled) { background: #15803d; color: #fff; }
.lps__btn-sm--dl:disabled { opacity: .6; cursor: not-allowed; }
.lps__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .5rem 1.1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lps__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
.lps__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.lps__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.lps__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.lps__btn-ghost:hover { background: #f0fdf4; }

/* Plant list */
.lps__list { display: flex; flex-direction: column; }
.lps__planta { display: flex; align-items: center; gap: .65rem; padding: .65rem 1rem; border-bottom: 1px solid #f0fdf4; text-decoration: none; transition: background .1s; color: inherit; }
.lps__planta:last-child { border-bottom: none; }
.lps__planta:hover { background: #f9fdfb; }
.lps__planta--cosechada { opacity: .75; }
.lps__planta--cosechada:hover { opacity: 1; }
.lps__planta-num    { width: 22px; font-size: .72rem; color: #94a3b8; font-weight: 600; text-align: right; flex-shrink: 0; }
.lps__planta-dot    { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
.lps__planta-info   { flex: 1; min-width: 0; }
.lps__planta-nombre { font-size: .82rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.lps__planta-qr     { font-size: .68rem; color: #94a3b8; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.lps__planta-estado { font-size: .7rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; flex-shrink: 0; }
.lps__planta-sel    { background: none; border: none; cursor: pointer; padding: .25rem; border-radius: 5px; color: #d4e6d4; font-size: .85rem; flex-shrink: 0; transition: color .15s; }
.lps__planta-sel:hover { color: #d97706; }
.lps__planta-sel--on { color: #d97706; }
.lps__planta-arrow  { color: #d4e6d4; font-size: .75rem; flex-shrink: 0; }

/* View toggle */
.lps__view-toggle { display: flex; border: 1.5px solid #d4e6d4; border-radius: 7px; overflow: hidden; }
.lps__view-btn { background: #f8fafc; border: none; padding: .32rem .55rem; cursor: pointer; color: #94a3b8; font-size: .8rem; transition: all .15s; display: flex; align-items: center; }
.lps__view-btn:first-child { border-right: 1px solid #d4e6d4; }
.lps__view-btn:hover { background: #f0fdf4; color: #1b5e20; }
.lps__view-btn--active { background: #e8f5e9; color: #1b5e20; }

/* Plant card grid */
.lps__plant-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(110px, 1fr));
  gap: 10px; padding: 1rem;
}

/* Plant card */
.lps__pcard {
  position: relative; border-radius: 12px; overflow: hidden;
  aspect-ratio: 2/3; text-decoration: none;
  box-shadow: 0 4px 14px rgba(0,0,0,.18);
  transition: transform .15s, box-shadow .15s;
  display: flex; flex-direction: column;
}
.lps__pcard:hover { transform: translateY(-4px); box-shadow: 0 8px 24px rgba(0,0,0,.28); }
.lps__pcard--cosechada { opacity: .8; }
.lps__pcard--descartada { opacity: .45; filter: grayscale(.5); }

/* Background + overlay */
.lps__pcard-bg {
  position: absolute; inset: 0;
  background-size: cover; background-position: center top;
  transition: transform .3s;
}
.lps__pcard:hover .lps__pcard-bg { transform: scale(1.05); }
.lps__pcard-overlay {
  position: absolute; inset: 0;
  background: linear-gradient(to top, rgba(0,0,0,.85) 0%, rgba(0,0,0,.2) 55%, rgba(0,0,0,.05) 100%);
}

/* Number badge */
.lps__pcard-num {
  position: relative; z-index: 1;
  align-self: flex-start; margin: .45rem .45rem 0;
  background: rgba(255,255,255,.18); backdrop-filter: blur(4px);
  color: #fff; font-size: .6rem; font-weight: 800;
  padding: .18rem .42rem; border-radius: 5px; font-family: monospace;
}

/* SVG illustration */
.lps__pcard-illustration {
  position: relative; z-index: 1;
  flex: 1; display: flex; align-items: center; justify-content: center;
  padding: .25rem .5rem;
}
.lps__psvg { width: 65%; height: auto; filter: drop-shadow(0 2px 5px rgba(0,0,0,.35)); }

/* Star badge */
.lps__pcard-star {
  position: absolute; top: .4rem; right: .4rem; z-index: 2;
  font-size: .75rem; line-height: 1;
  filter: drop-shadow(0 1px 2px rgba(0,0,0,.5));
}

/* Footer */
.lps__pcard-footer {
  position: relative; z-index: 1;
  padding: .4rem .5rem .55rem;
  display: flex; flex-direction: column; gap: .18rem;
}
.lps__pcard-nombre {
  font-size: .62rem; font-weight: 700; color: #fff;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  text-shadow: 0 1px 3px rgba(0,0,0,.5);
}
.lps__pcard-estado {
  font-size: .55rem; font-weight: 700;
  padding: .15rem .38rem; border-radius: 5px;
  align-self: flex-start; white-space: nowrap;
}

/* Layout leyenda */
.lps__layout-legend { display: flex; flex-wrap: wrap; gap: .35rem; padding: 0 1rem 1rem; }
.lps__legend-item { display: flex; align-items: center; gap: .3rem; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: .25rem .55rem; font-size: .72rem; }
.lps__legend-dot  { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.lps__legend-label { font-weight: 600; color: #374151; }
.lps__legend-cnt  { color: #94a3b8; font-size: .68rem; margin-left: .1rem; }

/* Cosechadas por pasada */
.lps__cosecha-grupo { }
.lps__cosecha-grupo-header { display: flex; align-items: center; justify-content: space-between; padding: .4rem .85rem; background: #f0fdf4; border-top: 1px solid #e8f0e9; border-bottom: 1px solid #e8f0e9; }
.lps__cosecha-grupo-label { font-size: .75rem; font-weight: 700; color: #15803d; }
.lps__cosecha-grupo-count { font-size: .72rem; color: #60725d; }

/* Modal */
.lps__overlay  { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.lps__modal    { background: #fff; border-radius: 16px; width: 100%; max-width: 420px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.lps__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; }
.lps__modal-title  { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.lps__modal-sub    { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.lps__modal-close  { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; }
.lps__modal-body   { padding: 1.25rem 1.5rem; }
.lps__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; }
.lps__alert    { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
.lps__info-box { background: #f0fdf4; border: 1px solid #d4e6d4; border-radius: 9px; padding: .625rem .875rem; font-size: .82rem; color: #374151; display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }
.lps__grid  { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.lps__field { display: flex; flex-direction: column; gap: .35rem; }
.lps__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.lps__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; }
.lps__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
@media (max-width: 480px) { .lps__grid { grid-template-columns: 1fr; } }
</style>
