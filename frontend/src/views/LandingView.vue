<template>
  <PaginaPublica :accion="null">
    <!-- ── La portada partida (23-oct-2026, Javi: «cuando llegás tenemos dos secciones pero se lee
         como todo uno mismo»). 3/4 para organizaciones, que es quien contrata, con el texto de Javi
         y los dos planes; 1/4 para autocultivo, en trigo, con la planta que crece. En el teléfono
         se apilan en el mismo orden. Reemplaza a la portada «cada planta, cada gramo, cada peso»
         y a la sección «¿Para qué la querés?»: las dos puertas ahora son la portada. ── -->
    <section class="lp">
      <div class="lp__org">
        <div class="lp__org-in">
          <p class="hb__ceja lp__ceja">Software de gestión y trazabilidad · proyectos cannábicos en la Argentina</p>
          <h1 class="lp__h1">Toda tu organización, <em>en una plataforma.</em></h1>
          <p class="lp__bajada">Trazabilidad de cultivos, genéticas, lotes, stock, dispensas y pacientes, para proyectos de dispensa e investigación.</p>

          <ul class="lp__puntos">
            <li><b>Todo el equipo, un lugar</b><span>Cultivo, manicura, médicos, comercial y administración, cada uno con su pantalla.</span></li>
            <li><b>En tiempo real</b><span>Lo que pasa en cada sala y en el mostrador, desde donde estés.</span></li>
            <li><b>Informes listos</b><span>REPROCANN, INASE y análisis de producción para presentar.</span></li>
          </ul>

          <div class="lp__acciones">
            <RouterLink to="/bienvenida/organizaciones" class="hb__btn">
              Conocer la plataforma
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </RouterLink>
            <RouterLink to="/bienvenida/organizaciones/demo" class="hb__btn hb__btn--linea lp__btn-linea">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7 4.5v15l13-7.5z"/></svg>
              Ver la demo
            </RouterLink>
            <RouterLink to="/contacto" class="hb__btn hb__btn--linea lp__btn-linea">Hablemos</RouterLink>
            <span class="hb__nota lp__nota">Armamos la cuenta y cargamos tu padrón</span>
          </div>

          <!-- Los planes: los NÚMEROS y los límites los manda el backend (`Precios.lista_publica`, el
               mismo que la tabla de /bienvenida/organizaciones). Sin respuesta, no se muestra ninguno. -->
          <template v-if="escalones.length">
            <div class="lp__planes">
              <article v-for="e in escalones" :key="e.clave" class="lp__plan">
                <p class="lp__plan-n">{{ e.label }}</p>
                <p class="lp__plan-p">{{ plata(e.un_pack) }} <span>por mes, un pack</span></p>
                <p class="lp__plan-dos">Los dos packs: <b>{{ plata(e.dos_packs) }}</b> por mes</p>
                <ul class="lp__plan-l">
                  <li>{{ e.sedes === 1 ? '1 sede' : `${e.sedes} sedes` }} y {{ e.salas == null ? 'salas libres' : `${e.salas} salas` }}</li>
                  <li>Hasta {{ e.plantas_floracion }} plantas en floración</li>
                  <li>{{ e.usuarios_por_rol }} personas de cada rol{{ e.por_sede ? ', en cada sede' : ' en el equipo' }}</li>
                  <li v-if="packPacientes">Sumale pacientes de a {{ packPacientes }}{{ e.sedes > 1 && sedeExtra ? ' y sedes extra' : '' }}</li>
                </ul>
                <RouterLink :to="{ path: '/bienvenida/organizaciones', hash: '#contacto' }" class="hb__btn hb__btn--linea lp__plan-btn">Empezar con este plan</RouterLink>
              </article>
            </div>
            <p class="lp__planes-pie">
              <span>Packs: Cultivo · Producción y dispensa. Delivery, correo, módulo médico y asistente IA, incluidos.</span>
              <RouterLink :to="{ path: '/bienvenida/organizaciones', hash: '#precios' }" class="lp__ver">Ver qué trae cada pack →</RouterLink>
            </p>
          </template>
        </div>
      </div>

      <div class="lp__auto">
        <p class="hb__ceja lp__auto-ceja">Autocultivo · uso personal</p>
        <h2 class="lp__auto-h">¿Cultivás en casa? <em>Como un profesional.</em></h2>
        <div class="lp__planta"><PlantaCreciendo /></div>
        <p class="lp__auto-d">Qué hacer hoy, lo que regaste y cómo va cada planta, desde el celular.</p>
        <p v-if="precioAuto" class="lp__auto-p">{{ precioAuto }} <span>por mes</span></p>
        <RouterLink to="/registro" class="hb__btn lp__auto-btn">Probar {{ diasPrueba }} días gratis</RouterLink>
        <p class="lp__auto-nota">Sin tarjeta · <RouterLink to="/bienvenida/autocultivo/demo">ver la demo</RouterLink> · <RouterLink to="/bienvenida/autocultivo">cómo funciona</RouterLink></p>
      </div>
    </section>

    <section class="hb__sec lp__confianza-sec">
      <div class="hb__wrap">
        <div class="lv__confianza">
          <div><h3 class="hb__h3">Tus datos son tuyos</h3><p>No se venden ni se usan para publicidad. Cada cuenta está aislada y hay copias de seguridad verificadas.</p></div>
          <div><h3 class="hb__h3">Anda en el teléfono</h3><p>Se instala desde el navegador en segundos, sin tiendas. Y sin señal también anota.</p></div>
          <div><h3 class="hb__h3">Pensada para la Argentina</h3><p>REPROCANN e INASE adentro, con informes que salen de lo que ya cargaste.</p></div>
        </div>
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// LA PORTADA PÚBLICA (/bienvenida). Desde el 23-oct-2026 es la portada partida que pidió Javi:
// organizaciones (3/4, verde claro, con los planes) y autocultivo (1/4, trigo, con la planta). Cada
// público sigue teniendo SU página —/bienvenida/organizaciones (la cuenta se arma a mano desde el
// contacto) y /bienvenida/autocultivo (se registra solo)—; acá está lo justo para elegir puerta.
// Los precios, los límites de cada plan y los días de prueba los dice el backend.
import { ref, computed, onMounted } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import PlantaCreciendo from '../components/public/PlantaCreciendo.vue'
import { getRegistroInfo } from '../lib/api.js'

