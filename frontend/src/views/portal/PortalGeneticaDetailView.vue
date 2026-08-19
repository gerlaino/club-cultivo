<template>
  <article class="pgd">
    <div v-if="estado === 'cargando'" class="pgd__cargando"><DsSpinner :size="32" /></div>

    <PortalVacio v-else-if="estado === 'no_encontrada'"
                 titulo="Esta variedad no está disponible"
                 texto="Puede que tu organización la haya sacado del catálogo."
                 hacia-a="/portal/geneticas" hacia-txt="Ver el catálogo" />

    <template v-else>
      <PortalCabecera :titulo="gen.nombre" volver-a="/portal/geneticas" volver-txt="Variedades" />

      <div class="pgd__chips">
        <span v-if="gen.tipo" class="pgd__chip">{{ TIPOS[gen.tipo] || gen.tipo }}</span>
        <span v-if="gen.registrada_inase" class="pgd__chip pgd__chip--inase">
          <BadgeCheck :size="12" :stroke-width="2" /> INASE
        </span>
      </div>

      <p v-if="gen.criador" class="pgd__criador">
        {{ gen.criador }}<template v-if="gen.origen"> · {{ gen.origen }}</template>
      </p>

      <!-- Fotos: la primera grande, el resto en tira. Es una planta; se mira antes de leerse. -->
      <div v-if="gen.fotos_urls?.length" class="pgd__fotos">
        <img :src="gen.fotos_urls[0]" :alt="gen.nombre" class="pgd__foto-1" />
        <div v-if="gen.fotos_urls.length > 1" class="pgd__tira">
          <img v-for="(f, i) in gen.fotos_urls.slice(1)" :key="i" :src="f" :alt="gen.nombre" loading="lazy" />
        </div>
      </div>

      <!-- Cannabinoides: es lo primero que mira un paciente. -->
      <div class="pgd__cann">
        <div class="pgd__c">
          <span class="pgd__c-l">THC</span>
          <span class="pgd__c-v">{{ gen.thc != null ? gen.thc + '%' : '—' }}</span>
          <span v-if="gen.thc != null" class="pgd__barra">
            <span class="pgd__barra-f" :style="{ width: pct(gen.thc) }"></span>
          </span>
        </div>
        <div class="pgd__c">
          <span class="pgd__c-l">CBD</span>
          <span class="pgd__c-v">{{ gen.cbd != null ? gen.cbd + '%' : '—' }}</span>
          <span v-if="gen.cbd != null" class="pgd__barra">
            <span class="pgd__barra-f pgd__barra-f--cbd" :style="{ width: pct(gen.cbd) }"></span>
          </span>
        </div>
      </div>

      <section v-if="terpenos.length" class="pgd__sec">
        <h2 class="pgd__sec-t">Perfil terpénico</h2>
        <div class="pgd__terps">
          <span v-for="t in terpenos" :key="t" class="pgd__terp">{{ t }}</span>
        </div>
      </section>

      <section v-if="gen.descripcion" class="pgd__sec">
        <h2 class="pgd__sec-t">Sobre esta variedad</h2>
        <p class="pgd__desc">{{ gen.descripcion }}</p>
      </section>

      <section v-if="datosCultivo.length" class="pgd__sec">
        <h2 class="pgd__sec-t">Cómo se cultiva</h2>
        <dl class="pgd__datos">
          <div v-for="d in datosCultivo" :key="d.l" class="pgd__dato">
            <dt>{{ d.l }}</dt>
            <dd>{{ d.v }}</dd>
          </div>
        </dl>
      </section>
    </template>
  </article>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { BadgeCheck } from 'lucide-vue-next'
import { getPortalGenetica } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const route = useRoute()
// El backend acepta id o slug: los enlaces del catálogo mandan el id y los QR viejos, el slug.
const idOSlug = route.params.id

