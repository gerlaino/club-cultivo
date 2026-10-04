<template>
  <div class="hb">

    <!-- ── Encabezado ─────────────────────────────────────── -->
    <header class="hb__top">
      <div class="hb__wrap hb__top-in">
        <RouterLink to="/bienvenida" class="hb__marca">Cultivo Espacial</RouterLink>
        <nav class="hb__nav" aria-label="Secciones">
          <a href="#empezar">En casa</a>
          <a href="#organizaciones">Organizaciones</a>
          <a href="#contacto" @click="tipo = 'organizacion'">Contacto</a>
        </nav>
        <RouterLink to="/login" class="hb__ingresar">Ingresar</RouterLink>
        <RouterLink to="/registro" class="hb__btn hb__btn--chico">Probar gratis</RouterLink>
      </div>
    </header>

    <!-- ── Portada: el texto y la lámina ──────────────────── -->
    <!-- En pantallas anchas la planta es el fondo de la portada, de borde a borde, y el texto va
         encima a la izquierda. En el teléfono, el texto y debajo la planta. -->
    <section class="hb__portada" :class="{ 'hb__portada--ancha': ancha }">
      <PlantaCreciendo v-if="ancha" :key="'ancha'" portada />
      <div class="hb__wrap hb__portada-in">
        <div class="hb__portada-txt">
          <p class="hb__ceja">Cuaderno de cultivo · de la semilla al frasco</p>
          <h1 class="hb__h1">Cada planta tiene su historia. <em>Escribila mientras crece.</em></h1>
          <p class="hb__bajada">
            Riegos, nutrientes, fotos, fases y cosecha, anotados en el teléfono en el momento en que
            pasan. Para tu cultivo en casa y para las organizaciones que cultivan y dispensan.
          </p>
          <div class="hb__acciones">
            <RouterLink to="/registro" class="hb__btn">
              Empezar gratis en mi cultivo
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </RouterLink>
            <a href="#organizaciones" class="hb__btn hb__btn--linea">Soy una organización</a>
          </div>
          <p class="hb__nota">{{ diasPrueba }} días gratis · sin tarjeta · entrás en el momento</p>
        </div>
      </div>
      <div v-if="!ancha" class="hb__lamina">
        <PlantaCreciendo :key="'angosta'" />
      </div>
    </section>

    <!-- ── Dos puertas ────────────────────────────────────── -->
    <section class="hb__sec" id="empezar">
      <div class="hb__wrap">
        <header class="hb__sec-h">
          <p class="hb__ceja">Cómo empezar</p>
          <h2 class="hb__h2">Dos maneras de usarla</h2>
        </header>

        <div class="hb__fichas">
          <article class="hb__ficha hb__ficha--casa hb-rev">
            <div class="hb__ficha-cab">
              <span class="hb__ficha-n">N.º 01</span>
              <span class="hb__ficha-tipo">Uso personal</span>
            </div>
            <h3 class="hb__h3">Tu cultivo en casa</h3>
            <p class="hb__ficha-d">Carpa, balcón o cama de suelo vivo. Autos o fotoperiódicas. Todo en el teléfono.</p>
            <ul class="hb__lista">
              <li v-for="x in enCasa" :key="x">{{ x }}</li>
            </ul>
            <div class="hb__ficha-pie">
              <p><strong>{{ diasPrueba }} días gratis</strong>, sin tarjeta. Después, consultanos el precio.</p>
              <RouterLink to="/registro" class="hb__btn">Crear mi cuenta</RouterLink>
            </div>
          </article>

          <article class="hb__ficha hb-rev" id="organizaciones">
            <div class="hb__ficha-cab">
              <span class="hb__ficha-n">N.º 02</span>
              <span class="hb__ficha-tipo">Organizaciones</span>
            </div>
            <h3 class="hb__h3">Tu organización</h3>
            <p class="hb__ficha-d">Asociaciones, fundaciones, investigación y producción: del cultivo al mostrador.</p>
            <ul class="hb__lista">
              <li v-for="x in enOrganizacion" :key="x">{{ x }}</li>
            </ul>
            <div class="hb__ficha-pie">
              <p>Te armamos la cuenta a medida. <strong>Precio: consultanos.</strong></p>
              <a href="#contacto" class="hb__btn hb__btn--linea" @click="tipo = 'organizacion'">Escribinos</a>
            </div>
          </article>
        </div>
      </div>
    </section>

    <!-- ── En el bolsillo: el teléfono y la instalación ───── -->
    <section class="hb__bolsillo" id="bolsillo">
      <div class="hb__wrap hb__bolsillo-in">
        <div class="hb__bolsillo-txt hb-rev">
          <p class="hb__ceja hb__ceja--claro">La app</p>
          <h2 class="hb__h2">Llevala en el bolsillo</h2>
          <p>
            Se instala en el teléfono desde el navegador, sin tiendas y en segundos. Abrís tu lote,
            tocás «Registrar» y listo: riego, foto, ambiente. Te avisa cuando le toca algo a la planta.
          </p>
          <ul class="hb__pasos">
            <li><span>1</span> Creá tu cuenta gratis</li>
            <li><span>2</span> Cargá tu espacio y tu primer lote</li>
            <li><span>3</span> Instalala y anotá desde la planta</li>
          </ul>
          <div class="hb__acciones">
            <RouterLink to="/registro" class="hb__btn hb__btn--claro">Probala gratis</RouterLink>
            <button v-if="instalable" type="button" class="hb__btn hb__btn--linea-claro" @click="instalar">Instalar en este dispositivo</button>
          </div>
          <p class="hb__instalar-ayuda">
            En iPhone: <b>Compartir</b> → <b>Agregar a inicio</b>. En Android: menú <b>⋮</b> → <b>Instalar app</b>.
          </p>
        </div>

        <!-- Un teléfono con la ficha del lote, como se ve de verdad en la app. -->
        <div class="hb__tel hb-rev" aria-hidden="true">
          <div class="hb__tel-pantalla">
            <div class="hb__tel-hero">
              <span class="hb__tel-fase">VEGETATIVO <i>AUTO</i></span>
              <b class="hb__tel-cod">L-26-002</b>
              <span class="hb__tel-gen">King’s Juice</span>
              <span class="hb__tel-falta">→ Faltan 46 días para la cosecha</span>
              <div class="hb__tel-stats">
                <div><b>3</b><small>Plantas</small></div>
                <div><b>31</b><small>Días</small></div>
                <div><b>Balcón</b><small>Espacio</small></div>
                <div><b>10 L</b><small>Maceta</small></div>
              </div>
            </div>
            <div class="hb__tel-cta">Registrar en el diario<small>Riego, pH/EC, ambiente, foto</small></div>
            <div class="hb__tel-feed">
              <div v-for="r in telFeed" :key="r.t" class="hb__tel-item"><span><component :is="r.i" :size="16" :stroke-width="1.8" /></span><div><b>{{ r.t }}</b><small>{{ r.s }}</small></div></div>
            </div>
            <div class="hb__tel-nav">
              <span>Hoy</span><span class="hb__tel-nav--on">Cultivo</span><b>+</b><span>Stock</span><span>Gastos</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── Principios ─────────────────────────────────────── -->
    <section class="hb__sec hb__sec--claro">
      <div class="hb__wrap">
        <header class="hb__sec-h">
          <p class="hb__ceja">Cómo está pensada</p>
          <h2 class="hb__h2">Un cuaderno de campo, no una planilla</h2>
        </header>
        <div class="hb__principios">
          <article v-for="(p, i) in principios" :key="p.t" class="hb__principio hb-rev" :style="{ transitionDelay: `${i * 90}ms` }">
            <span class="hb__principio-n">{{ String(i + 1).padStart(2, '0') }}</span>
            <h3 class="hb__h3">{{ p.t }}</h3>
            <p>{{ p.d }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- ── Contacto ───────────────────────────────────────── -->
    <section class="hb__sec" id="contacto">
      <div class="hb__wrap hb__contacto">
        <div class="hb__contacto-txt">
          <p class="hb__ceja">Contacto</p>
          <h2 class="hb__h2">Escribinos</h2>
          <p>
            Si sos una organización, contanos qué hacen y te armamos la cuenta. Si cultivás en casa y
            preferís hablar antes de probar, también. Te respondemos por mail.
          </p>
          <p v-if="tipo === 'baja'" class="hb__aviso">
            <strong>Botón de arrepentimiento.</strong> Si contrataste en los últimos 10 días, lo podés
            revocar sin costo ni explicaciones; también sirve para pedir la baja en cualquier momento.
            Te damos un código de trámite en el momento.
          </p>
        </div>

        <div v-if="enviado" class="hb__hoja" role="status">
          <h3 class="hb__h3">Gracias, {{ enviado.nombre }}.</h3>
          <p>Recibimos tu {{ enviado.tipo === 'baja' ? 'pedido' : 'mensaje' }}. Te respondemos a <strong>{{ enviado.email }}</strong>.</p>
          <p class="hb__codigo">Código de trámite · <strong>{{ enviado.codigo }}</strong></p>
        </div>

        <form v-else class="hb__hoja" novalidate @submit.prevent="enviar">
          <div class="hb__tipos" role="radiogroup" aria-label="Sobre qué nos escribís">
            <button v-for="t in TIPOS" :key="t.id" type="button" role="radio" :aria-checked="tipo === t.id"
                    class="hb__tipo" :class="{ 'hb__tipo--on': tipo === t.id }" @click="tipo = t.id">{{ t.label }}</button>
          </div>
          <label class="hb__campo">
            <span>Nombre</span>
            <input v-model="form.nombre" type="text" maxlength="120" autocomplete="name" required />
          </label>
          <label class="hb__campo">
            <span>Mail</span>
            <input v-model.trim="form.email" type="email" maxlength="160" autocomplete="email" required />
          </label>
          <label v-if="tipo === 'organizacion'" class="hb__campo">
            <span>Organización</span>
            <input v-model="form.organizacion" type="text" maxlength="160" autocomplete="organization" />
          </label>
          <label class="hb__campo">
            <span>Teléfono o WhatsApp <em>opcional</em></span>
            <input v-model="form.telefono" type="tel" maxlength="40" autocomplete="tel" />
          </label>
          <label class="hb__campo">
            <span>{{ tipo === 'baja' ? 'Con qué mail entrás, y lo que quieras agregar' : 'Mensaje' }} <em v-if="tipo !== 'baja'">opcional</em></span>
            <textarea v-model="form.mensaje" rows="4" maxlength="3000"></textarea>
          </label>
          <!-- Campo trampa: una persona no lo ve; un robot lo completa y el backend lo descarta. -->
          <input v-model="form.sitio" type="text" name="sitio" class="hb__trampa" tabindex="-1" autocomplete="off" aria-hidden="true" />
          <p v-if="errorContacto" class="hb__error">{{ errorContacto }}</p>
          <button type="submit" class="hb__btn" :disabled="enviando || !form.nombre || !form.email">
            {{ enviando ? 'Enviando…' : (tipo === 'baja' ? 'Enviar pedido' : 'Enviar') }}
          </button>
          <p class="hb__legal">Usamos tus datos sólo para responderte. <RouterLink to="/privacidad">Política de privacidad</RouterLink>.</p>
        </form>
      </div>
    </section>

    <!-- ── Pie ────────────────────────────────────────────── -->
    <footer class="hb__pie">
      <div class="hb__wrap hb__pie-in">
        <span class="hb__pie-marca">Cultivo Espacial</span>
        <nav class="hb__pie-nav" aria-label="Legales">
          <RouterLink to="/terminos">Términos y condiciones</RouterLink>
          <RouterLink to="/privacidad">Privacidad</RouterLink>
          <!-- Res. SCI 424/2020: el botón de arrepentimiento, a la vista en la página. -->
          <a href="#contacto" class="hb__pie-arrep" @click="tipo = 'baja'">Botón de arrepentimiento</a>
          <RouterLink to="/login">Ingresar</RouterLink>
        </nav>
        <span class="hb__pie-copy">© {{ yr }}</span>
      </div>
    </footer>
  </div>
</template>

<script setup>
// LA PÁGINA PÚBLICA, en la dirección «Herbario» (propuesta de rediseño del 29-sep-2026): papel
// cálido, tinta verde, títulos en Fraunces, datos en mono. La pieza central es una lámina de
// herbario (`LaminaPlanta`): el producto es un cuaderno de campo de cada planta.
//
// Dos puertas (Germán, 4-oct-2026): uso personal se registra solo (/registro); una organización
// deja sus datos y la cuenta se arma a mano. Precio de las dos: «consultanos». Los días de prueba
// los dice el backend.
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import PlantaCreciendo from '../components/public/PlantaCreciendo.vue'
import { Droplets, Camera, BellRing } from 'lucide-vue-next'
import { getRegistroInfo, enviarContacto } from '../lib/api.js'
import { cargarFuentesHerbario } from '../lib/fuentesHerbario.js'

cargarFuentesHerbario()

const route = useRoute()
const yr = new Date().getFullYear()
const diasPrueba = ref(30)


const enCasa = [
  'Tus espacios, tus lotes y cada planta, desde la semilla',
  'Riegos y nutrientes, con la dosis que le diste',
  'Fotos por semana, para comparar cómo viene',
  'Los próximos pasos del ciclo, con aviso al teléfono',
  'Cosecha, frascos y cuánto te costó cada gramo',
]
const enOrganizacion = [
  'Pacientes, REPROCANN y cuenta corriente',
  'Mostrador con caja y cierre, y delivery',
  'Trazabilidad de cada planta con su QR',
  'Los informes que pide la normativa, de la misma data',
  'Una pantalla por oficio: cultivo, manicura, mostrador',
]
const principios = [
  { t: 'Se anota una vez', d: 'Lo que registrás regando es lo que después sale en el informe, en el costo por lote y en la etiqueta del frasco. Nada se carga dos veces.' },
  { t: 'Tus datos son tuyos', d: 'No los vendemos ni los usamos para publicidad, y te los llevás cuando quieras. Sin un ecosistema que te pueda dejar afuera.' },
  { t: 'Va con vos al cultivo', d: 'Pensada para el teléfono, con la mano sucia de tierra: lo de todos los días está a dos toques, y la manicura funciona aun sin señal.' },
]

const telFeed = [
  { i: Droplets, t: 'Riego 1,2 L · pH 6,3', s: 'Hoy, 9:40' },
  { i: Camera,   t: 'Foto · semana 5', s: 'Ayer' },
  { i: BellRing, t: 'Próximo paso: empieza a florecer', s: 'En 5 días' },
]

// Portada ancha (planta de fondo) o angosta (apilada). Se decide por el ancho y se re-arma si cambia.
const consultaAncha = typeof window !== 'undefined' ? window.matchMedia('(min-width: 960px)') : null
const ancha = ref(!!consultaAncha?.matches)
const alCambiarAncho = (e) => { ancha.value = e.matches }

// ── Instalar como app (Chrome/Android ofrecen el evento; en iPhone se explica a mano) ──
const instalable = ref(false)
let promptInstalar = null
function alPedirInstalar (e) { e.preventDefault(); promptInstalar = e; instalable.value = true }
async function instalar () {
  if (!promptInstalar) return
  promptInstalar.prompt()
  try { await promptInstalar.userChoice } catch {}
  promptInstalar = null
  instalable.value = false
}

// ── Aparecer al hacer scroll (sutil; nada si «reducir movimiento») ──
let revelador = null

// ── Contacto ───────────────────────────────────────────────
const TIPOS = [
  { id: 'organizacion', label: 'Organización' },
  { id: 'personal',     label: 'Uso personal' },
  { id: 'baja',         label: 'Arrepentimiento / baja' },
]
const tipo = ref(TIPOS.some(t => t.id === route.query.tipo) ? route.query.tipo : 'organizacion')
const form = reactive({ nombre: '', email: '', organizacion: '', telefono: '', mensaje: '', sitio: '' })
const enviando = ref(false)
const errorContacto = ref(null)
const enviado = ref(null)

async function enviar () {
  errorContacto.value = null
  enviando.value = true
  try {
    const { data } = await enviarContacto({ ...form, tipo: tipo.value, organizacion: tipo.value === 'organizacion' ? form.organizacion : '' })
    enviado.value = { nombre: form.nombre.split(' ')[0], email: form.email, tipo: tipo.value, codigo: data?.codigo }
  } catch (e) {
    errorContacto.value = e?.response?.status === 429
      ? 'Llegaron muchos mensajes desde esta conexión. Probá en un rato o escribinos por mail.'
      : (e?.response?.data?.error || 'No se pudo enviar. Revisá tu conexión y probá de nuevo.')
  } finally {
    enviando.value = false
  }
}

onMounted(async () => {
  window.addEventListener('beforeinstallprompt', alPedirInstalar)
  consultaAncha?.addEventListener('change', alCambiarAncho)
  const quieto = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  const elementos = document.querySelectorAll('.hb .hb-rev')
  if (quieto || !('IntersectionObserver' in window)) {
    elementos.forEach(el => el.classList.add('hb-rev--on'))
  } else {
    revelador = new IntersectionObserver((entradas) => entradas.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('hb-rev--on'); revelador.unobserve(e.target) }
    }), { threshold: 0.15 })
    elementos.forEach(el => revelador.observe(el))
  }
  // Desde los Términos se llega con `#contacto` (y `?tipo=baja`): el router no hace scroll solo.
  if (route.hash) { await nextTick(); document.querySelector(route.hash)?.scrollIntoView() }
  try { diasPrueba.value = (await getRegistroInfo()).data.dias_prueba } catch {}
})
onBeforeUnmount(() => {
  window.removeEventListener('beforeinstallprompt', alPedirInstalar)
  consultaAncha?.removeEventListener('change', alCambiarAncho)
  revelador?.disconnect()
})
</script>

