<script setup>
import { computed } from 'vue'
import { RouterLink } from 'vue-router'

const props = defineProps({
  sala:         { type: Object, required: true },
  lotesActivos: { type: Array,  default: () => [] },
})

const STAGE_GRADIENT = {
  germinacion:           'linear-gradient(160deg, #166534 0%, #14532d 100%)',
  esqueje:           'linear-gradient(160deg, #0f766e 0%, #134e4a 100%)',
  vegetativo:        'linear-gradient(160deg, #15803d 0%, #166534 100%)',
  floracion:         'linear-gradient(160deg, #b45309 0%, #92400e 100%)',
  cosecha:           'linear-gradient(160deg, #1d4ed8 0%, #1e3a8a 100%)',
  en_manicura:       'linear-gradient(160deg, #9333ea 0%, #6d28d9 100%)',
  curado:            'linear-gradient(160deg, #0369a1 0%, #075985 100%)',
  finalizado:        'linear-gradient(160deg, #374151 0%, #1f2937 100%)',
}

const STAGE_LABEL = {
  germinacion: 'Enraizado', esqueje: 'Enraizado', vegetativo: 'Vegetativo',
  floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'En manicura',
  curado: 'Curado', finalizado: 'Finalizado',
}

const STAGE_EMOJI = {
  germinacion: '🌱', esqueje: '✂️', vegetativo: '🍃', floracion: '🌸',
  cosecha: '✅', en_manicura: '✂️',
  curado: '🫙', finalizado: '📦',
}

const totalSlots = computed(() => Number(props.sala?.pots_count) || 0)

const cols = computed(() => {
  const n = totalSlots.value
  if (n <= 2) return n
  if (n <= 4) return 2
  if (n <= 6) return 3
  return 3
})

const lotesSorted = computed(() => [...props.lotesActivos].sort((a, b) => a.id - b.id))

const slots = computed(() =>
  Array.from({ length: totalSlots.value }, (_, i) => ({
    index: i + 1,
    lote: lotesSorted.value[i] || null,
  }))
)

const ocupados = computed(() => slots.value.filter(s => s.lote).length)
const libres   = computed(() => totalSlots.value - ocupados.value)

function stageGradient(estado) {
  return STAGE_GRADIENT[estado] || 'linear-gradient(160deg,#374151,#1f2937)'
}
</script>

