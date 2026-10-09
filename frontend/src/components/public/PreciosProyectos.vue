<template>
  <!-- LOS PRECIOS DE PROYECTOS, comparables (8-oct-2026). Antes: el número grande era «los dos packs»
       sin que la página dijera qué es un pack, «Para crecer» era un adicional disfrazado de plan, y
       las diferencias entre escalones no estaban alineadas. Ahora: qué trae cada pack, un interruptor
       «un pack / los dos», filas alineadas y los adicionales aparte. Los NÚMEROS los manda el backend
       (`Precios.lista_publica`); sin respuesta la sección no aparece. -->
  <section v-if="precios?.escalones?.length" class="hb__sec pr" id="precios">
    <div class="hb__wrap">
      <header class="hb__sec-h">
        <p class="hb__ceja hb__ceja--claro">Precios</p>
        <h2 class="hb__h2">Elegí el tuyo</h2>
      </header>

      <div class="pr__packs">
        <div class="pr__pack"><span class="pr__mini">Pack</span><b>Cultivo</b><p>Salas, lotes y plantas, cosecha, manicura, stock e informes de producción.</p></div>
        <div class="pr__pack"><span class="pr__mini">Pack</span><b>Producción y dispensa</b><p>Pacientes y REPROCANN, mostrador, caja, cuenta corriente y el consultorio con su turnero.</p></div>
        <div class="pr__pack"><span class="pr__mini">En los dos</span><b>Incluido siempre</b><p>Delivery, correo a pacientes y asistente IA.</p></div>
      </div>

      <div class="pr__switch" role="radiogroup" aria-label="Cuántos packs">
        <button type="button" role="radio" :aria-checked="!dos" class="pr__op" :class="{ 'is-on': !dos }" @click="dos = false">Un pack</button>
        <button type="button" role="radio" :aria-checked="dos" class="pr__op" :class="{ 'is-on': dos }" @click="dos = true">Los dos packs</button>
      </div>

      <div class="pr__planes">
        <article v-for="(e, i) in precios.escalones" :key="e.label" class="pr__plan" :class="{ 'pr__plan--dest': i === precios.escalones.length - 1 }">
          <p class="pr__nombre">{{ e.label }}</p>
          <p class="pr__precio"><b>{{ plata(dos ? e.dos_packs : e.un_pack) }}</b><span>por mes, {{ dos ? 'los dos packs' : 'un pack' }}</span></p>
          <dl class="pr__filas">
            <div><dt>Plantas en floración</dt><dd>{{ e.plantas_floracion }}</dd></div>
            <div><dt>Salas</dt><dd>{{ e.salas == null ? 'Sin límite' : e.salas }}</dd></div>
            <div><dt>Sedes</dt><dd>{{ e.sedes }}</dd></div>
            <div><dt>Usuarios</dt><dd>{{ e.usuarios_por_rol }} de cada rol{{ e.por_sede ? ' por sede' : '' }}</dd></div>
            <div><dt>Consultorio y turnero</dt><dd>{{ dos ? 'Incluido' : 'Con Producción y dispensa' }}</dd></div>
          </dl>
          <a href="#contacto" class="hb__btn" :class="{ 'hb__btn--linea': i !== precios.escalones.length - 1 }">Lo quiero</a>
        </article>
      </div>

      <div class="pr__extras">
        <div v-if="precios.pack_pacientes"><b>+{{ precios.pack_pacientes.pacientes }} pacientes · {{ plata(precios.pack_pacientes.precio) }} por mes</b>
          <span>Suma {{ precios.pack_pacientes.plantas_floracion }} plantas en floración: no hace falta saltar de escalón.</span></div>
        <div v-if="precios.sede_extra"><b>Sede extra · {{ plata(precios.sede_extra) }} por mes</b><span>Con su stock y su caja.</span></div>
        <div><b>¿Más grande que esto?</b><span><a href="#contacto">Hablemos</a> y lo armamos a medida.</span></div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref } from 'vue'

const props = defineProps({ precios: { type: Object, default: null } })
const dos = ref(true)
const plata = (n) => (props.precios?.moneda === 'USD' ? `US$ ${n}` : `$ ${n}`)
</script>

<style scoped>
.pr { background: var(--hb-bosque); color: var(--hb-papel-claro); }
.pr .hb__h2 { color: var(--hb-papel-claro); }
.pr__packs { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 14px; }
.pr__pack { border: 1px solid color-mix(in srgb, var(--hb-papel-claro) 22%, transparent); padding: 18px 20px; display: flex; flex-direction: column; gap: 4px; }
.pr__pack b { font-size: 1.15rem; }
.pr__pack p { margin: 4px 0 0; color: color-mix(in srgb, var(--hb-papel-claro) 80%, transparent); line-height: 1.5; }
.pr__mini { font: 500 11px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-menta); }
.pr__switch { display: inline-flex; gap: 4px; padding: 4px; margin: 28px 0 20px; border-radius: 999px; background: color-mix(in srgb, var(--hb-papel-claro) 12%, transparent); }
.pr__op { min-height: 44px; padding: 0 20px; border-radius: 999px; border: 0; background: transparent; color: var(--hb-papel-claro); font: 600 .95rem var(--hb-sans); cursor: pointer; }
.pr__op.is-on { background: var(--hb-papel-claro); color: var(--hb-bosque); }
.pr__op:focus-visible { outline: 2px solid var(--hb-menta); outline-offset: 2px; }
.pr__planes { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 320px), 1fr)); gap: 20px; }
.pr__plan { background: var(--hb-papel-claro); color: var(--hb-tinta); padding: 28px; display: flex; flex-direction: column; gap: 16px; }
.pr__plan--dest { box-shadow: 0 0 0 3px var(--hb-menta); }
.pr__nombre { margin: 0; font: 500 12px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-verde); }
.pr__precio { margin: 0; display: flex; align-items: baseline; flex-wrap: wrap; gap: 8px; }
.pr__precio b { font: 600 2.6rem/1 var(--hb-serif); }
.pr__precio span { font: 13px var(--hb-mono); color: var(--hb-tinta-2); }
.pr__filas { margin: 0; display: flex; flex-direction: column; }
.pr__filas div { display: flex; justify-content: space-between; gap: 16px; padding: 11px 0; border-top: 1px solid var(--hb-regla); }
.pr__filas dt { color: var(--hb-tinta-2); }
.pr__filas dd { margin: 0; font-weight: 700; text-align: right; }
.pr__plan .hb__btn { align-self: flex-start; margin-top: auto; }
.pr__extras { margin-top: 20px; display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 1px; background: color-mix(in srgb, var(--hb-papel-claro) 18%, transparent); }
.pr__extras > div { background: var(--hb-verde-osc); padding: 18px 22px; display: flex; flex-direction: column; gap: 4px; }
.pr__extras span { color: color-mix(in srgb, var(--hb-papel-claro) 82%, transparent); }
.pr__extras a { color: var(--hb-menta); }
</style>