<style scoped>
/* La paleta de la dirección «Herbario», una sola vez: el resto de la página usa estos nombres. */
.hb {
  /* Verdes suaves (Germán, 4-oct: «volver al verde, más delicados»): fondo menta muy claro,
     tinta verde bosque, acentos salvia y menta. El ámbar queda sólo para detalles (pistilos). */
  --hb-papel: #EEF5EF;
  --hb-papel-claro: #F8FBF7;
  --hb-tinta: #15301F;
  --hb-tinta-2: #4E6858;
  --hb-regla: #CDE0D2;
  --hb-verde: #2E6B4A;
  --hb-verde-osc: #1F5137;
  --hb-bosque: #173A2A;
  --hb-salvia: #BCD8C3;
  --hb-salvia-suave: #DCEDE1;
  --hb-menta: #9FD1B0;
  --hb-ambar: #B98532;
  --hb-tierra: #8A6E55;
  --hb-error: #9B2C1E;
  --hb-serif: 'Fraunces', Georgia, serif;
  --hb-sans: 'Public Sans', system-ui, sans-serif;
  --hb-mono: 'JetBrains Mono', ui-monospace, monospace;

  /* Por encima del patrón de fondo del login (`.route-login body::before`, en theme.css). */
  position: relative; z-index: 0;
  min-height: 100vh;
  background: var(--hb-papel);
  color: var(--hb-tinta);
  font: 16px/1.6 var(--hb-sans);
  overflow-x: hidden;
}
.hb *, .hb *::before, .hb *::after { box-sizing: border-box; }
.hb__wrap { width: 100%; max-width: var(--hb-ancho); margin: 0 auto; padding: 0 var(--hb-relleno); }
/* UN solo ancho para todas las secciones (Germán: parejo, homogéneo). La planta de la portada se
   alinea con el borde derecho de este mismo ancho (`--hb-borde`). */
