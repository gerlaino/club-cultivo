<template>
  <div class="ph">
    <PortalCabecera titulo="Del club" bajada="Lo que publica tu organización." />

    <!-- Lo que la organización cuenta de sí misma -->
    <header v-if="club?.descripcion" class="ph__intro">
      <p class="ph__intro-txt">{{ club.descripcion }}</p>
    </header>

    <div v-if="cargando" class="ph__cargando"><DsSpinner :size="32" /></div>

    <template v-else>
      <!-- ── La portada: la última novedad, tratada como si importara ── -->
      <article v-if="portada" class="ph__portada">
        <RouterLink :to="`/portal/noticias/${portada.id}`" class="ph__portada-link">
          <div v-if="portada.cover_url" class="ph__portada-foto" :style="`background-image:url(${portada.cover_url})`"></div>
          <div class="ph__portada-txt">
            <span class="ph__kicker">Novedades · {{ fechaLarga(portada.publicada_at) }}</span>
            <h1 class="ph__portada-t">{{ portada.titulo }}</h1>
            <p v-if="portada.preview" class="ph__portada-b">{{ portada.preview }}</p>
            <span class="ph__leer">Leer <ArrowRight :size="14" :stroke-width="1.75" /></span>
          </div>
        </RouterLink>
      </article>

      <!-- ── Lo que viene ── -->
      <section v-if="eventos.length" class="ph__sec">
        <div class="ph__sec-hd">
          <h2 class="ph__sec-t">Lo que viene</h2>
          <RouterLink to="/portal/eventos" class="ph__mas">Ver todos</RouterLink>
        </div>
        <ul class="ph__agenda">
          <li v-for="e in eventos.slice(0, 3)" :key="e.id">
            <RouterLink :to="`/portal/eventos/${e.id}`" class="ph__ev">
              <span class="ph__ev-f">{{ diaSemana(e.fecha_inicio) }} {{ dia(e.fecha_inicio) }}</span>
              <span class="ph__ev-c">
                <span class="ph__ev-t">{{ e.titulo }}</span>
                <span class="ph__ev-m">{{ hora(e.fecha_inicio) }}<template v-if="e.lugar"> · {{ e.lugar }}</template></span>
              </span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- ── Más novedades (la portada ya se mostró) ── -->
      <section v-if="masNoticias.length" class="ph__sec">
        <div class="ph__sec-hd">
          <h2 class="ph__sec-t">Más novedades</h2>
          <RouterLink to="/portal/noticias" class="ph__mas">Ver todas</RouterLink>
        </div>
        <ul class="ph__notas">
          <li v-for="n in masNoticias" :key="n.id">
            <RouterLink :to="`/portal/noticias/${n.id}`" class="ph__nota">
              <span class="ph__nota-f">{{ fechaCorta(n.publicada_at) }}</span>
              <span class="ph__nota-t">{{ n.titulo }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- ── El catálogo ── -->
      <section v-if="geneticas.length" class="ph__sec">
        <div class="ph__sec-hd">
          <h2 class="ph__sec-t">En el catálogo</h2>
          <RouterLink to="/portal/geneticas" class="ph__mas">Ver todo</RouterLink>
        </div>
        <ul class="ph__vars">
          <li v-for="g in geneticas.slice(0, 4)" :key="g.id">
            <RouterLink :to="`/portal/geneticas/${g.id}`" class="ph__var">
              <span class="ph__var-f">
                <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre" loading="lazy" />
                <LeafHerbarium v-else :size="26" class="ph__var-sinfoto" />
                <span v-if="g.registrada_inase" class="ph__var-inase">INASE</span>
              </span>
              <span class="ph__var-n">{{ g.nombre }}</span>
              <span class="ph__var-d">
                <template v-if="g.tipo">{{ TIPOS[g.tipo] || g.tipo }}</template>
                <template v-if="g.thc != null"> · THC {{ g.thc }}%</template>
              </span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- ── Cuando la organización todavía no publicó nada ──
           No es un hueco: se ofrece lo que SÍ existe siempre. -->
      <section v-if="sinPublicar" class="ph__nada">
        <LeafHerbarium :size="40" class="ph__nada-ico" />
        <h2 class="ph__nada-t">Todavía no hay nada publicado</h2>
        <p class="ph__nada-b">
          Cuando {{ club?.name || 'tu organización' }} cargue novedades, eventos o variedades, los
          vas a ver acá. Mientras tanto:
        </p>
        <div class="ph__nada-acts">
          <RouterLink to="/portal" class="ph__nada-bt">Ver mi estado</RouterLink>
          <RouterLink to="/portal/historial" class="ph__nada-bt ph__nada-bt--sec">Mis retiros</RouterLink>
        </div>
      </section>
    </template>

  </div>
</template>

<script setup>
// Lo que PUBLICA la organización, tratado como si valiera algo: la última novedad va como portada,
// con su foto y su titular. Una organización que se toma el trabajo de escribir algo tiene que
// verlo tratado así — es lo que hace que lo siga escribiendo. Después, en orden: lo que VIENE (es
// lo único que caduca), el resto de las novedades, y el catálogo.
//
// Esto ERA el inicio del portal. Dejó de serlo: el inicio es el estado del paciente, porque el
// boletín está vacío en cualquier organización que no publique —que son casi todas, casi todas las
// semanas— y su REPROCANN, su turno y su indicación no están vacíos nunca. Acá no se perdió nada:
// la pantalla es la misma, con su propia entrada en la barra, y el inicio la resume arriba.
import { ref, computed, onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { ArrowRight } from 'lucide-vue-next'
import { getPortalEventos, getPortalNoticias, getPortalGeneticas } from '@/lib/portalApi'
import { usePortalClubStore } from '@/stores/portalClub'
import LeafHerbarium from '@/design-system/icons/LeafHerbarium.vue'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const { club } = storeToRefs(usePortalClubStore())

const eventos   = ref([])
const noticias  = ref([])
const geneticas = ref([])
const cargando  = ref(true)

const portada     = computed(() => noticias.value[0] || null)
const masNoticias = computed(() => noticias.value.slice(1, 4))
const sinPublicar = computed(() => !eventos.value.length && !noticias.value.length && !geneticas.value.length)

const TIPOS = { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida', ruderalis: 'Ruderalis' }
const DIAS  = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb']

const d = (f) => new Date(f)
const dia        = (f) => (f ? d(f).getDate() : '')
const diaSemana  = (f) => (f ? DIAS[d(f).getDay()].toUpperCase() : '')
const hora       = (f) => (f ? d(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')
const fechaLarga = (f) => (f ? d(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long' }) : '')
const fechaCorta = (f) => (f ? d(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : '')

onMounted(async () => {
  // Las tres en paralelo, y ninguna hace caer a las otras: si la organización no cargó eventos,
  // las novedades salen igual.
  const [ev, no, ge] = await Promise.allSettled([
    getPortalEventos(), getPortalNoticias(), getPortalGeneticas(),
  ])
  if (ev.status === 'fulfilled') eventos.value   = ev.value || []
  if (no.status === 'fulfilled') noticias.value  = no.value || []
  if (ge.status === 'fulfilled') geneticas.value = ge.value || []
  cargando.value = false
})
</script>

<style scoped>
/* Mobile-first: se diseña a 360 y se ensancha. El resto de la app es al revés porque se usa
   sentado en el club; esto se usa parado, yendo a retirar. */
.ph { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }

.ph__intro { margin-bottom: var(--sp-6); }
.ph__intro-txt {
  font-family: var(--p-display);
  font-size: var(--fs-18); line-height: var(--lh-base); color: var(--p-suave); margin: 0;
}

.ph__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

/* ── Portada ── */
.ph__portada { margin-bottom: var(--sp-10); }
.ph__portada-link { display: block; text-decoration: none; color: inherit; }
.ph__portada-foto {
  aspect-ratio: 16 / 9;
  background: var(--p-marca-suave) center/cover no-repeat;
  border-radius: var(--p-radio);
  margin-bottom: var(--sp-4);
}
.ph__portada-txt { min-width: 0; }
.ph__kicker {
  display: block;
  font-size: var(--fs-12); letter-spacing: .12em; text-transform: uppercase;
  color: var(--p-tenue); margin-bottom: var(--sp-2);
}
.ph__portada-t {
  font-family: var(--p-display);
  font-size: var(--fs-24); line-height: var(--lh-tight); font-weight: 600;
  letter-spacing: -.02em; margin: 0 0 var(--sp-2); text-wrap: balance;
}
.ph__portada-b { color: var(--p-suave); margin: 0 0 var(--sp-3); line-height: var(--lh-base); }
.ph__leer {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-14); font-weight: 600; color: var(--p-marca);
}
.ph__portada-link:hover .ph__portada-t { text-decoration: underline; text-underline-offset: 3px; }

/* ── Secciones ── */
.ph__sec { margin-bottom: var(--sp-10); }
.ph__sec-hd {
  display: flex; align-items: baseline; justify-content: space-between; gap: var(--sp-4);
  border-bottom: 1px solid var(--p-linea); padding-bottom: var(--sp-2); margin-bottom: var(--sp-3);
}
.ph__sec-t {
  font-family: var(--p-display);
  font-size: var(--fs-18); font-weight: 600; margin: 0; letter-spacing: -.01em;
}
.ph__mas { font-size: var(--fs-13); font-weight: 600; color: var(--p-marca); text-decoration: none; white-space: nowrap; }
.ph__mas:hover { text-decoration: underline; }

ul { list-style: none; margin: 0; padding: 0; }

/* Agenda */
.ph__ev {
  display: flex; gap: var(--sp-4); align-items: baseline;
  padding: var(--sp-3) 0; text-decoration: none; color: inherit;
  border-bottom: 1px dotted var(--p-linea);
}
.ph__agenda li:last-child .ph__ev { border-bottom: 0; }
.ph__ev-f {
  font-family: var(--font-mono); font-size: var(--fs-12); font-weight: 600;
  color: var(--p-marca); width: 66px; flex: 0 0 auto; letter-spacing: .02em;
}
.ph__ev-c { display: flex; flex-direction: column; min-width: 0; }
.ph__ev-t { font-weight: 600; }
.ph__ev-m { font-size: var(--fs-13); color: var(--p-tenue); }
.ph__ev:hover .ph__ev-t { text-decoration: underline; text-underline-offset: 3px; }

/* Notas */
.ph__nota {
  display: flex; gap: var(--sp-4); align-items: baseline;
  padding: var(--sp-3) 0; text-decoration: none; color: inherit;
  border-bottom: 1px dotted var(--p-linea);
}
.ph__notas li:last-child .ph__nota { border-bottom: 0; }
.ph__nota-f {
  font-family: var(--font-mono); font-size: var(--fs-12); color: var(--p-tenue);
  width: 66px; flex: 0 0 auto;
}
.ph__nota-t { font-weight: 500; }
.ph__nota:hover .ph__nota-t { text-decoration: underline; text-underline-offset: 3px; }

/* Catálogo */
.ph__vars { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
.ph__var { display: block; text-decoration: none; color: inherit; }
.ph__var-f {
  position: relative; display: flex; align-items: center; justify-content: center;
  aspect-ratio: 4 / 3; background: var(--p-marca-suave);
  border-radius: var(--p-radio-sm); overflow: hidden; margin-bottom: var(--sp-2);
}
.ph__var-f img { width: 100%; height: 100%; object-fit: cover; }
.ph__var-sinfoto { color: var(--p-marca-linea); }
.ph__var-inase {
  position: absolute; top: var(--sp-2); left: var(--sp-2);
  background: var(--p-marca-fuerte); color: #fff;
  font-size: 10px; font-weight: 700; letter-spacing: .06em;
  padding: 2px var(--sp-2); border-radius: var(--r-pill);
}
.ph__var-n { display: block; font-weight: 600; font-size: var(--fs-14); }
.ph__var-d { display: block; font-size: var(--fs-12); color: var(--p-tenue); }
.ph__var:hover .ph__var-n { text-decoration: underline; text-underline-offset: 3px; }

/* Nada publicado */
.ph__nada { text-align: center; padding: var(--sp-12) var(--sp-4); }
.ph__nada-ico { color: var(--p-marca-linea); margin-bottom: var(--sp-3); }
.ph__nada-t { font-family: var(--p-display); font-size: var(--fs-20); font-weight: 600; margin: 0 0 var(--sp-2); }
.ph__nada-b { color: var(--p-suave); margin: 0 auto var(--sp-5); max-width: 40ch; }
.ph__nada-acts { display: flex; flex-wrap: wrap; gap: var(--sp-2); justify-content: center; }
.ph__nada-bt {
  text-decoration: none; font-size: var(--fs-14); font-weight: 600;
  background: var(--p-marca); color: #fff;
  padding: var(--sp-2) var(--sp-5); border-radius: var(--r-pill);
}
.ph__nada-bt--sec { background: none; color: var(--p-marca); border: 1px solid var(--p-marca-linea); }

@media (min-width: 640px) {
  .ph { padding: var(--sp-10) var(--sp-4) var(--sp-12); }
  .ph__portada-t { font-size: var(--fs-32); }
  .ph__vars { grid-template-columns: repeat(4, 1fr); }
}
</style>
