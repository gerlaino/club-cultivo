<template>
  <PaginaPublica>
    <section class="hb__sec">
      <div class="hb__wrap ct">
        <div>
          <p class="hb__ceja">Contacto</p>
          <h1 class="hb__h2">Escribinos</h1>
          <p class="ct__p">
            Si tenés un proyecto, contanos qué hacen y te armamos la cuenta. Si autocultivás y
            preferís hablar antes de probar, también. Te respondemos por mail.
          </p>
          <p class="ct__p">
            ¿Querés arrepentirte de lo que contrataste o darte de baja? Elegí
            <strong>Arrepentimiento / baja</strong>: te damos un código de trámite en el momento.
          </p>
        </div>
        <ContactoForm :tipo-inicial="tipoInicial" />
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// /contacto (5-oct-2026): el formulario solo, para todos. Acá apuntan el botón de arrepentimiento
// del pie de cada página pública (Res. SCI 424/2020: tiene que estar a la vista), los Términos, el
// cartel de prueba terminada y el de organización suspendida. `?tipo=` elige con cuál arranca.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import ContactoForm from '../components/public/ContactoForm.vue'

const route = useRoute()
const tipoInicial = computed(() => (['organizacion', 'personal', 'baja'].includes(route.query.tipo) ? route.query.tipo : 'organizacion'))
</script>

<style scoped>
.ct { display: grid; grid-template-columns: minmax(0, .8fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px); align-items: start; }
@media (max-width: 860px) { .ct { grid-template-columns: minmax(0, 1fr); } }
.ct__p { margin: 16px 0 0; color: var(--hb-tinta-2); max-width: 32em; }
</style>
