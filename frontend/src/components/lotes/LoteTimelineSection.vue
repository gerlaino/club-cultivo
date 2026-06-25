<template>
  <div class="lts__section">
    <button class="lts__toggle" @click="toggle">
      <div class="lts__toggle-left">
        <span class="lts__emoji">📦</span>
        <span class="lts__title">Timeline del ciclo</span>
        <span v-if="timeline?.pesadas?.length" class="lts__pill">{{ timeline.pesadas.length }} pesadas</span>
      </div>
      <i class="bi lts__chevron" :class="expanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
    </button>

    <div v-show="expanded" class="lts__body">
      <div v-if="$slots.actions" class="lts__actions"><slot name="actions" /></div>
      <div v-if="loading" class="lts__loading">Cargando timeline…</div>
      <EmptyState v-else-if="!timeline" icon="📦" title="Sin datos de ciclo" compact />
      <div v-else class="lts__list">

        <div v-if="timeline.pesadas?.length" class="lts__group">
          <div class="lts__group-title">🏋️ Pesadas</div>
          <div v-for="p in timeline.pesadas" :key="p.id" class="lts__row">
            <div class="lts__fase">
              <span class="lts__pill-fase" :style="{ background: em(p.fase_origen).bg, color: em(p.fase_origen).color }">{{ em(p.fase_origen).emoji }} {{ em(p.fase_origen).label }}</span>
              <i class="bi bi-arrow-right" style="color:#94a3b8;font-size:.7rem"></i>
              <span class="lts__pill-fase" :style="{ background: em(p.fase_destino).bg, color: em(p.fase_destino).color }">{{ em(p.fase_destino).emoji }} {{ em(p.fase_destino).label }}</span>
            </div>
            <div class="lts__pesos">
              <span v-if="p.peso_humedo_g">🌿 húmedo: <strong>{{ p.peso_humedo_g }}g</strong></span>
              <span v-if="p.peso_seco_g">
                💨 seco: <strong>{{ p.peso_seco_g }}g</strong>
                <span v-if="p.peso_humedo_g" class="lts__merma">({{ (100 - p.peso_seco_g / p.peso_humedo_g * 100).toFixed(1) }}% merma)</span>
              </span>
              <span v-if="p.peso_curado_g">
                🫙 curado: <strong>{{ p.peso_curado_g }}g</strong>
                <span v-if="p.peso_seco_g" class="lts__merma">({{ (100 - p.peso_curado_g / p.peso_seco_g * 100).toFixed(1) }}% merma)</span>
              </span>
            </div>
            <div class="lts__meta">{{ p.registrado_por }} · {{ formatDate(p.registrado_at) }}</div>
          </div>
        </div>

        <div v-if="timeline.stocks?.length" class="lts__group">
          <div class="lts__group-title">🛒 Stocks generados</div>
          <div v-for="s in timeline.stocks" :key="s.id" class="lts__row">
            <div class="lts__stock-info">
              <span class="lts__pill-fase" style="background:#f0fdf4;color:#1b5e20">{{ s.forma_producto || 'flor_seca' }}</span>
              <span><strong>{{ s.cantidad }}{{ s.unidad }}</strong></span>
              <span v-if="s.precio_sugerido_ars" class="lts__precio">$ {{ s.precio_sugerido_ars }}/{{ s.unidad }}</span>
              <span v-if="s.sede_nombre" class="lts__sede">📍 {{ s.sede_nombre }}</span>
            </div>
          </div>
        </div>

        <div v-if="timeline.dispensaciones?.length" class="lts__group">
          <div class="lts__group-title">🧑‍⚕️ Dispensaciones</div>
          <div v-for="d in timeline.dispensaciones" :key="d.id" class="lts__row">
            <span>{{ d.socio }}</span>
            <span><strong>{{ d.cantidad }}{{ d.unidad }}</strong></span>
            <span class="lts__meta">{{ formatDate(d.fecha) }}</span>
          </div>
        </div>

        <div v-if="timeline.transplantes?.length" class="lts__group">
          <div class="lts__group-title">🪴 Trasplantes</div>
          <div v-for="(t, i) in timeline.transplantes" :key="i" class="lts__row">
            <div class="lts__fase">
              <span v-if="t.maceta_origen" class="lts__pill-fase" style="background:#f1f5f9;color:#475569">{{ t.maceta_origen }}L</span>
              <i v-if="t.maceta_origen && t.maceta_destino" class="bi bi-arrow-right" style="color:#94a3b8;font-size:.7rem"></i>
              <span v-if="t.maceta_destino" class="lts__pill-fase" style="background:#f0fdf4;color:#1b5e20">{{ t.maceta_destino }}L</span>
            </div>
            <div class="lts__meta">
              {{ t.plantas }} planta{{ t.plantas !== 1 ? 's' : '' }}
              <template v-if="t.usuario"> · {{ t.usuario }}</template>
              · {{ formatDate(t.fecha) }}
            </div>
          </div>
        </div>

        <EmptyState
          v-if="!timeline.pesadas?.length && !timeline.stocks?.length && !timeline.transplantes?.length"
          icon="📦" title="Sin actividad de ciclo" compact
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { getLoteTimeline } from '../../lib/api.js'
import { em, formatDate } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'

const props = defineProps({
  loteId: { type: Number, required: true },
})

const expanded = ref(false)
const timeline = ref(null)
const loading  = ref(false)

async function load() {
  loading.value = true
  try { const { data } = await getLoteTimeline(props.loteId); timeline.value = data }
  catch { timeline.value = null }
  finally { loading.value = false }
}

function toggle() {
  expanded.value = !expanded.value
  if (expanded.value && !timeline.value) load()
}
</script>

<style scoped>
.lts__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; margin-top: 1.25rem; }
.lts__toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.lts__toggle:hover { background: #f0fdf4; }
.lts__toggle-left { display: flex; align-items: center; gap: .6rem; }
.lts__emoji { font-size: 1rem; }
.lts__title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.lts__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; }
.lts__chevron { color: #60725d; font-size: .75rem; }
.lts__body { border-top: 1px solid #e8f0e9; }
.lts__actions { display: flex; justify-content: flex-end; padding: .65rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lts__loading { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.lts__list { display: flex; flex-direction: column; gap: .5rem; padding: .75rem 1.1rem; }
.lts__group { border: 1px solid #e8f0e9; border-radius: 10px; overflow: hidden; }
.lts__group-title { font-size: .72rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .05em; padding: .5rem .85rem; background: #f4f8f4; border-bottom: 1px solid #e8f0e9; }
.lts__row { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; padding: .6rem .85rem; border-bottom: 1px solid #f0fdf4; font-size: .8rem; }
.lts__row:last-child { border-bottom: none; }
.lts__fase { display: flex; align-items: center; gap: .35rem; flex-wrap: wrap; }
.lts__pill-fase { font-size: .68rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; white-space: nowrap; }
.lts__pesos { display: flex; flex-wrap: wrap; gap: .75rem; color: #374151; font-size: .78rem; }
.lts__merma { color: #d97706; font-size: .7rem; margin-left: .2rem; }
.lts__meta { font-size: .7rem; color: #94a3b8; margin-left: auto; white-space: nowrap; }
.lts__stock-info { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; }
.lts__precio { color: #1b5e20; font-weight: 600; }
.lts__sede { font-size: .72rem; color: #64748b; }
</style>
