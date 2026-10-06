<template>
  <PaginaPublica>
    <!-- ── Portada de casa ────────────────────────────────── -->
    <section class="lc__portada">
      <div class="hb__wrap lc__portada-in">
        <div>
          <p class="hb__ceja">Autocultivo · uso personal</p>
          <h1 class="hb__h1">Tu cultivo, <em>anotado mientras crece.</em></h1>
          <p class="hb__bajada">
            Carpa, balcón o cama de suelo vivo. Cada planta con su diario, los riegos y nutrientes que
            le diste, los próximos pasos del ciclo y cuánto te costó cada gramo. Todo en el teléfono.
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
        <img class="lc__planta" src="/planta/06.webp" alt="Una planta de cannabis en su maceta, en floración" />
      </div>
    </section>

    <QueHace ceja="Qué hace por tu cultivo" titulo="De la semilla al frasco, sin planillas" :temas="TEMAS_AUTOCULTIVO" />

    <Bolsillo />

    <Packs :packs="packs" :accion="{ label: 'Crear mi cuenta', to: '/registro' }" />

    <PreguntasFrecuentes titulo="Lo que nos preguntan en autocultivo" :preguntas="PREGUNTAS_AUTOCULTIVO"
                         :contacto="{ path: '/contacto', query: { tipo: 'personal' } }" />

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
          <RouterLink :to="{ path: '/contacto', query: { tipo: 'personal' } }" class="lc__hablar">¿Preferís hablar antes? Escribinos</RouterLink>
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
import { TEMAS_AUTOCULTIVO, PREGUNTAS_AUTOCULTIVO, packsAutocultivo } from '../components/public/contenido.js'
import { getRegistroInfo } from '../lib/api.js'

const diasPrueba = ref(30)
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
.lc__planta { justify-self: center; width: min(380px, 100%); height: auto; filter: drop-shadow(0 24px 30px color-mix(in srgb, var(--hb-tinta) 18%, transparent)); }
@media (max-width: 860px) {
  .lc__portada-in { grid-template-columns: minmax(0, 1fr); }
  .lc__planta { width: min(260px, 70%); }
}

.lc__cierre { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 24px; }
.lc__cierre-p { margin: 12px 0 0; color: var(--hb-tinta-2); }
.lc__cierre-acc { display: flex; flex-direction: column; align-items: flex-start; gap: 12px; }
.lc__hablar { color: var(--hb-verde); font-weight: 600; text-decoration: none; font-size: .95rem; }
.lc__hablar:hover { text-decoration: underline; }
</style>
