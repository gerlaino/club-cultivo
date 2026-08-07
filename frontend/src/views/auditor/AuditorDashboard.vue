<template>
  <div class="aud-home">
    <header class="aud-home__head">
      <h1 class="aud-home__title">Reportes</h1>
      <p class="aud-home__sub">
        Todos se descargan en PDF y Excel, con el membrete del club y los datos de la fecha
        en que los generás.
      </p>
    </header>

    <!-- Agrupados por para qué sirven, no por qué módulo los produce: el que entra acá
         viene con una pregunta ("¿estamos en regla?", "¿cómo viene la producción?"), no
         con ganas de recorrer un catálogo. -->
    <section v-for="grupo in GRUPOS" :key="grupo.titulo" class="aud-grupo">
      <div class="aud-grupo__head">
        <h2 class="aud-grupo__title">{{ grupo.titulo }}</h2>
        <p class="aud-grupo__desc">{{ grupo.desc }}</p>
      </div>
      <div class="aud-home__cards">
        <RouterLink v-for="inf in grupo.informes" :key="inf.to" :to="inf.to" class="aud-card">
          <component :is="inf.icon" :size="24" :stroke-width="1.5" class="aud-card__ico" />
          <span class="aud-card__label">{{ inf.label }}</span>
          <span class="aud-card__desc">{{ inf.desc }}</span>
          <span class="aud-card__q">{{ inf.pregunta }}</span>
        </RouterLink>
      </div>
    </section>
  </div>
</template>

<script setup>
import {
  FileCheck, Sprout, Package, Building2, ShieldAlert, FileBadge, Target, Search,
} from 'lucide-vue-next'

const GRUPOS = [
  {
    titulo: 'Cumplimiento',
    desc: 'Lo que hay que poder mostrar si golpean la puerta.',
    informes: [
      { to: '/auditor/reprocann', icon: FileCheck, label: 'REPROCANN',
        desc: 'Estado del certificado de cada paciente, por sede, y las entregas que recibieron.',
        pregunta: '¿Está todo el mundo en regla?' },
      { to: '/auditor/cumplimiento', icon: ShieldAlert, label: 'Cumplimiento',
        desc: 'Tasa de pacientes al día y alertas abiertas.',
        pregunta: '¿Qué me falta resolver?' },
      { to: '/auditor/inase', icon: FileBadge, label: 'INASE',
        desc: 'Variedades cultivadas y su registro.',
        pregunta: '¿Qué genéticas declaro?' },
    ],
  },
  {
    titulo: 'Operación',
    desc: 'Cómo viene el club puertas adentro.',
    informes: [
      { to: '/auditor/produccion', icon: Sprout, label: 'Producción',
        desc: 'Lotes, plantas y gramos del período.',
        pregunta: '¿Cuánto estamos produciendo?' },
      { to: '/auditor/dispensaciones', icon: Package, label: 'Dispensaciones',
        desc: 'Entregas, gramos y pacientes atendidos.',
        pregunta: '¿Cuánto sale y a cuántos?' },
      { to: '/auditor/sedes', icon: Building2, label: 'Sedes',
        desc: 'Salas, plantas y stock de cada una.',
        pregunta: '¿Cómo está repartido todo?' },
    ],
  },
  {
    titulo: 'Análisis',
    desc: 'Para decidir, no para declarar.',
    informes: [
      { to: '/auditor/plan-vs-real', icon: Target, label: 'Plan vs. real',
        desc: 'Lo que se esperaba de cada lote contra lo que dio.',
        pregunta: '¿Le acertamos a los objetivos?' },
      { to: '/auditor/trazabilidad', icon: Search, label: 'Trazabilidad',
        desc: 'El recorrido completo de un lote, de la semilla a la entrega.',
        pregunta: '¿De dónde salió esto?' },
    ],
  },
]
</script>

<style scoped>
.aud-home { padding: var(--sp-6); max-width: 1080px; margin: 0 auto; }
.aud-home__head { margin-bottom: var(--sp-6); }
.aud-home__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.aud-home__sub { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0; max-width: 60ch; }

.aud-grupo { margin-bottom: var(--sp-7, 2.5rem); }
.aud-grupo__head { margin-bottom: var(--sp-3); }
.aud-grupo__title { font-size: var(--fs-13); font-weight: 800; color: var(--c-ink-900); margin: 0; text-transform: uppercase; letter-spacing: .06em; }
.aud-grupo__desc { font-size: var(--fs-13); color: var(--c-ink-500); margin: .15rem 0 0; }

.aud-home__cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: var(--sp-3); }
.aud-card {
  display: flex; flex-direction: column; gap: var(--sp-1);
  background: #fff; border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-4); text-decoration: none; color: var(--c-ink-700);
  transition: border-color .15s, box-shadow .15s, transform .15s;
}
.aud-card:hover { border-color: #8B5A2B; box-shadow: 0 4px 14px rgba(139,90,43,.12); transform: translateY(-1px); }
.aud-card__ico { color: #8B5A2B; margin-bottom: var(--sp-1); }
.aud-card__label { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }
.aud-card__desc { font-size: var(--fs-12); color: var(--c-ink-500); line-height: 1.45; }
/* La pregunta que el informe contesta: es lo que hace elegir sin tener que abrirlos todos. */
.aud-card__q { font-size: var(--fs-12); color: #8B5A2B; font-style: italic; margin-top: auto; padding-top: var(--sp-2); }

@media (max-width: 640px) {
  .aud-home { padding: var(--sp-4); }
  .aud-home__cards { grid-template-columns: 1fr; }
}
</style>