.hb { --hb-ancho: 1320px; --hb-relleno: 16px; --hb-borde: max(var(--hb-relleno), calc((100% - var(--hb-ancho)) / 2 + var(--hb-relleno))); }
@media (min-width: 720px) { .hb { --hb-relleno: 40px; } }

/* ── Tipografía ── */
.hb__ceja { margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.hb__h1 {
  margin: 0; font-family: var(--hb-serif); font-weight: 600; letter-spacing: -.02em;
  font-size: clamp(2.3rem, 5.6vw, 4.2rem); line-height: 1.04; text-wrap: balance;
  font-variation-settings: 'opsz' 144;
}
.hb__h1 em { font-style: italic; font-weight: 400; color: var(--hb-verde); }
.hb__h2 { margin: 0; font-family: var(--hb-serif); font-weight: 600; font-size: clamp(1.7rem, 3.6vw, 2.5rem); line-height: 1.1; letter-spacing: -.015em; text-wrap: balance; }
.hb__h3 { margin: 0; font-family: var(--hb-serif); font-weight: 600; font-size: 1.45rem; line-height: 1.2; }

/* ── Botones ── */
.hb__btn {
  display: inline-flex; align-items: center; justify-content: center; gap: .5rem;
  min-height: 48px; padding: .8rem 1.35rem; border-radius: 999px;
  background: var(--hb-verde); color: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde);
  font: 600 15px var(--hb-sans); text-decoration: none; cursor: pointer;
  transition: background .2s, transform .2s;
}
.hb__btn:hover { background: var(--hb-verde-osc); transform: translateY(-1px); }
.hb__btn:disabled { opacity: .5; cursor: not-allowed; transform: none; }
.hb__btn--linea { background: transparent; color: var(--hb-verde); }
.hb__btn--linea:hover { background: var(--hb-salvia-suave); }
.hb__btn--chico { min-height: 38px; padding: .45rem 1rem; font-size: 14px; }
.hb a:focus-visible, .hb button:focus-visible, .hb input:focus-visible, .hb textarea:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 2px; }

