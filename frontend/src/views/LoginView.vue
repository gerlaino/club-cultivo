<template>
  <div class="lv">

    <!-- Fondo cosmos -->
    <div class="lv__bg" aria-hidden="true">
      <!-- Estrellas pequeñas -->
      <div class="lv__star lv__star--1"></div>
      <div class="lv__star lv__star--2"></div>
      <div class="lv__star lv__star--3"></div>
      <div class="lv__star lv__star--4"></div>
      <div class="lv__star lv__star--5"></div>
      <div class="lv__star lv__star--6"></div>
      <div class="lv__star lv__star--7"></div>
      <div class="lv__star lv__star--8"></div>
      <!-- Nebulosa de fondo -->
      <div class="lv__nebula lv__nebula--1"></div>
      <div class="lv__nebula lv__nebula--2"></div>
      <div class="lv__nebula lv__nebula--3"></div>
      <!-- Chalas / hojas decorativas -->
      <svg class="lv__chala lv__chala--a" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(90,138,114,.10)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(90,138,114,.08)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(90,138,114,.08)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(90,138,114,.06)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(90,138,114,.06)"/>
        <path d="M47 74C37 70 25 73 18 82C24 89 37 90 48 82Z" fill="rgba(90,138,114,.05)"/>
        <path d="M53 74C63 70 75 73 82 82C76 89 63 90 52 82Z" fill="rgba(90,138,114,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(90,138,114,.09)" stroke-width="2.5" stroke-linecap="round"/>
      </svg>
      <svg class="lv__chala lv__chala--b" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(63,100,82,.09)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(63,100,82,.07)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(63,100,82,.07)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(63,100,82,.06)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(63,100,82,.06)"/>
        <path d="M50 92L50 155" stroke="rgba(63,100,82,.08)" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <svg class="lv__chala lv__chala--c" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(168,201,181,.06)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(168,201,181,.05)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(168,201,181,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(168,201,181,.06)" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
      <!-- Chalas lado izquierdo -->
      <svg class="lv__chala lv__chala--d" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(63,100,82,.08)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(63,100,82,.06)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(63,100,82,.06)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(63,100,82,.05)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(63,100,82,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(63,100,82,.07)" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <svg class="lv__chala lv__chala--e" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(90,138,114,.06)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(90,138,114,.05)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(90,138,114,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(90,138,114,.06)" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </div>

    <!-- Una sola columna: el login es una puerta, no un folleto.
         Lo que cuenta qué es la plataforma vive en /bienvenida. -->
    <div class="lv__layout">
      <div class="lv__col-login">
        <div class="lv__card">

          <!-- Logo Cultivo Espacial -->
          <div class="lv__logo">
            <img src="/logo-ce-redondo.png" class="lv__logo-img" alt="Cultivo Espacial" />
            <div class="lv__logo-sub">Cultivo, producción y trazabilidad</div>
          </div>

          <div class="lv__sep"></div>

          <div class="lv__welcome">
            <h2 class="lv__welcome-h">Bienvenido <span class="lv__rocket" aria-hidden="true">🚀</span></h2>
            <p class="lv__welcome-p">Iniciá sesión para continuar</p>
          </div>

          <form @submit.prevent="onSubmit" novalidate class="lv__form">
            <div class="lv__field">
              <label class="lv__label">Email</label>
              <div class="lv__iw" :class="{ 'lv__iw--on': focusEmail }">
                <svg class="lv__ico" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/>
                </svg>
                <input v-model.trim="email" type="email" class="lv__input"
                       placeholder="tu@organizacion.org"
                       autocomplete="username" required :disabled="auth.loading"
                       @focus="focusEmail=true" @blur="focusEmail=false"/>
              </div>
            </div>

            <div class="lv__field">
              <label class="lv__label">Contraseña</label>
              <div class="lv__iw" :class="{ 'lv__iw--on': focusPass }">
                <svg class="lv__ico" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/>
                </svg>
                <input v-model="password" :type="showPass ? 'text' : 'password'"
                       class="lv__input" placeholder="••••••••"
                       autocomplete="current-password" required :disabled="auth.loading"
                       @focus="focusPass=true" @blur="focusPass=false"/>
                <button type="button" class="lv__eye" @click="showPass=!showPass" tabindex="-1">
                  <svg v-if="!showPass" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
                  </svg>
                  <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"/>
                    <line x1="1" y1="1" x2="23" y2="23"/>
                  </svg>
                </button>
              </div>
            </div>

            <Transition name="err">
              <div v-if="auth.error" class="lv__error">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
                </svg>
                {{ auth.error }}
              </div>
            </Transition>

            <button class="lv__btn" type="submit" :disabled="auth.loading || retrying || !email || !password">
              <DsSpinner v-if="auth.loading || retrying" :size="18" />
              <template v-else>
                <span>Ingresar</span>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                  <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>
                </svg>
              </template>
            </button>
          </form>

          <div class="lv__foot">
            <div class="lv__secure"><span class="lv__dot"></span>Conexión cifrada · SSL</div>
            <span class="lv__copy">© {{ yr }}</span>
          </div>

        </div>

        <RouterLink to="/bienvenida" class="lv__back">Conocé la plataforma →</RouterLink>
        <div class="lv__ver">v0.1.0 beta</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import DsSpinner from '../design-system/components/Spinner.vue'

const auth = useAuthStore()
const route = useRoute()
const email      = ref('')
const password   = ref('')
const showPass   = ref(false)
const focusEmail = ref(false)
const focusPass  = ref(false)
const yr = new Date().getFullYear()
const retrying     = ref(false)
const lastSubmitAt = ref(0)
const COOLDOWN_MS  = 600

function esErrorDeConexion(e) {
  const status = e?.response?.status
  return !status || status >= 500
}

async function intentarLogin() {
  await auth.login(email.value, password.value, route.query.redirect || null)
}

async function onSubmit() {
  const now = Date.now()
  if (auth.loading || retrying.value || now - lastSubmitAt.value < COOLDOWN_MS) return
  lastSubmitAt.value = now
  try {
    await intentarLogin()
  } catch (e) {
    if (esErrorDeConexion(e)) {
      auth.error = 'Hubo un problema al conectar. Reintentando…'
      retrying.value = true
      setTimeout(async () => {
        retrying.value = false
        try {
          await intentarLogin()
        } catch (_) {}
      }, 2000)
    }
  }
}
</script>

<style scoped>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

.lv {
  position: fixed; inset: 0;
  font-family: var(--font-ui, 'Inter', system-ui, sans-serif);
  background: var(--c-leaf-900, #0F2A1E);
  overflow: auto;
}

/* Fondo espacio */
.lv__bg {
  position: absolute; inset: 0; pointer-events: none; overflow: hidden;
  background:
    radial-gradient(ellipse 70% 70% at 50% 50%, rgba(45,74,62,.45) 0%, transparent 65%),
    radial-gradient(ellipse 90% 60% at 75% 45%, rgba(26,61,46,.5) 0%, transparent 55%),
    radial-gradient(ellipse 50% 50% at 20% 80%, rgba(15,42,30,.4) 0%, transparent 50%),
    linear-gradient(170deg, #0F2A1E 0%, #0B1F16 45%, #0F2A1E 100%);
}

/* Nebulosas */
.lv__nebula { position: absolute; border-radius: 50%; filter: blur(80px); animation: neb linear infinite; }
.lv__nebula--1 { width: 500px; height: 500px; background: rgba(45,74,62,.3); top: -100px; right: 5%; animation-duration: 25s; }
.lv__nebula--2 { width: 400px; height: 400px; background: rgba(90,138,114,.16); bottom: -80px; right: 20%; animation-duration: 30s; animation-delay: -10s; }
.lv__nebula--3 { width: 350px; height: 350px; background: rgba(26,61,46,.4); top: 30%; left: 5%; animation-duration: 20s; animation-delay: -6s; }
@keyframes neb { 0%,100%{transform:translateY(0) scale(1)} 50%{transform:translateY(-20px) scale(1.04)} }

/* Estrellas */
.lv__star { position: absolute; border-radius: 50%; background: white; animation: twinkle ease-in-out infinite; }
.lv__star--1 { width:2px; height:2px; top:8%;  left:12%; opacity:.6; animation-duration:3s; }
.lv__star--2 { width:1.5px; height:1.5px; top:15%; left:35%; opacity:.4; animation-duration:4s; animation-delay:-1s; }
.lv__star--3 { width:2px; height:2px; top:5%;  left:55%; opacity:.7; animation-duration:2.5s; animation-delay:-0.5s; }
.lv__star--4 { width:1px; height:1px; top:22%; left:72%; opacity:.5; animation-duration:3.5s; animation-delay:-2s; }
.lv__star--5 { width:2px; height:2px; top:70%; left:8%;  opacity:.4; animation-duration:4.5s; animation-delay:-1.5s; }
.lv__star--6 { width:1.5px; height:1.5px; top:80%; left:30%; opacity:.6; animation-duration:3s; animation-delay:-0.8s; }
.lv__star--7 { width:2px; height:2px; top:60%; left:82%; opacity:.5; animation-duration:2.8s; animation-delay:-2.5s; }
.lv__star--8 { width:1px; height:1px; top:40%; left:90%; opacity:.7; animation-duration:3.8s; animation-delay:-1.2s; }
@keyframes twinkle { 0%,100%{opacity:.7;transform:scale(1)} 50%{opacity:.1;transform:scale(0.6)} }

/* Chalas */
.lv__chala { position: absolute; pointer-events: none; animation: sway ease-in-out infinite; transform-origin: 50% 99%; }
.lv__chala--a { width: 190px; height: 304px; right: 1%;  top: 3%;  animation-duration: 9s; }
.lv__chala--b { width: 230px; height: 368px; right: 5%;  top: 50%; animation-duration: 12s; animation-delay: -4s; }
.lv__chala--c { width: 140px; height: 224px; right: 23%; top: 60%; animation-duration: 15s; animation-delay: -7s; }
/* Chalas lado izquierdo y centro */
.lv__chala--d { width: 170px; height: 272px; left: 1%;  top: 10%; animation-duration: 11s; animation-delay: -3s; }
.lv__chala--e { width: 130px; height: 208px; left: 4%;  top: 55%; animation-duration: 14s; animation-delay: -8s; }
@keyframes sway {
  0%  { transform: rotate(-4deg); }
  25% { transform: rotate(2deg) translateY(-5px); }
  50% { transform: rotate(-2deg) translateY(3px); }
  75% { transform: rotate(3deg) translateY(-3px); }
  100%{ transform: rotate(-4deg); }
}
@media (prefers-reduced-motion: reduce) {
  .lv__nebula, .lv__star, .lv__chala { animation: none; }
}

/* Layout: card centrado, en cualquier tamaño de pantalla */
.lv__layout {
  position: relative; z-index: 10;
  display: grid; grid-template-columns: 1fr; justify-items: center; align-items: center;
  min-height: 100vh; padding: var(--sp-6, 24px) var(--sp-5, 20px);
}

/* Col login */
.lv__col-login {
  display: flex; flex-direction: column; align-items: center;
  width: 100%; max-width: 400px;
}

/* Card */
.lv__card {
  width: 100%;
  background: rgba(255,255,255,.97);
  border-radius: 26px; overflow: hidden;
  box-shadow:
    0 0 0 1px rgba(255,255,255,.15),
    0 40px 80px rgba(0,0,0,.7),
    0 0 140px rgba(15,42,30,.35),
    inset 0 1px 0 rgba(255,255,255,.9);
}

.lv__logo {
  display: flex; flex-direction: column; align-items: center; gap: .5rem;
  padding: 1.75rem 1.5rem 1rem;
}
.lv__logo-img {
  width: 96px; height: 96px;
  border-radius: 50%; object-fit: cover;
  filter: drop-shadow(0 4px 16px rgba(15,42,30,.45));
}
.lv__logo-sub { font-size: .6rem; color: #94a3b8; font-weight: 500; text-transform: uppercase; letter-spacing: .07em; }
.lv__sep { height: 1px; background: #f1f5f9; margin: 0 1.5rem; }

.lv__welcome { padding: 1.1rem 1.5rem 0; }
.lv__welcome-h { font-family: var(--font-display, 'General Sans', sans-serif); font-size: 1.25rem; font-weight: 800; color: var(--c-ink-950, #0E1011); letter-spacing: -.04em; margin-bottom: .18rem; }

/* Cohete: flota, "carbura" (rumble) y despega periódicamente */
.lv__rocket {
  display: inline-block;
  transform-origin: 50% 80%;
  will-change: transform, opacity;
  animation: lv-rocket 5s ease-in-out infinite;
}
.lv__rocket:hover { animation: lv-rocket-launch .9s ease-in forwards; }

@keyframes lv-rocket {
  0%   { transform: translateY(0) rotate(0); opacity: 1; }
  6%   { transform: translateY(2px) rotate(-4deg); }   /* rumble: enciende motores */
  10%  { transform: translateY(2px) rotate(4deg); }
  14%  { transform: translateY(1px) rotate(-3deg); }
  18%  { transform: translateY(1px) rotate(3deg); }
  22%  { transform: translateY(2px) rotate(0); }       /* crouch antes del impulso */
  48%  { transform: translateY(-80px) rotate(16deg); opacity: 0; } /* sube desde su lugar y desaparece */
  49%  { transform: translateY(0) rotate(0); opacity: 0; }         /* reset invisible, ya en su lugar */
  74%  { transform: translateY(0) rotate(0); opacity: 0; }         /* espera apagado */
  88%  { transform: translateY(0) rotate(0); opacity: 1; }         /* reaparece en el mismo lugar (fade) */
  100% { transform: translateY(0) rotate(0); opacity: 1; }
}

/* Al pasar el mouse, despega de una */
@keyframes lv-rocket-launch {
  0%   { transform: translateY(0) rotate(0); }
  20%  { transform: translateY(3px) rotate(-5deg); }
  35%  { transform: translateY(3px) rotate(5deg); }
  100% { transform: translateY(-90px) rotate(15deg); opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .lv__rocket, .lv__rocket:hover { animation: none; }
}
.lv__welcome-p { font-size: .78rem; color: #64748b; }

.lv__form { padding: 1rem 1.5rem 1.1rem; display: flex; flex-direction: column; gap: .8rem; }
.lv__field { display: flex; flex-direction: column; gap: .28rem; }
.lv__label { font-size: .65rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .07em; }

.lv__iw { display: flex; align-items: center; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px; overflow: hidden; transition: all .2s; }
.lv__iw--on { border-color: var(--c-leaf-800, #1A3D2E); background: #fff; box-shadow: 0 0 0 3px rgba(26,61,46,.1); }
.lv__ico { flex-shrink: 0; padding: 0 .75rem; color: #94a3b8; transition: color .2s; }
.lv__iw--on .lv__ico { color: var(--c-leaf-800, #1A3D2E); }
.lv__input { flex: 1; border: none; background: transparent; padding: .85rem .2rem .85rem 0; font-size: .88rem; color: #0f172a; outline: none; width: 100%; }
.lv__input::placeholder { color: #cbd5e1; }
.lv__input:disabled { opacity: .55; }
.lv__eye { background: none; border: none; padding: 0 .75rem; color: #94a3b8; cursor: pointer; display: flex; align-items: center; }
.lv__eye:hover { color: #475569; }

.lv__error { display: flex; align-items: center; gap: .4rem; background: var(--c-rust-100, #FEE2E2); border: 1px solid #fecaca; color: var(--c-rust-600, #DC2626); padding: .55rem .8rem; border-radius: 9px; font-size: .78rem; font-weight: 500; }
.err-enter-active,.err-leave-active { transition: all .2s; }
.err-enter-from,.err-leave-to { opacity:0; transform:translateY(-4px); }

.lv__btn {
  display: flex; align-items: center; justify-content: center; gap: .45rem;
  width: 100%; padding: .95rem;
  background: linear-gradient(135deg, var(--c-leaf-800, #1A3D2E) 0%, var(--c-leaf-600, #3F6452) 100%);
  color: #fff; border: none; border-radius: 12px;
  font-size: .93rem; font-weight: 700; cursor: pointer; transition: all .25s;
  box-shadow: 0 4px 16px rgba(15,42,30,.45);
}
.lv__btn:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(15,42,30,.55); }
.lv__btn:disabled { opacity: .45; cursor: not-allowed; }

.lv__foot { display: flex; align-items: center; justify-content: space-between; padding: .7rem 1.5rem 1.4rem; border-top: 1px solid #f1f5f9; }
.lv__secure { display: flex; align-items: center; gap: .38rem; font-size: .65rem; color: #94a3b8; }
.lv__copy { font-size: .65rem; color: #94a3b8; }
.lv__dot { width: 6px; height: 6px; border-radius: 50%; background: var(--c-leaf-500, #5A8A72); display: inline-block; animation: pulse 2.5s ease infinite; }
@keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.4;transform:scale(.7)} }

.lv__back {
  margin-top: 1.1rem; font-size: .72rem; font-weight: 600;
  color: rgba(168,201,181,.55); text-decoration: none; transition: color .2s;
}
.lv__back:hover { color: var(--c-leaf-300, #A8C9B5); }
.lv__ver { margin-top: .55rem; font-size: .63rem; color: rgba(255,255,255,.13); text-align: center; }
</style>