const diasPrueba = ref(30)
const precios = ref(null)
const precioAuto = computed(() => precios.value?.autocultivo ? plata(precios.value.autocultivo.precio) : '')
const escalones = computed(() => precios.value?.escalones || [])
const packPacientes = computed(() => precios.value?.pack_pacientes?.pacientes || 0)
const sedeExtra = computed(() => precios.value?.sede_extra || 0)
const plata = (n) => (precios.value?.moneda === 'USD' ? `US$ ${n}` : `$ ${n}`)

onMounted(async () => {
  try {
    const { data } = await getRegistroInfo()
    diasPrueba.value = data.dias_prueba
    precios.value = data.precios || null
  } catch {}
})
</script>

<style scoped>
/* ── La portada partida ── */
.lp { display: grid; grid-template-columns: minmax(0, 3fr) minmax(0, 1fr); }
@media (max-width: 960px) { .lp { grid-template-columns: minmax(0, 1fr); } }

.lp__org {
  position: relative; overflow: hidden; background: var(--hb-salvia-suave);
  padding: clamp(32px, 5vw, 64px) var(--hb-relleno) clamp(28px, 4vw, 48px);
}
.lp__org::after {
  content: ""; position: absolute; right: -120px; bottom: -160px; width: 520px; height: 520px; border-radius: 50%;
  background: radial-gradient(circle, color-mix(in srgb, var(--hb-menta) 45%, transparent), transparent 65%); pointer-events: none;
}
.lp__org-in { position: relative; z-index: 1; max-width: 960px; margin-left: auto; display: flex; flex-direction: column; gap: 20px; height: 100%; }
.lp__ceja { margin: 0; color: var(--hb-verde); }
.lp__h1 {
  margin: 0; font-family: var(--hb-serif); font-weight: 600; letter-spacing: -.02em;
  font-size: clamp(2.2rem, 4.6vw, 3.6rem); line-height: 1.04; text-wrap: balance; max-width: 15ch;
  font-variation-settings: 'opsz' 144;
}
.lp__h1 em { font-style: italic; font-weight: 400; color: var(--hb-verde); }
.lp__bajada { margin: 0; max-width: 46em; font-size: 1.1rem; color: var(--hb-tinta-2); }
.lp__puntos { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
.lp__puntos li { display: grid; gap: 4px; padding-top: 12px; border-top: 1px solid color-mix(in srgb, var(--hb-tinta) 16%, transparent); }
.lp__puntos b { font-size: 15px; }
.lp__puntos span { font-size: 14px; color: var(--hb-tinta-2); line-height: 1.45; }
@media (max-width: 640px) { .lp__puntos { grid-template-columns: minmax(0, 1fr); } }
.lp__acciones { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }
.lp__btn-linea { border-color: var(--hb-tinta-2); color: var(--hb-tinta); }
.lp__nota { margin: 0; }

/* Los planes llenan lo que queda de la columna: la de organizaciones termina a la par de la de autocultivo. */
.lp__planes { flex: 1; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; margin-top: 4px; }
@media (max-width: 640px) { .lp__planes { grid-template-columns: minmax(0, 1fr); } }
.lp__plan { display: flex; flex-direction: column; gap: 10px; padding: 22px 24px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); border-radius: 16px; }
.lp__plan p { margin: 0; }
.lp__plan-n { font: 500 12px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-tinta-2); }
.lp__plan-p { font: 600 clamp(2rem, 3.4vw, 2.6rem)/1 var(--hb-serif); letter-spacing: -.01em; }
.lp__plan-p span { font: 500 14px var(--hb-sans); color: var(--hb-tinta-2); letter-spacing: 0; }
.lp__plan-dos { font-size: 15px; }
.lp__plan-dos b { color: var(--hb-verde); }
.lp__plan-l { list-style: none; margin: 0; padding: 12px 0 0; border-top: 1px solid var(--hb-regla); display: grid; gap: 8px; font-size: 14px; color: var(--hb-tinta-2); }
.lp__plan-l li { position: relative; padding-left: 16px; }
.lp__plan-l li::before { content: ""; position: absolute; left: 0; top: .6em; width: 6px; height: 6px; border-radius: 50%; background: var(--hb-verde); }
.lp__plan-btn { margin-top: auto; border-color: var(--hb-tinta-2); color: var(--hb-tinta); }
.lp__planes-pie { margin: 0; display: flex; flex-wrap: wrap; gap: 6px 18px; align-items: baseline; font-size: 14px; color: var(--hb-tinta-2); }
.lp__ver { margin-left: auto; color: var(--hb-verde); font-weight: 600; text-decoration: none; white-space: nowrap; }
.lp__ver:hover { text-decoration: underline; }