/* ── Encabezado ── */
.hb__top { position: sticky; top: 0; z-index: 20; background: color-mix(in srgb, var(--hb-papel) 88%, transparent); backdrop-filter: blur(8px); border-bottom: 1px solid var(--hb-regla); }
.hb__top-in { display: flex; align-items: center; gap: 18px; height: 64px; }
.hb__marca { color: var(--hb-tinta); text-decoration: none; font: 600 19px var(--hb-serif); letter-spacing: -.01em; white-space: nowrap; }
.hb__nav { display: flex; gap: 22px; margin-left: auto; }
.hb__nav a { color: var(--hb-tinta-2); text-decoration: none; font-size: 15px; }
.hb__nav a:hover { color: var(--hb-tinta); }
.hb__ingresar { display: inline-flex; align-items: center; min-height: 38px; color: var(--hb-tinta); text-decoration: none; font-weight: 600; font-size: 15px; }
@media (max-width: 760px) {
  .hb__nav { display: none; }
  .hb__ingresar { margin-left: auto; }
  .hb__top-in { gap: 12px; }
  .hb__marca { font-size: 17px; }
}

/* ── Portada ── */
.hb__portada {
  position: relative; overflow: hidden;
  padding: clamp(32px, 6vw, 72px) 0 8px;
  background:
    radial-gradient(60% 70% at 80% 30%, color-mix(in srgb, var(--hb-menta) 32%, transparent) 0%, transparent 70%),
    radial-gradient(50% 60% at 0% 100%, color-mix(in srgb, var(--hb-salvia) 38%, transparent) 0%, transparent 70%);
}
/* Ancha: ocupa la pantalla y la planta es el fondo; el texto, encima y a la izquierda. */
.hb__portada--ancha { min-height: max(660px, calc(100svh - 64px)); display: flex; align-items: center; padding: 0; }
.hb__portada--ancha .hb__portada-in { position: relative; z-index: 2; pointer-events: none; padding-bottom: 90px; }
.hb__portada--ancha .hb__portada-txt { pointer-events: auto; max-width: 540px; }
.hb__portada-txt { min-width: 0; }
.hb__bajada { margin: 22px 0 0; max-width: 34em; font-size: 1.12rem; color: var(--hb-tinta-2); }
.hb__acciones { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 30px; }
.hb__nota { margin: 14px 0 0; font: 13px var(--hb-mono); color: var(--hb-tinta-2); }
/* Angosta: la planta debajo del texto, sin recuadro. */
.hb__lamina { max-width: 480px; margin: 18px auto 0; padding: 0 16px 24px; }

