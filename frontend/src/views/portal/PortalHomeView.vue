<template>
  <div class="ph">

    <!-- Lo que la organización cuenta de sí misma -->
    <header class="ph__hero">
      <h1 class="ph__hola">{{ club?.name || 'Tu organización' }}</h1>
      <p v-if="club?.descripcion" class="ph__desc">{{ club.descripcion }}</p>
    </header>

    <!-- Próximos eventos: va primero porque es lo único que caduca -->
    <section v-if="cargando || eventos.length" class="ph__sec">
      <div class="ph__sec-hd">
        <h2 class="ph__sec-t">Próximos eventos</h2>
        <RouterLink to="/portal/eventos" class="ph__mas">Ver todos →</RouterLink>
      </div>

      <div v-if="cargando" class="ph__cargando"><DsSpinner :size="28" /></div>
      <ul v-else class="ph__eventos">
        <li v-for="e in eventos.slice(0, 3)" :key="e.id" class="ph__evento">
          <RouterLink :to="`/portal/eventos/${e.id}`" class="ph__evento-link">
            <div class="ph__fecha">
              <span class="ph__dia">{{ dia(e.fecha_inicio) }}</span>
              <span class="ph__mes">{{ mes(e.fecha_inicio) }}</span>
            </div>
            <div class="ph__evento-txt">
              <span class="ph__evento-t">{{ e.titulo }}</span>
              <span class="ph__evento-meta">
                {{ hora(e.fecha_inicio) }}<template v-if="e.lugar"> · {{ e.lugar }}</template>
              </span>
            </div>
          </RouterLink>
        </li>
      </ul>
    </section>

    <!-- Novedades -->
    <section v-if="cargando || noticias.length" class="ph__sec">
      <div class="ph__sec-hd">
        <h2 class="ph__sec-t">Novedades</h2>
        <RouterLink to="/portal/noticias" class="ph__mas">Ver todas →</RouterLink>
      </div>

      <div v-if="cargando" class="ph__cargando"><DsSpinner :size="28" /></div>
      <ul v-else class="ph__noticias">
        <li v-for="n in noticias.slice(0, 3)" :key="n.id">
          <RouterLink :to="`/portal/noticias/${n.id}`" class="ph__noticia">
            <div v-if="n.cover_url" class="ph__noticia-img" :style="`background-image:url(${n.cover_url})`"></div>
            <div class="ph__noticia-txt">
              <span class="ph__noticia-fecha">{{ fechaLarga(n.publicada_at) }}</span>
              <span class="ph__noticia-t">{{ n.titulo }}</span>
              <span v-if="n.preview" class="ph__noticia-prev">{{ n.preview }}</span>
            </div>
          </RouterLink>
        </li>
      </ul>
    </section>

    <!-- Variedades -->
    <section v-if="cargando || geneticas.length" class="ph__sec">
      <div class="ph__sec-hd">
        <h2 class="ph__sec-t">Variedades disponibles</h2>
        <RouterLink to="/portal/geneticas" class="ph__mas">Ver todas →</RouterLink>
      </div>

      <div v-if="cargando" class="ph__cargando"><DsSpinner :size="28" /></div>
      <ul v-else class="ph__geneticas">
        <li v-for="g in geneticas.slice(0, 3)" :key="g.id">
          <RouterLink :to="`/portal/geneticas/${g.id}`" class="ph__genetica">
            <div class="ph__gen-img">
              <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre" loading="lazy" />
              <span v-else class="ph__gen-sinfoto">🌿</span>
              <span v-if="g.registrada_inase" class="ph__gen-inase">INASE</span>
            </div>
            <span class="ph__gen-nombre">{{ g.nombre }}</span>
            <span class="ph__gen-stats">
              <span v-if="g.tipo">{{ TIPOS[g.tipo] || g.tipo }}</span>
              <span v-if="g.thc != null">· THC {{ g.thc }}%</span>
              <span v-if="g.cbd != null">· CBD {{ g.cbd }}%</span>
            </span>
          </RouterLink>
        </li>
      </ul>
    </section>

    <!-- Cuando la organización todavía no cargó nada -->
    <div v-if="!cargando && vacio" class="ph__vacio">
      <div class="ph__vacio-ico">🌱</div>
      <p class="ph__vacio-txt">
        Tu organización todavía no publicó novedades, eventos ni variedades.
        Mientras tanto podés ver <RouterLink to="/portal/historial">tus retiros</RouterLink>.
      </p>
    </div>

  </div>
</template>

<script setup>
// El inicio del portal es LO QUE LA ORGANIZACIÓN PUBLICA: eventos, novedades y su catálogo, que
// es justo lo que su admin configura en Configuración → Portal del paciente. Lo del paciente
// —sus retiros, su cuenta corriente— vive en la barra, porque no cambia solo: entra a mirar qué
// hay de nuevo, no a revisar lo que ya hizo.
//
// Los eventos van primero de todo: son lo único que caduca. Una novedad de la semana pasada se
// lee igual el martes; una fiesta del sábado no.
import { ref, computed, onMounted } from 'vue'
import {
  getPortalEventos, getPortalNoticias, getPortalGeneticas,
} from '@/lib/portalApi'
import { usePortalClubStore } from '@/stores/portalClub'
import { storeToRefs } from 'pinia'
import DsSpinner from '@/design-system/components/Spinner.vue'