const TIPOS = { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida', ruderalis: 'Ruderalis' }
const DIF   = { facil: 'Fácil', media: 'Media', dificil: 'Difícil' }

const gen    = ref(null)
const estado = ref('cargando')

// El tope de 30% no es arbitrario: por encima de eso no hay flor, así que la barra llena
// significa "de lo más alto que se ve" y no "el máximo teórico".
const pct = (v) => `${Math.min(Number(v), 30) / 30 * 100}%`

const terpenos = computed(() =>
  gen.value?.terpenos ? gen.value.terpenos.split(',').map(t => t.trim()).filter(Boolean) : []
)

const datosCultivo = computed(() => {
  const g = gen.value || {}
  return [
    g.tiempo_floracion && { l: 'Floración', v: `${g.tiempo_floracion} días` },
    g.dificultad       && { l: 'Dificultad', v: DIF[g.dificultad] || g.dificultad },
    g.origen           && { l: 'Origen', v: g.origen },
  ].filter(Boolean)
})

onMounted(async () => {
  try {
    gen.value = await getPortalGenetica(idOSlug)
    estado.value = 'ok'
  } catch {
    estado.value = 'no_encontrada'
  }
})
</script>

<style scoped>
.pgd { max-width: 620px; margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pgd__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pgd__chips { display: flex; flex-wrap: wrap; gap: var(--sp-2); margin: calc(var(--sp-6) * -1 + var(--sp-2)) 0 var(--sp-2); }
.pgd__chip {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-12); font-weight: 600;
  background: var(--p-marca-suave); color: var(--p-marca-fuerte);
  padding: 2px var(--sp-3); border-radius: var(--r-pill);
}
.pgd__chip--inase { background: var(--p-marca-fuerte); color: #fff; letter-spacing: .05em; }
.pgd__criador { color: var(--p-suave); margin: 0 0 var(--sp-5); }

.pgd__fotos { margin-bottom: var(--sp-6); }
.pgd__foto-1 { width: 100%; border-radius: var(--p-radio); display: block; }
.pgd__tira { display: flex; gap: var(--sp-2); margin-top: var(--sp-2); overflow-x: auto; }
.pgd__tira img { width: 92px; height: 92px; object-fit: cover; border-radius: var(--p-radio-sm); flex: 0 0 auto; }

.pgd__cann { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); margin-bottom: var(--sp-8); }
.pgd__c { background: var(--p-hundido); border-radius: var(--p-radio); padding: var(--sp-4); }
.pgd__c-l { display: block; font-size: var(--fs-12); letter-spacing: .1em; color: var(--p-tenue); }
.pgd__c-v { display: block; font-family: var(--p-display); font-size: var(--fs-24); font-weight: 700; line-height: 1.1; }
.pgd__barra { display: block; height: 5px; background: var(--p-linea); border-radius: var(--r-pill); margin-top: var(--sp-2); overflow: hidden; }
.pgd__barra-f { display: block; height: 100%; background: var(--p-marca); border-radius: var(--r-pill); }
.pgd__barra-f--cbd { background: var(--p-marca-linea); }

.pgd__sec { margin-bottom: var(--sp-6); }
.pgd__sec-t {
  font-family: var(--p-display); font-size: var(--fs-16); font-weight: 600; margin: 0 0 var(--sp-3);
  border-bottom: 1px solid var(--p-linea); padding-bottom: var(--sp-2);
}
.pgd__terps { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.pgd__terp {
  font-size: var(--fs-13); background: var(--p-hundido); color: var(--p-suave);
  padding: var(--sp-1) var(--sp-3); border-radius: var(--r-pill);
}
.pgd__desc { margin: 0; line-height: var(--lh-loose); white-space: pre-line; }

.pgd__datos { margin: 0; display: flex; flex-direction: column; gap: var(--sp-2); }
.pgd__dato { display: flex; gap: var(--sp-4); align-items: baseline; }
.pgd__dato dt { font-size: var(--fs-13); color: var(--p-tenue); width: 92px; flex: 0 0 auto; }
.pgd__dato dd { margin: 0; font-weight: 500; }
</style>
