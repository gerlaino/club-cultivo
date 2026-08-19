<template>
  <div v-if="avisos.length" class="pav" :class="`pav--${nivel}`">
    <div class="pav__inner">
      <span class="pav__punto" aria-hidden="true"></span>
      <p class="pav__txt">
        <span v-for="(a, i) in avisos" :key="a.tipo">
          <template v-if="i > 0"> · </template>{{ a.texto }}
        </span>
      </p>
      <a v-if="carnet" :href="`/c/${carnet}`" class="pav__bt" target="_blank" rel="noopener">
        Mi carnet
      </a>
    </div>
  </div>
</template>

<script setup>
// La franja de arriba: lo único que el paciente NO puede perderse por no scrollear.
//
// Sólo se dibuja si hay algo que decir. Una franja que dice algo siempre —"todo en orden"— se deja
// de leer a la semana, y el día que dice algo importante ya nadie la mira. Por eso el backend
// devuelve `avisos: []` cuando el REPROCANN está vigente y la cuenta al día, y acá no se renderiza
// nada.
//
// El aviso que justifica la franja entera es el vencimiento del REPROCANN: es el único dato que el
// portal le da al paciente y ninguna otra pantalla, y vencido no puede retirar.
import { ref, computed, onMounted } from 'vue'
import { getPortalMiEstado } from '@/lib/portalApi'

const avisos = ref([])
const carnet = ref(null)

// Si hay uno urgente, manda: la franja es una sola y tiene que tomar el color del peor.
const nivel = computed(() =>
  avisos.value.some(a => a.nivel === 'urgente') ? 'urgente' : 'atencion'
)

onMounted(async () => {
  try {
    const estado = await getPortalMiEstado()
    avisos.value = estado?.avisos || []
    carnet.value = estado?.carnet_token || null
  } catch { /* la franja es un extra: si falla, el portal se usa igual */ }
})
</script>

<style scoped>
.pav { border-bottom: 1px solid transparent; }
.pav--atencion { background: var(--p-atencion-bg); border-bottom-color: color-mix(in srgb, var(--p-atencion) 30%, transparent); }
.pav--urgente  { background: var(--p-urgente-bg);  border-bottom-color: color-mix(in srgb, var(--p-urgente) 30%, transparent); }

.pav__inner {
  max-width: var(--p-ancho);
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
}

.pav__punto { width: 7px; height: 7px; border-radius: var(--r-pill); flex: 0 0 auto; }
.pav--atencion .pav__punto { background: var(--p-atencion); }
.pav--urgente  .pav__punto { background: var(--p-urgente); }

.pav__txt { margin: 0; font-size: var(--fs-13); line-height: var(--lh-base); }
.pav--atencion .pav__txt { color: color-mix(in srgb, var(--p-atencion) 80%, #000 20%); }
.pav--urgente  .pav__txt { color: color-mix(in srgb, var(--p-urgente) 75%, #000 25%); }

.pav__bt {
  margin-left: auto;
  flex: 0 0 auto;
  font-size: var(--fs-12);
  font-weight: 600;
  text-decoration: none;
  color: var(--p-marca-fuerte);
  border: 1px solid currentColor;
  border-radius: var(--r-pill);
  padding: 2px var(--sp-3);
  white-space: nowrap;
}
.pav__bt:hover { background: rgb(255 255 255 / .55); }

@media (max-width: 520px) {
  .pav__inner { flex-wrap: wrap; }
  .pav__bt { margin-left: calc(7px + var(--sp-2)); }
}
</style>
