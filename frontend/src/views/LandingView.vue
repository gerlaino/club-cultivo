<template>
  <div class="ld">

    <!-- Fondo: mismo cosmos del login, con la paleta del design system -->
    <div class="ld__bg" aria-hidden="true">
      <div class="ld__nebula ld__nebula--1"></div>
      <div class="ld__nebula ld__nebula--2"></div>
      <div class="ld__nebula ld__nebula--3"></div>
      <span class="ld__star" style="top:6%;left:11%;width:2px;height:2px;animation-duration:3s"></span>
      <span class="ld__star" style="top:13%;left:34%;width:1.5px;height:1.5px;animation-duration:4s;animation-delay:-1s"></span>
      <span class="ld__star" style="top:4%;left:57%;width:2px;height:2px;animation-duration:2.5s;animation-delay:-.5s"></span>
      <span class="ld__star" style="top:20%;left:74%;width:1px;height:1px;animation-duration:3.5s;animation-delay:-2s"></span>
      <span class="ld__star" style="top:9%;left:88%;width:2px;height:2px;animation-duration:3.8s;animation-delay:-1.2s"></span>
      <svg class="ld__chala ld__chala--a" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(90,138,114,.10)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(90,138,114,.08)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(90,138,114,.08)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(90,138,114,.06)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(90,138,114,.06)"/>
        <path d="M50 92L50 155" stroke="rgba(90,138,114,.09)" stroke-width="2.5" stroke-linecap="round"/>
      </svg>
      <svg class="ld__chala ld__chala--b" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(168,201,181,.06)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(168,201,181,.05)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(168,201,181,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(168,201,181,.06)" stroke-width="2" stroke-linecap="round"/>
      </svg>
    </div>

    <!-- ── Header ───────────────────────────────────────────── -->
    <header class="ld__header">
      <div class="ld__wrap ld__header-in">
        <RouterLink to="/bienvenida" class="ld__brand">
          <img src="/logo-ce-redondo.png" alt="" class="ld__brand-img" />
          <span class="ld__brand-txt">Cultivo Espacial</span>
        </RouterLink>
        <nav class="ld__nav">
          <a href="#capacidades" class="ld__nav-a">Qué hace</a>
          <a href="#quienes"     class="ld__nav-a">Para quién</a>
          <a href="#modulos"     class="ld__nav-a">Módulos</a>
        </nav>
        <RouterLink to="/login" class="ld__login">Ingresar</RouterLink>
      </div>
    </header>

    <!-- ── Hero ─────────────────────────────────────────────── -->
    <section class="ld__hero">
      <div class="ld__wrap ld__hero-in">
        <span class="ld__badge"><span class="ld__bdot"></span>De la genética a la entrega</span>

        <h1 class="ld__h1">
          Todo lo que cultivás,<br /><em>bajo control</em>
        </h1>

        <p class="ld__lead">
          Una plataforma para toda organización que cultiva: clubes, investigación y producción.
          Cada planta, cada ciclo y cada gramo, registrados y demostrables.
        </p>

        <div class="ld__cta">
          <RouterLink to="/login" class="ld__btn ld__btn--primary">
            Ingresar
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
            </svg>
          </RouterLink>
          <a href="#capacidades" class="ld__btn ld__btn--ghost">Ver qué hace</a>
        </div>

        <!-- Los tres pilares -->
        <div class="ld__pilares">
          <div class="ld__pilar">
            <span class="ld__pilar-t">Cultivo</span>
            <span class="ld__pilar-d">Genéticas, lotes, plantas y ambiente</span>
          </div>
          <span class="ld__psep" aria-hidden="true"></span>
          <div class="ld__pilar">
            <span class="ld__pilar-t">Producción</span>
            <span class="ld__pilar-d">Cosecha, post-cosecha, stock y entrega</span>
          </div>
          <span class="ld__psep" aria-hidden="true"></span>
          <div class="ld__pilar">
            <span class="ld__pilar-t">Cumplimiento</span>
            <span class="ld__pilar-d">Informes que salen de la misma data</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ── La cadena ────────────────────────────────────────── -->
    <section class="ld__sec" id="capacidades">
      <div class="ld__wrap">
        <span class="ld__kicker">La cadena</span>
        <h2 class="ld__h2">Una sola línea de tiempo, de la madre a quien la recibe</h2>
        <p class="ld__sub">
          No son módulos sueltos que después hay que conciliar. Cada eslabón hereda la trazabilidad
          del anterior, así que preguntarle al sistema de dónde salió un gramo es una consulta, no una
          investigación.
        </p>

        <ol class="ld__chain">
          <li v-for="(p, i) in cadena" :key="p.t" class="ld__link">
            <span class="ld__link-n">{{ String(i + 1).padStart(2, '0') }}</span>
            <span class="ld__link-t">{{ p.t }}</span>
            <span class="ld__link-d">{{ p.d }}</span>
          </li>
        </ol>
      </div>
    </section>

    <!-- ── Capacidades ──────────────────────────────────────── -->
    <section class="ld__sec ld__sec--alt">
      <div class="ld__wrap">
        <div class="ld__feats">
          <article class="ld__feat">
            <div class="ld__feat-ico">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" />
                <rect x="3" y="14" width="7" height="7" rx="1" /><path d="M14 17.5h7M17.5 14v7" />
              </svg>
            </div>
            <h3 class="ld__feat-t">Trazabilidad de punta a punta</h3>
            <p class="ld__feat-d">
              Cada planta con su QR, desde la madre o la semilla hasta quien la recibe. Escaneás una
              etiqueta y tenés el expediente completo: origen, sala, riegos, pesadas y destino.
            </p>
          </article>

          <article class="ld__feat">
            <div class="ld__feat-ico">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M3 3v18h18" /><path d="M7 15l4-5 3 3 5-7" />
              </svg>
            </div>
            <h3 class="ld__feat-t">El ciclo, medido</h3>
            <p class="ld__feat-d">
              Ambiente, riego, fases y rendimiento por lote y por genética. Sensores, setpoints por
              fase y alertas — para comparar corridas y saber qué cambió entre una y otra.
            </p>
          </article>

          <article class="ld__feat">
            <div class="ld__feat-ico">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><path d="M14 2v6h6" />
                <path d="M9 15l2 2 4-4" />
              </svg>
            </div>
            <h3 class="ld__feat-t">Cumplimiento cuando hace falta</h3>
            <p class="ld__feat-d">
              REPROCANN y ARICCAME salen de la misma data que ya cargaste operando, sin cargar nada
              dos veces. El informe es una salida del sistema, no un trabajo aparte.
            </p>
          </article>

          <article class="ld__feat">
            <div class="ld__feat-ico">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" /><circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
              </svg>
            </div>
            <h3 class="ld__feat-t">Una vista por cada oficio</h3>
            <p class="ld__feat-d">
              Quien cultiva, quien manicura, quien dispensa, quien reparte y quien audita ven cosas
              distintas. Once roles, cada uno con su pantalla y sus permisos.
            </p>
          </article>
        </div>
      </div>
    </section>

    <!-- ── Para quién ───────────────────────────────────────── -->
    <section class="ld__sec" id="quienes">
      <div class="ld__wrap">
        <span class="ld__kicker">Para quién</span>
        <h2 class="ld__h2">Si lo que cultivás hay que poder demostrarlo</h2>
        <p class="ld__sub">
          Un club, un laboratorio y un productor no comparten normativa, pero comparten el problema:
          saber qué pasó con cada planta y poder mostrarlo ante quien pregunte.
        </p>

        <div class="ld__whos">
          <article v-for="w in publicos" :key="w.t" class="ld__who">
            <h3 class="ld__who-t">{{ w.t }}</h3>
            <p class="ld__who-d">{{ w.d }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- ── Módulos ──────────────────────────────────────────── -->
    <section class="ld__sec ld__sec--alt" id="modulos">
      <div class="ld__wrap">
        <span class="ld__kicker">Módulos</span>
        <h2 class="ld__h2">Lo que ya viene resuelto</h2>
        <div class="ld__mods">
          <span v-for="m in modulos" :key="m" class="ld__mod">{{ m }}</span>
        </div>
      </div>
    </section>

    <!-- ── Cierre ───────────────────────────────────────────── -->
    <section class="ld__sec ld__final">
      <div class="ld__wrap ld__final-in">
        <h2 class="ld__h2 ld__h2--center">Cada planta tiene su historia</h2>
        <p class="ld__sub ld__sub--center">Guardarla no debería costarte una planilla.</p>
        <RouterLink to="/login" class="ld__btn ld__btn--primary ld__btn--lg">
          Ingresar a la plataforma
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
          </svg>
        </RouterLink>
      </div>
    </section>

    <footer class="ld__footer">
      <div class="ld__wrap ld__footer-in">
        <span>© {{ yr }} Cultivo Espacial</span>
        <span class="ld__footer-sep" aria-hidden="true">·</span>
        <span>Trazabilidad de cultivo y producción</span>
      </div>
    </footer>

  </div>
</template>

<script setup>
const yr = new Date().getFullYear()

const cadena = [
  { t: 'Genética',   d: 'Cepa, origen y perfil. Todo lo que se siembra arranca acá.' },
  { t: 'Lote',       d: 'Plantas de la misma cepa en el mismo ciclo, con sus fases y su sala.' },
  { t: 'Planta',     d: 'Etiqueta QR propia, actividades, riegos, fotos y su historia completa.' },
  { t: 'Cosecha',    d: 'Pesadas, secado y curado, con el peso que entra y el que sale.' },
  { t: 'Stock',      d: 'Por sede y por depósito, con movimientos y aprobaciones.' },
  { t: 'Entrega',    d: 'Dispensación o delivery, con comprobante y firma.' },
]

const publicos = [
  {
    t: 'Clubes',
    d: 'Socios y pacientes, cuenta corriente, dispensaciones, reservas, delivery, turnos médicos y los informes que pide la normativa argentina.',
  },
  {
    t: 'Investigación',
    d: 'Ensayos comparables: fenotipado por genética, condiciones de ambiente registradas, análisis de laboratorio y rendimiento por corrida.',
  },
  {
    t: 'Producción',
    d: 'Costo por lote, rendimiento real, pérdidas, stock multi-sede y contabilidad — para saber qué produce cada metro cuadrado.',
  },
]

const modulos = [
  'Genéticas', 'Lotes y plantas', 'Salas y sedes', 'Ambiente e IoT', 'Plan de trabajo',
  'Tareas', 'Post-cosecha', 'Stock multi-sede', 'Dispensaciones', 'Reservas', 'Delivery',
  'Turnos médicos', 'Análisis de laboratorio', 'Contabilidad', 'Costo por lote', 'Analítica',
  'Informes de cumplimiento', 'Etiquetas QR', 'Audit log', 'App móvil',
]
</script>

<style scoped>
*, *::before, *::after { box-sizing: border-box; }

.ld {
  position: relative;
  min-height: 100vh;
  background: var(--c-leaf-900, #0F2A1E);
  color: #fff;
  font-family: var(--font-ui, 'Inter', system-ui, sans-serif);
  overflow-x: hidden;
}

/* ── Fondo ─────────────────────────────────────────────── */
.ld__bg {
  position: fixed; inset: 0; pointer-events: none; overflow: hidden; z-index: 0;
  background:
    radial-gradient(ellipse 70% 60% at 50% 0%, rgba(45, 74, 62, .55) 0%, transparent 60%),
    radial-gradient(ellipse 80% 50% at 80% 30%, rgba(26, 61, 46, .5) 0%, transparent 55%),
    linear-gradient(180deg, #0F2A1E 0%, #0B1F16 55%, #0F2A1E 100%);
}
.ld__nebula { position: absolute; border-radius: 50%; filter: blur(90px); animation: ld-neb linear infinite; }
.ld__nebula--1 { width: 520px; height: 520px; background: rgba(45,74,62,.35);  top: -120px; right: 4%;  animation-duration: 26s; }
.ld__nebula--2 { width: 420px; height: 420px; background: rgba(90,138,114,.14); top: 45%;   left: -80px; animation-duration: 32s; animation-delay: -9s; }
.ld__nebula--3 { width: 360px; height: 360px; background: rgba(26,61,46,.45);   bottom: 5%;  right: 18%; animation-duration: 22s; animation-delay: -5s; }
@keyframes ld-neb { 0%,100% { transform: translateY(0) scale(1); } 50% { transform: translateY(-22px) scale(1.05); } }

.ld__star { position: absolute; border-radius: 50%; background: #fff; opacity: .5; animation: ld-twinkle ease-in-out infinite; }
@keyframes ld-twinkle { 0%,100% { opacity: .6; transform: scale(1); } 50% { opacity: .1; transform: scale(.6); } }

.ld__chala { position: absolute; pointer-events: none; animation: ld-sway ease-in-out infinite; transform-origin: 50% 99%; }
.ld__chala--a { width: 210px; height: 336px; right: 2%; top: 4%;  animation-duration: 11s; }
.ld__chala--b { width: 150px; height: 240px; left: 3%;  top: 22%; animation-duration: 15s; animation-delay: -6s; }
@keyframes ld-sway {
  0%   { transform: rotate(-4deg); }
  50%  { transform: rotate(-1deg) translateY(4px); }
  100% { transform: rotate(-4deg); }
}
@media (prefers-reduced-motion: reduce) {
  .ld__nebula, .ld__star, .ld__chala { animation: none; }
}

/* ── Estructura ────────────────────────────────────────── */
.ld__wrap { width: 100%; max-width: 1080px; margin: 0 auto; padding: 0 var(--sp-6, 24px); }
.ld__sec  { position: relative; z-index: 1; padding: clamp(56px, 8vw, 104px) 0; }
.ld__sec--alt { background: rgba(0, 0, 0, .18); border-block: 1px solid rgba(255,255,255,.05); }

/* ── Header ────────────────────────────────────────────── */
.ld__header {
  position: sticky; top: 0; z-index: 20;
  background: rgba(15, 42, 30, .72);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(255,255,255,.06);
}
.ld__header-in { display: flex; align-items: center; gap: var(--sp-6, 24px); height: 62px; }
.ld__brand { display: flex; align-items: center; gap: var(--sp-2, 8px); text-decoration: none; color: #fff; }
.ld__brand-img { width: 32px; height: 32px; border-radius: 50%; object-fit: cover; }
.ld__brand-txt { font-family: var(--font-display, 'General Sans', sans-serif); font-weight: 700; font-size: var(--fs-16, 16px); letter-spacing: -.01em; }
.ld__nav { display: flex; gap: var(--sp-5, 20px); margin-left: auto; }
.ld__nav-a { color: rgba(255,255,255,.6); text-decoration: none; font-size: var(--fs-14, 14px); font-weight: 500; transition: color var(--t-base, .2s); }
.ld__nav-a:hover { color: #fff; }
.ld__login {
  padding: .5rem 1.05rem; border-radius: var(--r-pill, 9999px);
  border: 1px solid rgba(168,201,181,.3); color: var(--c-leaf-300, #A8C9B5);
  font-size: var(--fs-13, 13px); font-weight: 600; text-decoration: none;
  transition: all var(--t-base, .2s); white-space: nowrap;
}
.ld__login:hover { background: rgba(168,201,181,.12); border-color: rgba(168,201,181,.55); color: #fff; }
@media (max-width: 720px) { .ld__nav { display: none; } .ld__login { margin-left: auto; } }

/* ── Hero ──────────────────────────────────────────────── */
.ld__hero { position: relative; z-index: 1; padding: clamp(56px, 10vw, 120px) 0 clamp(40px, 6vw, 72px); }
.ld__hero-in { display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-5, 20px); }

.ld__badge {
  display: inline-flex; align-items: center; gap: .45rem;
  border: 1px solid rgba(168,201,181,.28); background: rgba(168,201,181,.08);
  color: var(--c-leaf-300, #A8C9B5);
  font-size: var(--fs-12, 12px); font-weight: 700;
  padding: .38em .95em; border-radius: var(--r-pill, 9999px);
  text-transform: uppercase; letter-spacing: .08em;
}
.ld__bdot { width: 6px; height: 6px; border-radius: 50%; background: var(--c-leaf-500, #5A8A72); animation: ld-pulse 2s ease infinite; }
@keyframes ld-pulse { 0%,100% { opacity: 1; transform: scale(1); } 50% { opacity: .35; transform: scale(.7); } }

.ld__h1 {
  font-family: var(--font-display, 'General Sans', sans-serif);
  font-size: clamp(2.4rem, 6.5vw, 4.1rem);
  font-weight: 800; line-height: 1.04; letter-spacing: -.045em; margin: 0;
}
.ld__h1 em {
  font-style: normal;
  background: linear-gradient(135deg, var(--c-leaf-300, #A8C9B5) 0%, var(--c-leaf-500, #5A8A72) 85%);
  -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent;
}
.ld__lead { max-width: 46ch; font-size: clamp(.95rem, 1.6vw, 1.1rem); line-height: var(--lh-loose, 1.7); color: rgba(255,255,255,.62); margin: 0; }

.ld__cta { display: flex; flex-wrap: wrap; gap: var(--sp-3, 12px); margin-top: var(--sp-2, 8px); }
.ld__btn {
  display: inline-flex; align-items: center; justify-content: center; gap: .45rem;
  padding: .8rem 1.4rem; border-radius: var(--r-xl, 12px);
  font-size: var(--fs-14, 14px); font-weight: 700; text-decoration: none;
  transition: all var(--t-base, .2s); border: 1px solid transparent;
}
.ld__btn--primary {
  background: linear-gradient(135deg, var(--c-leaf-500, #5A8A72) 0%, var(--c-leaf-600, #3F6452) 100%);
  color: #fff; box-shadow: 0 6px 20px rgba(15,42,30,.5);
}
.ld__btn--primary:hover { transform: translateY(-2px); box-shadow: 0 10px 26px rgba(15,42,30,.62); }
.ld__btn--ghost { color: rgba(255,255,255,.72); border-color: rgba(255,255,255,.14); }
.ld__btn--ghost:hover { background: rgba(255,255,255,.06); color: #fff; }
.ld__btn--lg { padding: .95rem 1.8rem; font-size: var(--fs-16, 16px); }

.ld__pilares {
  display: flex; align-items: stretch; gap: var(--sp-4, 16px);
  margin-top: var(--sp-8, 32px); width: 100%;
  background: rgba(255,255,255,.035); border: 1px solid rgba(255,255,255,.07);
  border-radius: var(--r-xl, 12px); padding: var(--sp-5, 20px) var(--sp-6, 24px);
}
.ld__pilar { flex: 1; display: flex; flex-direction: column; gap: .2rem; }
.ld__pilar-t { font-family: var(--font-display, sans-serif); font-size: var(--fs-16, 16px); font-weight: 700; color: var(--c-leaf-300, #A8C9B5); }
.ld__pilar-d { font-size: var(--fs-13, 13px); color: rgba(255,255,255,.42); line-height: var(--lh-base, 1.5); }
.ld__psep { width: 1px; background: rgba(255,255,255,.08); flex-shrink: 0; }
@media (max-width: 720px) {
  .ld__pilares { flex-direction: column; gap: var(--sp-4, 16px); }
  .ld__psep { width: 100%; height: 1px; }
}

/* ── Tipografía de sección ─────────────────────────────── */
.ld__kicker {
  display: inline-block; font-size: var(--fs-12, 12px); font-weight: 800;
  text-transform: uppercase; letter-spacing: .12em; color: var(--c-leaf-500, #5A8A72);
  margin-bottom: var(--sp-3, 12px);
}
.ld__h2 {
  font-family: var(--font-display, 'General Sans', sans-serif);
  font-size: clamp(1.5rem, 3.4vw, 2.2rem); font-weight: 700;
  line-height: 1.16; letter-spacing: -.03em; margin: 0 0 var(--sp-4, 16px);
  max-width: 22ch;
}
.ld__h2--center { max-width: none; text-align: center; }
.ld__sub { max-width: 62ch; font-size: var(--fs-16, 16px); line-height: var(--lh-loose, 1.7); color: rgba(255,255,255,.5); margin: 0; }
.ld__sub--center { text-align: center; margin-inline: auto; }

/* ── Cadena ────────────────────────────────────────────── */
.ld__chain {
  list-style: none; margin: var(--sp-10, 40px) 0 0; padding: 0;
  display: grid; grid-template-columns: repeat(auto-fit, minmax(168px, 1fr)); gap: var(--sp-3, 12px);
  counter-reset: none;
}
.ld__link {
  position: relative;
  display: flex; flex-direction: column; gap: .3rem;
  background: rgba(255,255,255,.03); border: 1px solid rgba(255,255,255,.06);
  border-radius: var(--r-lg, 8px); padding: var(--sp-4, 16px);
  transition: all var(--t-base, .2s);
}
.ld__link:hover { background: rgba(90,138,114,.1); border-color: rgba(90,138,114,.28); }
.ld__link-n { font-family: var(--font-mono, monospace); font-size: var(--fs-12, 12px); color: var(--c-leaf-500, #5A8A72); font-weight: 600; }
.ld__link-t { font-family: var(--font-display, sans-serif); font-size: var(--fs-16, 16px); font-weight: 700; color: #fff; }
.ld__link-d { font-size: var(--fs-13, 13px); line-height: var(--lh-base, 1.5); color: rgba(255,255,255,.42); }

/* ── Features ──────────────────────────────────────────── */
.ld__feats { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: var(--sp-5, 20px); }
.ld__feat {
  background: rgba(255,255,255,.035); border: 1px solid rgba(255,255,255,.07);
  border-radius: var(--r-xl, 12px); padding: var(--sp-6, 24px);
  transition: all var(--t-base, .2s);
}
.ld__feat:hover { border-color: rgba(90,138,114,.3); background: rgba(90,138,114,.07); }
.ld__feat-ico {
  width: 40px; height: 40px; border-radius: var(--r-lg, 8px);
  background: rgba(90,138,114,.16); color: var(--c-leaf-300, #A8C9B5);
  display: flex; align-items: center; justify-content: center; margin-bottom: var(--sp-4, 16px);
}
.ld__feat-t { font-family: var(--font-display, sans-serif); font-size: var(--fs-18, 18px); font-weight: 700; margin: 0 0 var(--sp-2, 8px); letter-spacing: -.02em; }
.ld__feat-d { font-size: var(--fs-14, 14px); line-height: var(--lh-loose, 1.7); color: rgba(255,255,255,.48); margin: 0; }

/* ── Para quién ────────────────────────────────────────── */
.ld__whos { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: var(--sp-5, 20px); margin-top: var(--sp-10, 40px); }
.ld__who { border-top: 2px solid rgba(90,138,114,.45); padding-top: var(--sp-4, 16px); }
.ld__who-t { font-family: var(--font-display, sans-serif); font-size: var(--fs-20, 20px); font-weight: 700; margin: 0 0 var(--sp-2, 8px); letter-spacing: -.02em; }
.ld__who-d { font-size: var(--fs-14, 14px); line-height: var(--lh-loose, 1.7); color: rgba(255,255,255,.48); margin: 0; }

/* ── Módulos ───────────────────────────────────────────── */
.ld__mods { display: flex; flex-wrap: wrap; gap: var(--sp-2, 8px); margin-top: var(--sp-6, 24px); }
.ld__mod {
  font-size: var(--fs-13, 13px); font-weight: 500; color: rgba(255,255,255,.62);
  background: rgba(255,255,255,.045); border: 1px solid rgba(255,255,255,.07);
  border-radius: var(--r-pill, 9999px); padding: .45em 1em;
  transition: all var(--t-base, .2s);
}
.ld__mod:hover { color: #fff; border-color: rgba(168,201,181,.35); background: rgba(168,201,181,.1); }

/* ── Cierre ────────────────────────────────────────────── */
.ld__final-in { display: flex; flex-direction: column; align-items: center; gap: var(--sp-5, 20px); text-align: center; }

/* ── Footer ────────────────────────────────────────────── */
.ld__footer { position: relative; z-index: 1; border-top: 1px solid rgba(255,255,255,.06); padding: var(--sp-6, 24px) 0; }
.ld__footer-in { display: flex; flex-wrap: wrap; justify-content: center; gap: var(--sp-2, 8px); font-size: var(--fs-13, 13px); color: rgba(255,255,255,.3); }
.ld__footer-sep { color: rgba(255,255,255,.18); }
</style>