/* ── Autocultivo, en trigo ── */
.lp__auto {
  background: var(--hb-trigo); color: var(--hb-tinta); border-left: 1px solid color-mix(in srgb, var(--hb-tinta) 12%, transparent);
  padding: clamp(32px, 5vw, 64px) clamp(20px, 2.4vw, 32px) clamp(28px, 4vw, 48px);
  display: flex; flex-direction: column; gap: 14px;
}
@media (max-width: 960px) { .lp__auto { border-left: 0; border-top: 1px solid color-mix(in srgb, var(--hb-tinta) 12%, transparent); padding-inline: var(--hb-relleno); } }
.lp__auto p { margin: 0; }
.lp__auto-ceja { color: var(--hb-tierra); }
.lp__auto-h { margin: 0; font: 600 clamp(1.5rem, 2.2vw, 1.9rem)/1.1 var(--hb-serif); letter-spacing: -.015em; text-wrap: balance; }
.lp__auto-h em { font-style: italic; font-weight: 400; color: var(--hb-trigo-acento); }
.lp__planta { max-width: 320px; width: 100%; }
@media (max-width: 960px) { .lp__planta { max-width: 220px; } }
.lp__auto-d { font-size: 15px; color: var(--hb-trigo-tinta); }
.lp__auto-p { font: 600 2rem/1 var(--hb-serif); }
.lp__auto-p span { font: 500 14px var(--hb-sans); color: var(--hb-tierra); }
.lp__auto-btn { background: var(--hb-bosque); border-color: var(--hb-bosque); }
.lp__auto-nota { font-size: 13px; color: var(--hb-tierra); }
.lp__auto-nota a { color: var(--hb-trigo-acento); font-weight: 600; }

/* ── Lo de confianza, debajo ── */
.lp__confianza-sec { padding-block: clamp(44px, 6vw, 72px); }
.lv__confianza { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 28px; }
.lv__confianza p { margin: 8px 0 0; color: var(--hb-tinta-2); line-height: 1.55; }
</style>