/* ── Secciones ── */
.hb__sec { padding: clamp(56px, 8vw, 104px) 0; }
.hb__sec--claro { background: var(--hb-papel-claro); border-block: 1px solid var(--hb-regla); }
.hb__sec-h { margin-bottom: clamp(28px, 4vw, 44px); }

/* ── Fichas (dos puertas) ── */
.hb__fichas { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 330px), 1fr)); gap: 24px; }
.hb__ficha { position: relative; display: flex; flex-direction: column; gap: 14px; padding: 26px 24px 24px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); scroll-margin-top: 84px; }
.hb__ficha--casa { border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia); }
.hb__ficha-cab { display: flex; justify-content: space-between; gap: 12px; font: 500 12px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-tinta-2); border-bottom: 1px dashed var(--hb-regla); padding-bottom: 10px; }
.hb__ficha--casa .hb__ficha-tipo { color: var(--hb-verde); }
.hb__ficha-n { color: var(--hb-tinta); }
.hb__ficha-d { margin: 0; color: var(--hb-tinta-2); }
.hb__lista { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; flex: 1; }
.hb__lista li { position: relative; padding-left: 26px; }
.hb__lista li::before {
  content: ''; position: absolute; left: 2px; top: .45em; width: 12px; height: 12px;
  background: var(--hb-verde);
  -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M1 11C1 5 5 1 11 1c0 6-4 10-10 10z'/%3E%3C/svg%3E") center / contain no-repeat;
          mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M1 11C1 5 5 1 11 1c0 6-4 10-10 10z'/%3E%3C/svg%3E") center / contain no-repeat;
}
.hb__ficha-pie { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 14px; border-top: 1px solid var(--hb-regla); padding-top: 16px; }
.hb__ficha-pie p { margin: 0; font-size: 14px; color: var(--hb-tinta-2); flex: 1 1 200px; }
.hb__ficha-pie strong { color: var(--hb-tinta); }

