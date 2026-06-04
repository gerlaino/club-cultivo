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
        <button
          v-if="plantList.length > 0"
          class="lps__btn-sm lps__btn-sm--qr"
          :disabled="printingLabels"
          title="Imprimir etiquetas con QR para todas las plantas"
          @click="imprimirEtiquetas"
        >
          <i class="bi" :class="printingLabels ? 'bi-hourglass-split' : 'bi-printer'"></i>
          {{ printingLabels ? 'Generando…' : 'Etiquetas' }}
        </button>
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
      <div v-else class="lps__list">
        <RouterLink
          v-for="(p, i) in plantasMostradas" :key="p.id"
          :to="{ name: 'planta-detalle', params: { id: p.id } }"
          class="lps__planta"
        >
          <div class="lps__planta-num">{{ (plantasPage - 1) * plantasPerPage + i + 1 }}</div>
          <div class="lps__planta-dot" :style="{ background: pm(p.state).color }"></div>
          <div class="lps__planta-info">
            <div class="lps__planta-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
            <div class="lps__planta-qr">{{ p.codigo_qr || '—' }}</div>
          </div>
          <span class="lps__planta-estado" :style="{ background: pm(p.state).color + '18', color: pm(p.state).color }">
            {{ pm(p.state).emoji }} {{ pm(p.state).label }}
          </span>
          <button v-if="canEdit" class="lps__planta-sel" :class="{ 'lps__planta-sel--on': p.es_seleccion }"
                  :title="p.es_seleccion ? 'Quitar de selección' : 'Marcar como selección'"
                  @click.prevent.stop="toggleEsSeleccion(p)">
            <i class="bi" :class="p.es_seleccion ? 'bi-star-fill' : 'bi-star'"></i>
          </button>
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

      <!-- Cosechadas agrupadas por pasada -->
      <template v-if="plantasCosechadasPorPasada.length">
        <div v-for="grupo in plantasCosechadasPorPasada" :key="grupo.pasada" class="lps__cosecha-grupo">
          <div class="lps__cosecha-grupo-header">
            <span class="lps__cosecha-grupo-label">🌿 Cosecha {{ grupo.pasada }}</span>
            <span class="lps__cosecha-grupo-count">{{ grupo.plantas.length }} planta{{ grupo.plantas.length !== 1 ? 's' : '' }}</span>
          </div>
          <RouterLink
            v-for="p in grupo.plantas" :key="p.id"
            :to="{ name: 'planta-detalle', params: { id: p.id } }"
            class="lps__planta lps__planta--cosechada"
          >
            <div class="lps__planta-dot" :style="{ background: pm(p.state).color }"></div>
            <div class="lps__planta-info">
              <div class="lps__planta-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
              <div class="lps__planta-qr">{{ p.codigo_qr || '—' }}</div>
            </div>
            <span class="lps__planta-estado" :style="{ background: pm(p.state).color + '18', color: pm(p.state).color }">
              {{ pm(p.state).emoji }} {{ pm(p.state).label }}
            </span>
            <i class="bi bi-chevron-right lps__planta-arrow"></i>
          </RouterLink>
        </div>
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
import { createPlant, updatePlant } from '../../lib/api'
import { useQRCode } from '../../composables/useQRCode.js'
import { useToast } from '../../composables/useToast.js'
import { pm, STATE_MAP } from '../../lib/loteHelpers.js'
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

const expanded       = ref(true)
const plantasPage    = ref(1)
const plantasPerPage = ref(10)
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
const plantasCosechadasPorPasada = computed(() => {
  const grupos = {}
  for (const p of plantasCosechadas.value) {
    const pasada = p.pasada_cosecha || '—'
    if (!grupos[pasada]) grupos[pasada] = []
    grupos[pasada].push(p)
  }
  return Object.entries(grupos).sort(([a], [b]) => a.localeCompare(b)).map(([pasada, plantas]) => ({ pasada, plantas }))
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

async function toggleEsSeleccion(plant) {
  const original = plant.es_seleccion
  plant.es_seleccion = !original
  try { await updatePlant(plant.id, { es_seleccion: !original }) }
  catch { plant.es_seleccion = original; toast.error('Error al actualizar selección') }
}

const printingLabels = ref(false)

async function imprimirEtiquetas() {
  if (!plantList.value.length || printingLabels.value) return
  printingLabels.value = true
  try {
    const origen   = window.location.origin
    const clubName = clubStore.data?.name || ''
    const loteCode = props.lote?.codigo || 'lote'

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

    const html = `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Etiquetas QR — ${loteCode}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  @page { size: A4; margin: 8mm; }
  body { font-family: -apple-system, sans-serif; background: #fff; }
  .grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 3mm; }
  .label {
    width: 100%;
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    border: 0.4px solid #ccc; border-radius: 2mm; padding: 3mm 2mm;
    page-break-inside: avoid; break-inside: avoid; gap: 2mm;
  }
  .label img { width: 62%; height: auto; display: block; }
  .label-club { font-size: 9pt; color: #444; text-align: center; line-height: 1.2; }
  .label-code { font-size: 11pt; font-weight: 700; font-family: monospace; color: #000; text-align: center; line-height: 1.2; }
</style>
</head>
<body>
<div class="grid">
${labels.map(l => `
  <div class="label">
    <img src="${l.dataUrl}" alt="${l.nombre}" />
    <div class="label-club">${clubName}</div>
    <div class="label-code">${l.nombre}</div>
  </div>`).join('')}
</div>
</body>
</html>`

    const win = window.open('', '_blank', 'width=800,height=900')
    if (!win) { toast.error('Permitir ventanas emergentes para imprimir'); return }
    win.document.write(html)
    win.document.close()
    setTimeout(() => { win.print() }, 600)
  } catch (e) {
    toast.error('Error al generar etiquetas')
  } finally {
    printingLabels.value = false
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