const { club } = storeToRefs(usePortalClubStore())

const eventos   = ref([])
const noticias  = ref([])
const geneticas = ref([])
const cargando  = ref(true)

const vacio = computed(() => !eventos.value.length && !noticias.value.length && !geneticas.value.length)

const TIPOS = { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida', ruderalis: 'Ruderalis' }
const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

const dia  = (f) => (f ? new Date(f).getDate() : '')
const mes  = (f) => (f ? MESES[new Date(f).getMonth()] : '')
const hora = (f) => (f ? new Date(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')
const fechaLarga = (f) =>
  f ? new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }) : ''

onMounted(async () => {
  // Las tres en paralelo y ninguna hace caer a las otras: si la organización no cargó eventos,
  // las novedades tienen que salir igual.
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
.ph { max-width: 780px; margin: 0 auto; padding: 2.25rem 1.25rem 3.5rem; }

.ph__hero { margin-bottom: 2.5rem; }
.ph__hola { font-size: 1.7rem; font-weight: 800; color: #1a2e1a; margin: 0 0 .4rem; letter-spacing: -.015em; }
.ph__desc { color: #6b8f71; margin: 0; line-height: 1.6; max-width: 60ch; }

.ph__sec { margin-bottom: 2.5rem; }
.ph__sec-hd { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; margin-bottom: .9rem; }
.ph__sec-t { font-size: 1.05rem; font-weight: 700; color: #1a2e1a; margin: 0; }
.ph__mas { font-size: .82rem; font-weight: 600; color: #1b5e20; text-decoration: none; white-space: nowrap; }
.ph__mas:hover { text-decoration: underline; }
.ph__cargando { display: flex; justify-content: center; padding: 1.5rem; }

/* Eventos */
.ph__eventos { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .55rem; }
.ph__evento { min-width: 0; }
.ph__evento-link {
  display: flex; align-items: center; gap: 1rem; text-decoration: none;
  border: 1px solid #e4ece6; border-radius: 12px; padding: .8rem 1rem; background: #fff;
}
.ph__evento-link:hover { border-color: #6dbe8a; }
.ph__fecha {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  width: 46px; flex-shrink: 0; background: #f0f6f1; border-radius: 9px; padding: .35rem 0;
}
.ph__dia { font-size: 1.1rem; font-weight: 800; color: #1b5e20; line-height: 1; }
.ph__mes { font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: #6b8f71; }
.ph__evento-txt { display: flex; flex-direction: column; min-width: 0; }
.ph__evento-t { font-weight: 600; color: #1a2e1a; }
.ph__evento-meta { font-size: .8rem; color: #6b8f71; }

/* Novedades */
.ph__noticias { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .55rem; }
.ph__noticia {
  display: flex; gap: 1rem; text-decoration: none; align-items: stretch;
  border: 1px solid #e4ece6; border-radius: 12px; overflow: hidden; background: #fff;
}
.ph__noticia:hover { border-color: #6dbe8a; }
.ph__noticia-img { width: 110px; flex-shrink: 0; background-size: cover; background-position: center; }
.ph__noticia-txt { display: flex; flex-direction: column; gap: .15rem; padding: .85rem 1rem; min-width: 0; }
.ph__noticia-fecha { font-size: .74rem; color: #6b8f71; text-transform: uppercase; letter-spacing: .03em; }
.ph__noticia-t { font-weight: 600; color: #1a2e1a; }
.ph__noticia-prev {
  font-size: .85rem; color: #6b8f71; line-height: 1.5;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
}

/* Variedades */
.ph__geneticas {
  list-style: none; margin: 0; padding: 0;
  display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: .75rem;
}
.ph__genetica {
  display: flex; flex-direction: column; gap: .3rem; text-decoration: none;
  border: 1px solid #e4ece6; border-radius: 12px; overflow: hidden; background: #fff; padding-bottom: .8rem;
}
.ph__genetica:hover { border-color: #6dbe8a; }
.ph__gen-img {
  position: relative; aspect-ratio: 4 / 3; background: #f0f6f1;
  display: flex; align-items: center; justify-content: center;
}
.ph__gen-img img { width: 100%; height: 100%; object-fit: cover; }
.ph__gen-sinfoto { font-size: 1.75rem; opacity: .45; }
.ph__gen-inase {
  position: absolute; top: .45rem; left: .45rem; background: rgba(27,94,32,.9); color: #fff;
  font-size: .62rem; font-weight: 700; letter-spacing: .05em; padding: .12rem .4rem; border-radius: 20px;
}
.ph__gen-nombre { font-weight: 600; color: #1a2e1a; padding: .55rem .8rem 0; }
.ph__gen-stats { font-size: .78rem; color: #6b8f71; padding: 0 .8rem; display: flex; gap: .25rem; flex-wrap: wrap; }

/* Nada publicado */
.ph__vacio { text-align: center; padding: 3rem 1rem; color: #6b8f71; }
.ph__vacio-ico { font-size: 2.5rem; margin-bottom: .75rem; }
.ph__vacio-txt { margin: 0 auto; max-width: 380px; line-height: 1.6; }
.ph__vacio-txt a { color: #1b5e20; }

@media (max-width: 520px) {
  .ph__noticia-img { width: 84px; }
}
</style>