/* ── Aparecer al hacer scroll ── */
.hb-rev { opacity: 0; transform: translateY(18px); transition: opacity .7s ease, transform .7s cubic-bezier(.2,.7,.2,1); }
.hb-rev--on { opacity: 1; transform: none; }
.hb__ficha { transition: opacity .7s ease, transform .7s cubic-bezier(.2,.7,.2,1), box-shadow .25s; }
.hb__ficha.hb-rev--on:hover { transform: translateY(-3px); }

/* ── En el bolsillo ── */
.hb__bolsillo { background: var(--hb-bosque); color: var(--hb-papel-claro); padding: clamp(56px, 8vw, 100px) 0; overflow: hidden; }
.hb__bolsillo-in { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, .8fr); gap: clamp(32px, 6vw, 80px); align-items: center; }
.hb__bolsillo-txt > p:not(.hb__ceja):not(.hb__instalar-ayuda) { margin: 16px 0 0; color: color-mix(in srgb, var(--hb-papel-claro) 78%, transparent); max-width: 32em; }
.hb__ceja--claro { color: var(--hb-menta); }
.hb__pasos { list-style: none; margin: 22px 0 0; padding: 0; display: grid; gap: 10px; }
.hb__pasos li { display: flex; align-items: center; gap: 12px; }
.hb__pasos span { width: 28px; height: 28px; border-radius: 50%; display: grid; place-items: center; border: 1px solid var(--hb-menta); color: var(--hb-menta); font: 500 13px var(--hb-mono); flex-shrink: 0; }
.hb__btn--claro { background: var(--hb-menta); border-color: var(--hb-menta); color: var(--hb-bosque); }
.hb__btn--claro:hover { background: var(--hb-papel-claro); }
.hb__btn--linea-claro { background: transparent; border-color: color-mix(in srgb, var(--hb-papel-claro) 50%, transparent); color: var(--hb-papel-claro); }
.hb__btn--linea-claro:hover { background: rgb(255 255 255 / .08); }
.hb__instalar-ayuda { margin: 16px 0 0; font-size: 13px; color: color-mix(in srgb, var(--hb-papel-claro) 60%, transparent); }
.hb__instalar-ayuda b { color: var(--hb-papel-claro); font-weight: 600; }
@media (max-width: 860px) { .hb__bolsillo-in { grid-template-columns: minmax(0, 1fr); } }

