<template>
  <div class="phv">
    <header class="phv__hd">
      <h1 class="phv__title">Mis retiros</h1>
      <p class="phv__sub">Todo lo que retiraste, de lo más reciente a lo más viejo.</p>
    </header>

    <div v-if="cargando" class="phv__estado"><DsSpinner :size="36" /></div>

    <div v-else-if="error" class="phv__estado phv__estado--error">
      No pudimos traer tu historial. Probá de nuevo en un rato.
    </div>

    <div v-else-if="!dispensas.length" class="phv__estado">
      <div class="phv__vacio-ico">🌿</div>
      <p class="phv__vacio-txt">Todavía no retiraste nada. Cuando lo hagas, va a aparecer acá.</p>
    </div>

    <ul v-else class="phv__lista">
      <li v-for="d in dispensas" :key="d.id" class="phv__item">
        <div class="phv__fecha">
          <span class="phv__dia">{{ dia(d.fecha) }}</span>
          <span class="phv__mes">{{ mes(d.fecha) }}</span>
        </div>
        <div class="phv__cuerpo">
          <div class="phv__geneticas">
            <span v-for="(i, n) in d.items" :key="n" class="phv__genetica">
              {{ i.genetica || 'Producto' }}
              <span class="phv__cant">{{ i.cantidad }} {{ i.unidad || 'g' }}</span>
            </span>
          </div>
          <div class="phv__meta">
            <span>{{ d.gramos }} g en total</span>
            <span v-if="d.total > 0">· {{ pesos(d.total) }}</span>
          </div>
        </div>
        <a v-if="d.token" :href="`/d/${d.token}`" class="phv__ver" target="_blank" rel="noopener">
          Ver detalle
        </a>
      </li>
    </ul>
  </div>
</template>

<script setup>
// Lo primero que un paciente busca cuando entra: qué retiró y cuándo.
//
// El "ver detalle" abre el pasaporte que ya existe (`/d/:token`), con las fotos, la ficha de la
// genética y cómo se cultivó. No se rehace acá: es la misma página que le llega por QR, y tener
// dos versiones del mismo dato es lo que después se contradice.
import { ref, onMounted } from 'vue'
import { getPortalHistorial } from '@/lib/portalApi'
import DsSpinner from '@/design-system/components/Spinner.vue'

const dispensas = ref([])
const cargando  = ref(true)
const error     = ref(false)

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
const fecha = (f) => new Date(String(f) + 'T00:00:00')
const dia   = (f) => (f ? fecha(f).getDate() : '')
const mes   = (f) => (f ? MESES[fecha(f).getMonth()] : '')
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)

onMounted(async () => {
  try {
    dispensas.value = await getPortalHistorial()
  } catch {
    error.value = true
  } finally {
    cargando.value = false
  }
})
</script>

<style scoped>
.phv { max-width: 720px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }
.phv__hd { margin-bottom: 1.75rem; }
.phv__title { font-size: 1.5rem; font-weight: 800; color: var(--p-tinta); margin: 0 0 .25rem; }
.phv__sub { color: var(--p-suave); font-size: .9rem; margin: 0; }

.phv__estado {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .75rem; padding: 3rem 1rem; text-align: center; color: var(--p-suave);
}
.phv__estado--error { color: var(--p-atencion); }
.phv__vacio-ico { font-size: 2.5rem; }
.phv__vacio-txt { margin: 0; max-width: 320px; }

.phv__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .6rem; }
.phv__item {
  display: flex; align-items: center; gap: 1rem;
  border: 1px solid var(--p-linea); border-radius: 12px; padding: .85rem 1rem; background: #fff;
}
.phv__fecha {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  width: 46px; flex-shrink: 0; background: var(--p-marca-suave); border-radius: 9px; padding: .35rem 0;
}
.phv__dia { font-size: 1.1rem; font-weight: 800; color: var(--p-marca); line-height: 1; }
.phv__mes { font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: var(--p-suave); }

.phv__cuerpo { flex: 1; min-width: 0; }
.phv__geneticas { display: flex; flex-wrap: wrap; gap: .4rem .75rem; margin-bottom: .2rem; }
.phv__genetica { font-weight: 600; color: var(--p-tinta); font-size: .92rem; }
.phv__cant { font-weight: 400; color: var(--p-suave); }
.phv__meta { font-size: .8rem; color: var(--p-suave); display: flex; gap: .3rem; flex-wrap: wrap; }

.phv__ver { flex-shrink: 0; font-size: .85rem; font-weight: 600; color: var(--p-marca); text-decoration: none; }
.phv__ver:hover { text-decoration: underline; }

@media (max-width: 520px) {
  .phv__item { align-items: flex-start; }
  .phv__ver { align-self: center; }
}
</style>
