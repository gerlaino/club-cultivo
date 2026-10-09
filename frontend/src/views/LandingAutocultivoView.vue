<template>
  <PaginaPublica>
    <!-- ── Portada de casa ────────────────────────────────── -->
    <section class="lc__portada">
      <div class="hb__wrap lc__portada-in">
        <div>
          <p class="hb__ceja">Autocultivo · uso personal</p>
          <h1 class="hb__h1">Tus plantas, <em>anotadas mientras crecen.</em></h1>
          <p class="hb__bajada">
            Agregás tus plantas, anotás desde el teléfono al lado de la carpa y la app te avisa lo que
            viene. Carpa, balcón o cama de suelo vivo; autos y fotos juntas. Todo en el teléfono.
          </p>
          <div class="hb__acciones">
            <RouterLink to="/registro" class="hb__btn">
              Crear mi cuenta gratis
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </RouterLink>
            <a href="#que-hace" class="hb__btn hb__btn--linea">Ver qué hace</a>
          </div>
          <p class="hb__nota">{{ diasPrueba }} días gratis · sin tarjeta · entrás en el momento</p>
        </div>
        <!-- El teléfono con la app (Germán, 9-oct: no repetir la planta que crece de la portada). -->
        <TelefonoMiCultivo class="lc__tel" />
      </div>
    </section>

    <!-- ── Así se usa: tres pasos ─────────────────────────── -->
    <section class="hb__sec">
      <div class="hb__wrap">
        <header class="hb__sec-h">
          <p class="hb__ceja">Así se usa</p>
          <h2 class="hb__h2">Tres cosas, nada más</h2>
        </header>
        <ol class="lc__pasos">
          <li v-for="(p, i) in PASOS" :key="p.t" class="lc__paso hb-rev" :style="{ transitionDelay: `${i * 90}ms` }">
            <span class="lc__paso-n">{{ i + 1 }}</span>
            <h3 class="hb__h3">{{ p.t }}</h3>
            <p>{{ p.d }}</p>
          </li>
        </ol>
      </div>
    </section>

    <QueHace ceja="Qué hace por tu cultivo" titulo="De la semilla al frasco, sin planillas" :temas="TEMAS_AUTOCULTIVO" />

    <Bolsillo />

    <Packs :packs="packs" :accion="{ label: 'Crear mi cuenta', to: '/registro' }" />

    <PreguntasFrecuentes titulo="Lo que nos preguntan en autocultivo" :preguntas="PREGUNTAS_AUTOCULTIVO"
                         contacto="#contacto" />

    <!-- ── Contacto: para quien prefiere hablar antes de probar ── -->
    <section class="hb__sec" id="contacto">
      <div class="hb__wrap lc__contacto">
        <div>
          <p class="hb__ceja">Contacto</p>
          <h2 class="hb__h2">¿Preferís hablar antes?</h2>
          <p class="lc__cierre-p">Contanos cómo cultivás y te ayudamos a arrancar: tus plantas, tus nutrientes o lo que tengas anotado.</p>
        </div>
        <ContactoForm tipo-inicial="personal" :tipos="['personal']" />
      </div>
    </section>

    <!-- ── Cierre: crear la cuenta ────────────────────────── -->
    <section class="hb__sec hb__sec--claro">
      <div class="hb__wrap lc__cierre">
        <div>
          <p class="hb__ceja">Empezá hoy</p>
          <h2 class="hb__h2">Probala {{ diasPrueba }} días, gratis</h2>
          <p class="lc__cierre-p">Sin tarjeta. Entrás en el momento y el mail lo confirmás después.</p>
        </div>
        <div class="lc__cierre-acc">
          <RouterLink to="/registro" class="hb__btn">Crear mi cuenta</RouterLink>
          <a href="#contacto" class="lc__hablar">¿Preferís hablar antes? Escribinos</a>
        </div>
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// LA PÁGINA DE «AUTOCULTIVO» (/bienvenida/autocultivo, 5-oct-2026): sólo lo que le importa a quien cultiva
// para sí — su espacio, sus plantas, sus frascos y sus números. Sin pacientes, sedes ni caja.
// El contenido (solapas y preguntas) está en `components/public/contenido.js`. Termina en el
// autoregistro (/registro); el contacto queda para quien prefiere hablar antes.
import { ref, onMounted } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import QueHace from '../components/public/QueHace.vue'
import Bolsillo from '../components/public/Bolsillo.vue'
import PreguntasFrecuentes from '../components/public/PreguntasFrecuentes.vue'
import Packs from '../components/public/Packs.vue'
import ContactoForm from '../components/public/ContactoForm.vue'
import TelefonoMiCultivo from '../components/public/TelefonoMiCultivo.vue'
import { TEMAS_AUTOCULTIVO, PREGUNTAS_AUTOCULTIVO, packsAutocultivo } from '../components/public/contenido.js'
import { getRegistroInfo } from '../lib/api.js'

const diasPrueba = ref(30)
const PASOS = [
  { t: 'Agregás tus plantas', d: 'De a una o varias juntas: la genética, si es auto o foto, dónde está y desde cuándo.' },
  { t: 'Anotás al lado de la carpa', d: 'Regar con cuánto y con qué, una foto o una nota: un toque, a una planta o a toda la carpa. O dictándolo.' },
  { t: 'La app te avisa lo que viene', d: 'El primer fertilizante, el cambio a flora, la cosecha. Al teléfono.' },
]
// El precio lo dice el backend (`Precios.lista_publica`); acá sólo las palabras.
const packs = ref([])
onMounted(async () => {
  try {
    const { data } = await getRegistroInfo()
    diasPrueba.value = data.dias_prueba
    packs.value = packsAutocultivo(data.precios)
  } catch {}
})
</script>

<style scoped>
.lc__portada {
  padding: clamp(40px, 7vw, 88px) 0 clamp(24px, 4vw, 48px);
  background: radial-gradient(55% 70% at 85% 40%, color-mix(in srgb, var(--hb-menta) 30%, transparent) 0%, transparent 70%);
}
.lc__portada-in { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(0, .9fr); gap: clamp(24px, 5vw, 64px); align-items: center; }
.lc__tel { justify-self: center; }
@media (max-width: 860px) {
  .lc__portada-in { grid-template-columns: minmax(0, 1fr); }
  .lc__tel { width: min(280px, 80%); }
}
.lc__pasos { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 20px; }
.lc__paso { padding: 24px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); display: flex; flex-direction: column; gap: 8px; }
.lc__paso p { margin: 0; color: var(--hb-tinta-2); line-height: 1.55; }
.lc__paso-n { font: 600 2rem/1 var(--hb-serif); color: var(--hb-verde); }
.lc__contacto { display: grid; grid-template-columns: minmax(0, .9fr) minmax(0, 1.1fr); gap: clamp(24px, 5vw, 64px); align-items: start; }
@media (max-width: 860px) { .lc__contacto { grid-template-columns: minmax(0, 1fr); } }

.lc__cierre { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 24px; }
.lc__cierre-p { margin: 12px 0 0; color: var(--hb-tinta-2); }
.lc__cierre-acc { display: flex; flex-direction: column; align-items: flex-start; gap: 12px; }
.lc__hablar { color: var(--hb-verde); font-weight: 600; text-decoration: none; font-size: .95rem; }
.lc__hablar:hover { text-decoration: underline; }
</style>