.hb__tel {
  justify-self: center; width: min(300px, 100%); aspect-ratio: 9 / 18.5; padding: 10px;
  border-radius: 44px; background: #0c1a12; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .6), inset 0 0 0 2px rgb(255 255 255 / .08);
  transform: rotate(-3deg);
}
.hb__tel.hb-rev--on { transform: rotate(-3deg); }
.hb__tel-pantalla { height: 100%; border-radius: 34px; overflow: hidden; background: var(--hb-papel-claro); color: var(--hb-tinta); display: flex; flex-direction: column; font-family: var(--hb-sans); }
.hb__tel-hero { background: linear-gradient(160deg, #1F4A33, #2E6B4A); color: #fff; padding: 34px 16px 16px; border-radius: 0 0 22px 22px; display: flex; flex-direction: column; gap: 3px; }
.hb__tel-fase { font: 600 10px var(--hb-mono); letter-spacing: .08em; opacity: .9; }
.hb__tel-fase i { font-style: normal; background: rgb(255 255 255 / .18); border-radius: 99px; padding: 1px 6px; margin-left: 4px; }
.hb__tel-cod { font: 700 24px var(--hb-sans); letter-spacing: -.01em; }
.hb__tel-gen { font-size: 12px; opacity: .8; }
.hb__tel-falta { margin-top: 6px; font-size: 11px; background: rgb(255 255 255 / .12); border-radius: 99px; padding: 4px 10px; align-self: flex-start; }
.hb__tel-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 5px; margin-top: 10px; }
.hb__tel-stats div { background: rgb(255 255 255 / .1); border-radius: 10px; padding: 6px 2px; text-align: center; display: flex; flex-direction: column; }
.hb__tel-stats b { font-size: 13px; }
.hb__tel-stats small { font-size: 9px; opacity: .75; }
.hb__tel-cta { margin: 12px 12px 0; background: var(--hb-bosque); color: #fff; border-radius: 14px; padding: 10px 12px; font: 600 13px var(--hb-sans); display: flex; flex-direction: column; }
.hb__tel-cta small { font-weight: 400; font-size: 10.5px; opacity: .75; }
.hb__tel-feed { padding: 10px 12px; display: grid; gap: 8px; }
.hb__tel-item { display: flex; gap: 9px; align-items: center; background: #fff; border: 1px solid var(--hb-regla); border-radius: 12px; padding: 8px 10px; font-size: 12px; }
.hb__tel-item > span { width: 28px; height: 28px; flex-shrink: 0; display: grid; place-items: center; border-radius: 8px; background: var(--hb-salvia-suave); color: var(--hb-verde); }
.hb__tel-item div { display: flex; flex-direction: column; }
.hb__tel-item small { color: var(--hb-tinta-2); font-size: 10.5px; }
.hb__tel-nav { margin-top: auto; display: flex; align-items: center; justify-content: space-around; padding: 10px 8px 14px; border-top: 1px solid var(--hb-regla); font-size: 10.5px; color: var(--hb-tinta-2); }
.hb__tel-nav--on { color: var(--hb-verde); font-weight: 700; }
.hb__tel-nav b { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; background: var(--hb-verde); color: #fff; font-size: 20px; font-weight: 400; margin-top: -18px; box-shadow: 0 6px 14px -6px rgb(46 107 74 / .8); }

/* ── Principios ── */
.hb__principios { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 0; border-top: 1px solid var(--hb-tinta); }
.hb__principio { padding: 22px 22px 8px 0; display: flex; flex-direction: column; gap: 10px; }
.hb__principio + .hb__principio { padding-left: 22px; border-left: 1px solid var(--hb-regla); }
.hb__principio p { margin: 0; color: var(--hb-tinta-2); }
.hb__principio-n { font: 500 36px var(--hb-serif); color: var(--hb-ambar); line-height: 1; }
@media (max-width: 860px) {
  .hb__principio, .hb__principio + .hb__principio { padding: 20px 0; border-left: none; border-bottom: 1px solid var(--hb-regla); }
}

/* ── Contacto ── */
.hb__contacto { display: grid; grid-template-columns: minmax(0, .8fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px); align-items: start; scroll-margin-top: 84px; }
.hb__contacto-txt p:not(.hb__ceja) { color: var(--hb-tinta-2); margin: 16px 0 0; }
.hb__aviso { border-left: 3px solid var(--hb-ambar); padding-left: 12px; }
@media (max-width: 860px) { .hb__contacto { grid-template-columns: minmax(0, 1fr); } }
.hb__hoja {
  display: flex; flex-direction: column; gap: 14px; padding: 24px;
  background: var(--hb-papel-claro); border: 1px solid var(--hb-regla);
}
.hb__hoja p { margin: 0; }
.hb__codigo { font: 14px var(--hb-mono); }
.hb__tipos { display: flex; flex-wrap: wrap; gap: 8px; }
.hb__tipo { min-height: 38px; border: 1px solid var(--hb-regla); background: var(--hb-papel-claro); color: var(--hb-tinta-2); border-radius: 999px; padding: .4rem .95rem; font: 500 14px var(--hb-sans); cursor: pointer; }
.hb__tipo--on { background: var(--hb-tinta); border-color: var(--hb-tinta); color: var(--hb-papel-claro); }
.hb__campo { display: flex; flex-direction: column; gap: 5px; font: 500 12px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.hb__campo em { font-style: normal; text-transform: none; letter-spacing: 0; opacity: .75; }
.hb__campo input, .hb__campo textarea {
  font: 16px var(--hb-sans); text-transform: none; letter-spacing: 0; color: var(--hb-tinta);
  background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); border-radius: 6px; padding: .7rem .8rem; resize: vertical;
}
.hb__campo input:focus, .hb__campo textarea:focus { border-color: var(--hb-verde); outline: none; box-shadow: 0 0 0 3px var(--hb-salvia-suave); }
.hb__trampa { position: absolute; left: -10000px; width: 1px; height: 1px; opacity: 0; }
.hb__hoja .hb__btn { align-self: flex-start; }
.hb__error { color: var(--hb-error); font-size: 14px; }
.hb__legal { font-size: 13px; color: var(--hb-tinta-2); }
.hb__legal a { color: var(--hb-verde); }

/* ── Pie ── */
.hb__pie { border-top: 1px solid var(--hb-tinta); padding: 28px 0 36px; }
.hb__pie-in { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 28px; font-size: 14px; color: var(--hb-tinta-2); }
.hb__pie-marca { font: 600 17px var(--hb-serif); color: var(--hb-tinta); }
.hb__pie-nav { display: flex; flex-wrap: wrap; gap: 8px 20px; }
.hb__pie-nav a { color: var(--hb-tinta-2); text-decoration: none; }
.hb__pie-nav a:hover { color: var(--hb-tinta); text-decoration: underline; }
.hb__pie-arrep { color: var(--hb-verde) !important; font-weight: 600; }
.hb__pie-copy { margin-left: auto; font: 13px var(--hb-mono); }
</style>