<template>
  <div class="slg">
    <!-- Sin configurar -->
    <div v-if="!totalSlots" class="slg__empty">
      <div class="slg__empty-icon">🗺️</div>
      <p class="slg__empty-title">Layout no configurado</p>
      <p class="slg__empty-sub">Editá la sala y configurá la cantidad de slots para ver el layout visual.</p>
    </div>

    <template v-else>
      <!-- Cámara (si está configurada) -->
      <div v-if="sala.camera_snapshot_url || sala.camera_stream_url" class="slg__camera">
        <div class="slg__camera-header">
          <i class="bi bi-camera-video-fill"></i>
          <span>Cámara en vivo</span>
        </div>
        <div class="slg__camera-feed">
          <img
            v-if="sala.camera_snapshot_url"
            :src="sala.camera_snapshot_url"
            class="slg__camera-img"
            alt="Cámara sala"
          />
          <iframe
            v-else-if="sala.camera_stream_url"
            :src="sala.camera_stream_url"
            class="slg__camera-iframe"
            frameborder="0"
            allowfullscreen
          ></iframe>
        </div>
      </div>

      <!-- Barra de ocupación -->
      <div class="slg__occ">
        <div class="slg__occ-track">
          <div class="slg__occ-fill" :style="{ width: Math.min((ocupados / totalSlots) * 100, 100) + '%' }"></div>
        </div>
        <span class="slg__occ-label">{{ ocupados }}/{{ totalSlots }} slots · {{ libres }} libres</span>
      </div>

      <!-- Grid de lote cards -->
      <div class="slg__grid" :style="{ gridTemplateColumns: `repeat(${cols}, 1fr)` }">
        <!-- Slot con lote -->
        <component
          v-for="slot in slots"
          :key="slot.index"
          :is="slot.lote ? RouterLink : 'div'"
          :to="slot.lote ? { name: 'lote-detail', params: { id: slot.lote.id } } : undefined"
          class="slg__card"
          :class="{ 'slg__card--libre': !slot.lote, 'slg__card--link': !!slot.lote }"
        >
          <template v-if="slot.lote">
            <!-- Fondo: foto de portada del lote (marcada → última subida) o gradiente por estadío -->
            <div
              class="slg__card-bg"
              :style="slot.lote.foto_url
                ? { backgroundImage: `url(${slot.lote.foto_url})` }
                : { background: stageGradient(slot.lote.estado) }"
            ></div>
            <!-- Overlay oscuro para legibilidad -->
            <div class="slg__card-overlay"></div>

            <!-- Contenido -->
            <div class="slg__card-body">
              <!-- Badge código + estadío -->
              <div class="slg__card-top">
                <span class="slg__card-codigo">{{ slot.lote.codigo }}</span>
                <span class="slg__card-estado">
                  {{ STAGE_EMOJI[slot.lote.estado] }} {{ STAGE_LABEL[slot.lote.estado] || slot.lote.estado }}
                </span>
              </div>

              <!-- Ilustración SVG de planta (si no hay foto) -->
              <div v-if="!slot.lote.foto_url" class="slg__card-plant">
                <!-- Floración -->
                <svg v-if="slot.lote.estado === 'floracion'" viewBox="0 0 60 90" xmlns="http://www.w3.org/2000/svg" class="slg__plant-svg">
                  <line x1="30" y1="88" x2="30" y2="20" stroke="#86efac" stroke-width="3" stroke-linecap="round"/>
                  <ellipse cx="14" cy="65" rx="16" ry="7" fill="#4ade80" opacity=".9" transform="rotate(-25 14 65)"/>
                  <ellipse cx="46" cy="65" rx="16" ry="7" fill="#4ade80" opacity=".9" transform="rotate(25 46 65)"/>
                  <ellipse cx="12" cy="48" rx="14" ry="6" fill="#22c55e" opacity=".85" transform="rotate(-30 12 48)"/>
                  <ellipse cx="48" cy="48" rx="14" ry="6" fill="#22c55e" opacity=".85" transform="rotate(30 48 48)"/>
                  <ellipse cx="30" cy="18" rx="9" ry="14" fill="#a16207" opacity=".95"/>
                  <ellipse cx="17" cy="27" rx="7" ry="11" fill="#92400e" opacity=".9"/>
                  <ellipse cx="43" cy="27" rx="7" ry="11" fill="#92400e" opacity=".9"/>
                  <line x1="28" y1="9" x2="25" y2="4" stroke="#fbbf24" stroke-width="1.5"/>
                  <line x1="32" y1="8" x2="35" y2="3" stroke="#fbbf24" stroke-width="1.5"/>
                  <line x1="30" y1="6" x2="30" y2="2" stroke="#fbbf24" stroke-width="1.5"/>
                </svg>
                <!-- Vegetativo -->
                <svg v-else-if="['vegetativo','germinacion','esqueje'].includes(slot.lote.estado)" viewBox="0 0 60 90" xmlns="http://www.w3.org/2000/svg" class="slg__plant-svg">
                  <line x1="30" y1="88" x2="30" y2="18" stroke="#86efac" stroke-width="3" stroke-linecap="round"/>
                  <ellipse cx="14" cy="68" rx="16" ry="7" fill="#4ade80" opacity=".9" transform="rotate(-20 14 68)"/>
                  <ellipse cx="46" cy="68" rx="16" ry="7" fill="#4ade80" opacity=".9" transform="rotate(20 46 68)"/>
                  <ellipse cx="12" cy="52" rx="14" ry="6" fill="#22c55e" opacity=".85" transform="rotate(-28 12 52)"/>
                  <ellipse cx="48" cy="52" rx="14" ry="6" fill="#22c55e" opacity=".85" transform="rotate(28 48 52)"/>
                  <ellipse cx="15" cy="36" rx="12" ry="5" fill="#16a34a" opacity=".8" transform="rotate(-35 15 36)"/>
                  <ellipse cx="45" cy="36" rx="12" ry="5" fill="#16a34a" opacity=".8" transform="rotate(35 45 36)"/>
                  <ellipse cx="30" cy="20" rx="10" ry="8" fill="#15803d" opacity=".9"/>
                </svg>
                <!-- Cosecha / finalizado -->
                <svg v-else viewBox="0 0 60 90" xmlns="http://www.w3.org/2000/svg" class="slg__plant-svg">
                  <line x1="30" y1="88" x2="30" y2="10" stroke="#9ca3af" stroke-width="3" stroke-linecap="round"/>
                  <ellipse cx="15" cy="65" rx="14" ry="5" fill="#6b7280" opacity=".7" transform="rotate(20 15 65)"/>
                  <ellipse cx="45" cy="65" rx="14" ry="5" fill="#6b7280" opacity=".7" transform="rotate(-20 45 65)"/>
                  <ellipse cx="18" cy="48" rx="12" ry="4" fill="#4b5563" opacity=".7" transform="rotate(25 18 48)"/>
                  <ellipse cx="42" cy="48" rx="12" ry="4" fill="#4b5563" opacity=".7" transform="rotate(-25 42 48)"/>
                  <ellipse cx="30" cy="12" rx="7" ry="10" fill="#374151" opacity=".8"/>
                </svg>
              </div>

              <!-- Info inferior -->
              <div class="slg__card-bottom">
                <div class="slg__card-genetica">{{ slot.lote.genetica?.nombre || slot.lote.strain || '—' }}</div>
                <div class="slg__card-plantas">
                  <i class="bi bi-flower1"></i> {{ slot.lote.plants_count || 0 }} plantas
                </div>
              </div>
            </div>
          </template>

          <!-- Slot libre -->
          <template v-else>
            <div class="slg__card-libre-body">
              <div class="slg__card-libre-n">{{ slot.index }}</div>
              <div class="slg__card-libre-label">Disponible</div>
            </div>
          </template>
        </component>
      </div>

      <!-- Leyenda compacta -->
      <div v-if="lotesSorted.length" class="slg__legend">
        <div v-for="l in lotesSorted" :key="l.id" class="slg__legend-item">
          <div class="slg__legend-dot" :style="{ background: stageGradient(l.estado) }"></div>
          <span class="slg__legend-code">{{ l.codigo }}</span>
          <span class="slg__legend-gen">{{ l.genetica?.nombre || '—' }}</span>
          <span class="slg__legend-cnt">· {{ l.plants_count || 0 }} pl.</span>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.slg { display: flex; flex-direction: column; gap: 1rem; }

/* Empty state */
.slg__empty { text-align: center; padding: 3rem 1rem; }
.slg__empty-icon { font-size: 3rem; margin-bottom: .75rem; }
.slg__empty-title { font-size: 1rem; font-weight: 700; color: #374151; margin: 0 0 .35rem; }
.slg__empty-sub   { font-size: .82rem; color: #9ca3af; margin: 0; }

/* Camera */
.slg__camera { border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; }
.slg__camera-header {
  display: flex; align-items: center; gap: .5rem;
  padding: .55rem .875rem; background: #1a1f36; color: #fff;
  font-size: .78rem; font-weight: 600;
}
.slg__camera-feed { background: #000; }
.slg__camera-img  { width: 100%; display: block; max-height: 200px; object-fit: cover; }
.slg__camera-iframe { width: 100%; height: 200px; display: block; }

/* Ocupación */
.slg__occ { display: flex; align-items: center; gap: .75rem; }
.slg__occ-track { flex: 1; height: 6px; background: #e2e8f0; border-radius: 3px; overflow: hidden; }
.slg__occ-fill  { height: 100%; background: #16a34a; border-radius: 3px; transition: width .4s; }
.slg__occ-label { font-size: .73rem; color: #64748b; white-space: nowrap; font-weight: 500; }

/* Grid */
.slg__grid { display: grid; gap: 10px; }

/* Lote card */
.slg__card {
  position: relative; border-radius: 14px; overflow: hidden;
  aspect-ratio: 2/3; min-height: 180px;
  box-shadow: 0 4px 16px rgba(0,0,0,.18);
  transition: transform .15s, box-shadow .15s;
  cursor: default;
}
.slg__card--link { cursor: pointer; text-decoration: none; }
.slg__card:hover { transform: translateY(-3px); box-shadow: 0 8px 28px rgba(0,0,0,.25); }

/* Background: foto o gradiente */
.slg__card-bg {
  position: absolute; inset: 0;
  background-size: cover; background-position: center;
  transition: transform .3s;
}
.slg__card:hover .slg__card-bg { transform: scale(1.04); }

/* Overlay */
.slg__card-overlay {
  position: absolute; inset: 0;
  background: linear-gradient(to top, rgba(0,0,0,.82) 0%, rgba(0,0,0,.25) 55%, rgba(0,0,0,.1) 100%);
}

/* Body: sobre overlay */
.slg__card-body {
  position: relative; z-index: 1;
  height: 100%; display: flex; flex-direction: column;
  padding: .7rem;
}

/* Top: código + estado */
.slg__card-top { display: flex; align-items: flex-start; justify-content: space-between; gap: .3rem; }
.slg__card-codigo {
  background: rgba(255,255,255,.15); backdrop-filter: blur(4px);
  color: #fff; font-size: .68rem; font-weight: 800;
  padding: .2rem .5rem; border-radius: 6px;
  font-family: monospace; letter-spacing: .04em;
}
.slg__card-estado {
  background: rgba(0,0,0,.3); backdrop-filter: blur(4px);
  color: rgba(255,255,255,.9); font-size: .6rem; font-weight: 700;
  padding: .2rem .45rem; border-radius: 6px; text-align: right;
  max-width: 80px; line-height: 1.2;
}

/* Plant illustration */
.slg__card-plant {
  flex: 1; display: flex; align-items: center; justify-content: center;
  padding: .5rem 1rem;
}
.slg__plant-svg { width: 100%; max-width: 70px; height: auto; filter: drop-shadow(0 2px 6px rgba(0,0,0,.4)); }

/* Bottom: genetica + plantas */
.slg__card-bottom { margin-top: auto; }
.slg__card-genetica {
  font-size: .75rem; font-weight: 700; color: #fff;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  text-shadow: 0 1px 4px rgba(0,0,0,.6);
}
.slg__card-plantas {
  font-size: .65rem; color: rgba(255,255,255,.75);
  display: flex; align-items: center; gap: .25rem; margin-top: .15rem;
}

/* Slot libre */
.slg__card--libre {
  background: #f8fafc; border: 2px dashed #cbd5e1;
  box-shadow: none; cursor: default;
}
.slg__card--libre:hover { transform: none; box-shadow: none; }
.slg__card-libre-body {
  height: 100%; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: .3rem;
}
.slg__card-libre-n     { font-size: 1.1rem; font-weight: 800; color: #cbd5e1; }
.slg__card-libre-label { font-size: .68rem; font-weight: 600; color: #94a3b8; letter-spacing: .04em; text-transform: uppercase; }

/* Leyenda */
.slg__legend { display: flex; flex-wrap: wrap; gap: .35rem; }
.slg__legend-item {
  display: flex; align-items: center; gap: .3rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 7px;
  padding: .25rem .6rem; font-size: .72rem;
}
.slg__legend-dot { width: 10px; height: 10px; border-radius: 3px; flex-shrink: 0; }
.slg__legend-code { font-weight: 800; color: #1a1a1a; font-family: monospace; }
.slg__legend-gen  { color: #475569; }
.slg__legend-cnt  { color: #94a3b8; }
</style>
