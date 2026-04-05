<template>
  <div class="lv">

    <!-- Fondo cosmos -->
    <div class="lv__bg">
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
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(76,175,80,.09)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(76,175,80,.07)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(76,175,80,.07)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(76,175,80,.06)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(76,175,80,.06)"/>
        <path d="M47 74C37 70 25 73 18 82C24 89 37 90 48 82Z" fill="rgba(76,175,80,.05)"/>
        <path d="M53 74C63 70 75 73 82 82C76 89 63 90 52 82Z" fill="rgba(76,175,80,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(76,175,80,.08)" stroke-width="2.5" stroke-linecap="round"/>
      </svg>
      <svg class="lv__chala lv__chala--b" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(56,142,60,.07)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(56,142,60,.06)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(56,142,60,.06)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(56,142,60,.05)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(56,142,60,.05)"/>
        <path d="M50 92L50 155" stroke="rgba(56,142,60,.07)" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <svg class="lv__chala lv__chala--c" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(129,199,132,.05)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(129,199,132,.04)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(129,199,132,.04)"/>
        <path d="M50 92L50 155" stroke="rgba(129,199,132,.05)" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
      <!-- Chalas lado izquierdo -->
      <svg class="lv__chala lv__chala--d" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(56,142,60,.06)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(56,142,60,.05)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(56,142,60,.05)"/>
        <path d="M46 55C34 50 20 52 12 60C17 68 30 70 44 64Z" fill="rgba(56,142,60,.04)"/>
        <path d="M54 55C66 50 80 52 88 60C83 68 70 70 56 64Z" fill="rgba(56,142,60,.04)"/>
        <path d="M50 92L50 155" stroke="rgba(56,142,60,.06)" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <svg class="lv__chala lv__chala--e" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(76,175,80,.05)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(76,175,80,.04)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(76,175,80,.04)"/>
        <path d="M50 92L50 155" stroke="rgba(76,175,80,.05)" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
      <!-- Chala centro -->
      <svg class="lv__chala lv__chala--f" viewBox="0 0 100 160" fill="none">
        <path d="M50 8C44 22 38 42 40 65C42 80 47 88 50 92C53 88 58 80 60 65C62 42 56 22 50 8Z" fill="rgba(46,125,50,.05)"/>
        <path d="M48 35C38 28 24 26 16 32C20 40 32 44 44 40Z" fill="rgba(46,125,50,.04)"/>
        <path d="M52 35C62 28 76 26 84 32C80 40 68 44 56 40Z" fill="rgba(46,125,50,.04)"/>
        <path d="M50 92L50 155" stroke="rgba(46,125,50,.05)" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </div>

    <!-- Layout: 4 columnas — vacío | login | vacío | info -->
    <div class="lv__layout">

      <!-- Col 1: vacía -->
      <div></div>

      <!-- Col 2: Card login -->
      <div class="lv__col-login">
        <div class="lv__card">

          <!-- Logo Cultivo Espacial -->
          <div class="lv__logo">
            <!-- SVG inspirado en el logo: cogollo + navecita + espacio -->
            <div class="lv__logo-mark">
              <svg width="52" height="52" viewBox="0 0 52 52" fill="none" xmlns="http://www.w3.org/2000/svg">
                <!-- Fondo circular tipo espacio -->
                <circle cx="26" cy="26" r="26" fill="#0a1a0c"/>
                <circle cx="26" cy="26" r="26" fill="url(#space-grad)"/>
                <!-- Estrellas del fondo -->
                <circle cx="8"  cy="10" r="0.8" fill="white" opacity="0.6"/>
                <circle cx="44" cy="8"  r="0.6" fill="white" opacity="0.5"/>
                <circle cx="46" cy="20" r="0.7" fill="white" opacity="0.4"/>
                <circle cx="6"  cy="32" r="0.5" fill="white" opacity="0.5"/>
                <circle cx="42" cy="40" r="0.7" fill="white" opacity="0.4"/>
                <circle cx="14" cy="44" r="0.5" fill="white" opacity="0.3"/>
                <!-- Cogollo central (bud) -->
                <!-- Forma principal del bud — esferas agrupadas -->
                <ellipse cx="26" cy="28" rx="9" ry="10" fill="#3d8c3d"/>
                <ellipse cx="22" cy="30" rx="6" ry="7" fill="#4caf50"/>
                <ellipse cx="30" cy="30" rx="6" ry="7" fill="#4caf50"/>
                <ellipse cx="26" cy="24" rx="7" ry="8" fill="#66bb6a"/>
                <ellipse cx="21" cy="26" rx="5" ry="5.5" fill="#81c784"/>
                <ellipse cx="31" cy="26" rx="5" ry="5.5" fill="#81c784"/>
                <ellipse cx="26" cy="22" rx="5.5" ry="6" fill="#a5d6a7"/>
                <!-- Pistils (pistilos naranjas) -->
                <ellipse cx="23" cy="20" rx="0.8" ry="2" fill="#ff7043" transform="rotate(-10 23 20)"/>
                <ellipse cx="27" cy="19" rx="0.8" ry="2" fill="#ff8a65" transform="rotate(5 27 19)"/>
                <ellipse cx="30" cy="21" rx="0.8" ry="1.8" fill="#ff7043" transform="rotate(15 30 21)"/>
                <!-- Tricomas (puntos blancos) -->
                <circle cx="24" cy="21" r="0.9" fill="white" opacity="0.7"/>
                <circle cx="28" cy="20" r="0.8" fill="white" opacity="0.6"/>
                <circle cx="26" cy="23" r="0.7" fill="white" opacity="0.5"/>
                <circle cx="22" cy="24" r="0.7" fill="white" opacity="0.5"/>
                <circle cx="30" cy="23" r="0.8" fill="white" opacity="0.6"/>
                <!-- Hojas de cannabis a los lados -->
                <path d="M17 30 C14 26 10 25 8 28 C10 31 14 32 17 30Z" fill="#2e7d32" opacity="0.9"/>
                <path d="M17 34 C13 31 9 32 8 36 C11 38 15 37 17 34Z" fill="#388e3c" opacity="0.8"/>
                <path d="M35 30 C38 26 42 25 44 28 C42 31 38 32 35 30Z" fill="#2e7d32" opacity="0.9"/>
                <path d="M35 34 C39 31 43 32 44 36 C41 38 37 37 35 34Z" fill="#388e3c" opacity="0.8"/>
                <!-- Tallo -->
                <path d="M26 38 L26 46" stroke="#1b5e20" stroke-width="2" stroke-linecap="round"/>
                <path d="M26 43 C23 45 21 46 19 47" stroke="#2e7d32" stroke-width="1.2" stroke-linecap="round"/>
                <path d="M26 43 C29 45 31 46 33 47" stroke="#2e7d32" stroke-width="1.2" stroke-linecap="round"/>
                <!-- Navecita espacial (arriba derecha) -->
                <g transform="translate(35, 10) rotate(45)">
                  <!-- Cuerpo cohete -->
                  <ellipse cx="0" cy="0" rx="3" ry="5.5" fill="#e0e0e0"/>
                  <!-- Cabeza cohete -->
                  <path d="M0 -5.5 C-2 -3 -3 0 -3 0 L3 0 C3 0 2 -3 0 -5.5Z" fill="#f5f5f5"/>
                  <!-- Ventana -->
                  <circle cx="0" cy="0.5" r="1.2" fill="#64b5f6" opacity="0.9"/>
                  <!-- Aletas -->
                  <path d="M-3 2 L-5 5 L-3 5 Z" fill="#bdbdbd"/>
                  <path d="M3 2 L5 5 L3 5 Z" fill="#bdbdbd"/>
                  <!-- Llama del cohete -->
                  <path d="M-2 5 L0 9 L2 5Z" fill="#ff7043" opacity="0.9"/>
                  <path d="M-1 5 L0 8 L1 5Z" fill="#ffcc02" opacity="0.8"/>
                </g>
                <!-- Estela del cohete -->
                <path d="M36 16 C33 19 30 21 27 22" stroke="rgba(255,200,100,.4)" stroke-width="1" stroke-dasharray="1.5 2" stroke-linecap="round"/>
                <defs>
                  <radialGradient id="space-grad" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stop-color="#0d2010"/>
                    <stop offset="100%" stop-color="#060f07"/>
                  </radialGradient>
                </defs>
              </svg>
            </div>
            <div>
              <div class="lv__logo-name">Cultivo Espacial</div>
              <div class="lv__logo-sub">Gestión medicinal profesional</div>
            </div>
          </div>

          <div class="lv__sep"></div>

          <div class="lv__welcome">
            <h2 class="lv__welcome-h">Bienvenido 🚀</h2>
            <p class="lv__welcome-p">Iniciá sesión para acceder a tu club</p>
          </div>

          <form @submit.prevent="onSubmit" novalidate class="lv__form">
            <div class="lv__field">
              <label class="lv__label">Email</label>
              <div class="lv__iw" :class="{ 'lv__iw--on': focusEmail }">
                <svg class="lv__ico" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/>
                </svg>
                <input v-model.trim="email" type="email" class="lv__input"
                       placeholder="admin@miclub.org"
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

            <button class="lv__btn" type="submit" :disabled="auth.loading || !email || !password">
              <div v-if="auth.loading" class="lv__spinner"></div>
              <template v-else>
                <span>Ingresar al club</span>
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
        <div class="lv__ver">v0.1.0 beta</div>
      </div>

      <!-- Col 3: vacía -->
      <div></div>

      <!-- Col 4: Info -->
      <div class="lv__col-info">
        <div class="lv__info">

          <div class="lv__badge">
            <span class="lv__bdot"></span>
            Plataforma REPROCANN · Argentina
          </div>

          <h1 class="lv__headline">
            La gestión que<br>tu club <em>merece</em>
          </h1>

          <p class="lv__desc">
            Trazabilidad completa, cumplimiento normativo y gestión profesional para clubes de cannabis medicinal en Argentina.
          </p>

          <div class="lv__ruler"></div>

          <div class="lv__stats">
            <div class="lv__stat">
              <span class="lv__stat-n">100%</span>
              <span class="lv__stat-l">REPROCANN</span>
            </div>
            <span class="lv__ssep"></span>
            <div class="lv__stat">
              <span class="lv__stat-n">∞</span>
              <span class="lv__stat-l">Trazabilidad</span>
            </div>
            <span class="lv__ssep"></span>
            <div class="lv__stat">
              <span class="lv__stat-n">24/7</span>
              <span class="lv__stat-l">Acceso</span>
            </div>
          </div>

          <div class="lv__features">
            <div class="lv__feat">
              <div class="lv__feat-ico">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <div>
                <div class="lv__feat-t">100% REPROCANN</div>
                <div class="lv__feat-d">Informe semestral automático — Resolución 1780/2025</div>
              </div>
            </div>
            <div class="lv__feat">
              <div class="lv__feat-ico">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>
                </svg>
              </div>
              <div>
                <div class="lv__feat-t">Trazabilidad total</div>
                <div class="lv__feat-d">Cada planta desde semilla hasta dispensación con QR</div>
              </div>
            </div>
            <div class="lv__feat">
              <div class="lv__feat-ico">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>
                </svg>
              </div>
              <div>
                <div class="lv__feat-t">Gestión integral</div>
                <div class="lv__feat-d">Pacientes, contabilidad, tareas y genéticas en un solo lugar</div>
              </div>
            </div>
          </div>

          <div class="lv__news">
            <div class="lv__news-hd">Últimas novedades</div>
            <div class="lv__nitem"><span class="lv__ndot" style="background:#4caf50"></span>Genéticas INASE integradas al sistema</div>
            <div class="lv__nitem"><span class="lv__ndot" style="background:#42a5f5"></span>Exportación PDF del informe semestral</div>
            <div class="lv__nitem"><span class="lv__ndot" style="background:#ffa726"></span>Tareas con repetición automática</div>
          </div>

        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const email      = ref('')
const password   = ref('')
const showPass   = ref(false)
const focusEmail = ref(false)
const focusPass  = ref(false)
const yr = new Date().getFullYear()

async function onSubmit() {
  try {
    await auth.login(email.value, password.value)
    router.replace(String(route.query.redirect || '/'))
  } catch (_) {}
}
</script>

<style scoped>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

.lv {
  position: fixed; inset: 0;
  font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
  background: #050d06;
  overflow: hidden;
}

/* Fondo espacio */
.lv__bg {
  position: absolute; inset: 0; pointer-events: none; overflow: hidden;
  background:
    radial-gradient(ellipse 70% 70% at 50% 50%, rgba(27,94,32,.28) 0%, transparent 65%),
    radial-gradient(ellipse 90% 60% at 75% 45%, rgba(20,80,25,.35) 0%, transparent 55%),
    radial-gradient(ellipse 50% 50% at 20% 80%, rgba(15,60,20,.2) 0%, transparent 50%),
    linear-gradient(170deg, #050d06 0%, #091508 45%, #050d06 100%);
}

/* Nebulosas */
.lv__nebula { position: absolute; border-radius: 50%; filter: blur(80px); animation: neb linear infinite; }
.lv__nebula--1 { width: 500px; height: 500px; background: rgba(27,94,32,.18); top: -100px; right: 5%; animation-duration: 25s; }
.lv__nebula--2 { width: 400px; height: 400px; background: rgba(46,125,50,.14); bottom: -80px; right: 20%; animation-duration: 30s; animation-delay: -10s; }
.lv__nebula--3 { width: 350px; height: 350px; background: rgba(13,50,18,.25); top: 30%; left: 5%; animation-duration: 20s; animation-delay: -6s; }
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
.lv__chala--f { width: 120px; height: 192px; left: 30%; top: 70%; animation-duration: 16s; animation-delay: -5s; }
@keyframes sway {
  0%  { transform: rotate(-4deg); }
  25% { transform: rotate(2deg) translateY(-5px); }
  50% { transform: rotate(-2deg) translateY(3px); }
  75% { transform: rotate(3deg) translateY(-3px); }
  100%{ transform: rotate(-4deg); }
}

/* Layout 4 columnas: 1fr | 420px | 1fr | 1fr */
.lv__layout {
  position: relative; z-index: 10;
  display: grid;
  grid-template-columns: 0.3fr 420px 0.2fr 1fr;
  min-height: 100vh;
  align-items: center;
}
@media (max-width: 1100px) {
  .lv__layout { grid-template-columns: 0.3fr 420px 0.2fr 1fr; }
}
@media (max-width: 860px) {
  .lv__layout { grid-template-columns: 1fr; padding: 1.5rem; }
  .lv__col-info { display: none; }
}

/* Col login */
.lv__col-login {
  display: flex; flex-direction: column; align-items: center;
  padding: 2rem 0;
}

/* Card */
.lv__card {
  width: 100%; max-width: 400px;
  background: rgba(255,255,255,.97);
  border-radius: 26px; overflow: hidden;
  box-shadow:
    0 0 0 1px rgba(255,255,255,.15),
    0 40px 80px rgba(0,0,0,.7),
    0 0 140px rgba(27,94,32,.25),
    inset 0 1px 0 rgba(255,255,255,.9);
}

.lv__logo { display: flex; align-items: center; gap: .9rem; padding: 1.5rem 1.5rem 1rem; }
.lv__logo-mark { flex-shrink: 0; filter: drop-shadow(0 2px 8px rgba(27,94,32,.4)); }
.lv__logo-name { font-size: 1.05rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; }
.lv__logo-sub { font-size: .6rem; color: #94a3b8; font-weight: 500; text-transform: uppercase; letter-spacing: .07em; margin-top: .1rem; }
.lv__sep { height: 1px; background: #f1f5f9; margin: 0 1.5rem; }

.lv__welcome { padding: 1.1rem 1.5rem 0; }
.lv__welcome-h { font-size: 1.25rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; margin-bottom: .18rem; }
.lv__welcome-p { font-size: .78rem; color: #64748b; }

.lv__form { padding: 1rem 1.5rem 1.1rem; display: flex; flex-direction: column; gap: .8rem; }
.lv__field { display: flex; flex-direction: column; gap: .28rem; }
.lv__label { font-size: .65rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .07em; }

.lv__iw { display: flex; align-items: center; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px; overflow: hidden; transition: all .2s; }
.lv__iw--on { border-color: #1b5e20; background: #fff; box-shadow: 0 0 0 3px rgba(27,94,32,.09); }
.lv__ico { flex-shrink: 0; padding: 0 .75rem; color: #94a3b8; transition: color .2s; }
.lv__iw--on .lv__ico { color: #1b5e20; }
.lv__input { flex: 1; border: none; background: transparent; padding: .85rem .2rem .85rem 0; font-size: .88rem; color: #0f172a; outline: none; width: 100%; }
.lv__input::placeholder { color: #cbd5e1; }
.lv__input:disabled { opacity: .55; }
.lv__eye { background: none; border: none; padding: 0 .75rem; color: #94a3b8; cursor: pointer; display: flex; align-items: center; }
.lv__eye:hover { color: #475569; }

.lv__error { display: flex; align-items: center; gap: .4rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .55rem .8rem; border-radius: 9px; font-size: .78rem; font-weight: 500; }
.err-enter-active,.err-leave-active { transition: all .2s; }
.err-enter-from,.err-leave-to { opacity:0; transform:translateY(-4px); }

.lv__btn {
  display: flex; align-items: center; justify-content: center; gap: .45rem;
  width: 100%; padding: .95rem;
  background: linear-gradient(135deg, #1b5e20 0%, #2e7d32 60%);
  color: #fff; border: none; border-radius: 12px;
  font-size: .93rem; font-weight: 700; cursor: pointer; transition: all .25s;
  box-shadow: 0 4px 16px rgba(27,94,32,.45);
}
.lv__btn:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(27,94,32,.55); }
.lv__btn:disabled { opacity: .45; cursor: not-allowed; }
.lv__spinner { width: 18px; height: 18px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: spin .7s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.lv__foot { display: flex; align-items: center; justify-content: space-between; padding: .7rem 1.5rem 1.4rem; border-top: 1px solid #f1f5f9; }
.lv__secure { display: flex; align-items: center; gap: .38rem; font-size: .65rem; color: #94a3b8; }
.lv__copy { font-size: .65rem; color: #94a3b8; }
.lv__dot { width: 6px; height: 6px; border-radius: 50%; background: #22c55e; display: inline-block; animation: pulse 2.5s ease infinite; }
@keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.4;transform:scale(.7)} }
.lv__ver { margin-top: .9rem; font-size: .63rem; color: rgba(255,255,255,.13); text-align: center; }

/* Col info */
.lv__col-info {
  display: flex; align-items: center;
  padding: 2rem 1.5rem 2rem 1rem;
}
.lv__info { display: flex; flex-direction: column; gap: 1.1rem; max-width: 420px; width: 100%; }

.lv__badge {
  display: inline-flex; align-items: center; gap: .45rem;
  border: 1px solid rgba(76,175,80,.3); background: rgba(76,175,80,.08);
  color: #81c784; font-size: .65rem; font-weight: 700;
  padding: .35em .9em; border-radius: 999px;
  text-transform: uppercase; letter-spacing: .08em; width: fit-content;
}
.lv__bdot { width: 6px; height: 6px; border-radius: 50%; background: #4caf50; animation: pulse 2s ease infinite; }

.lv__headline { font-size: 2.6rem; font-weight: 900; color: #fff; letter-spacing: -.06em; line-height: 1.06; }
.lv__headline em {
  font-style: normal;
  background: linear-gradient(135deg, #66bb6a 0%, #a5d6a7 60%);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
}

.lv__desc { font-size: .8rem; color: rgba(255,255,255,.32); line-height: 1.7; }
.lv__ruler { width: 36px; height: 2px; background: linear-gradient(90deg, #4caf50, transparent); border-radius: 2px; }

.lv__stats { display: flex; align-items: center; gap: 1rem; background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.07); border-radius: 12px; padding: .75rem 1.1rem; }
.lv__stat { text-align: center; flex: 1; }
.lv__stat-n { display: block; font-size: 1.05rem; font-weight: 800; color: #81c784; letter-spacing: -.03em; }
.lv__stat-l { display: block; font-size: .56rem; color: rgba(255,255,255,.28); text-transform: uppercase; letter-spacing: .06em; margin-top: .12rem; }
.lv__ssep { width: 1px; height: 26px; background: rgba(255,255,255,.08); flex-shrink: 0; }

.lv__features { display: flex; flex-direction: column; gap: .5rem; }
.lv__feat { display: flex; align-items: flex-start; gap: .75rem; background: rgba(255,255,255,.025); border: 1px solid rgba(255,255,255,.04); border-radius: 11px; padding: .7rem .9rem; transition: all .2s; }
.lv__feat:hover { background: rgba(76,175,80,.07); border-color: rgba(76,175,80,.14); transform: translateX(4px); }
.lv__feat-ico { width: 30px; height: 30px; border-radius: 8px; background: rgba(76,175,80,.12); color: #66bb6a; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.lv__feat-t { font-size: .78rem; font-weight: 700; color: rgba(255,255,255,.8); margin-bottom: .12rem; }
.lv__feat-d { font-size: .67rem; color: rgba(255,255,255,.28); line-height: 1.4; }

.lv__news { background: rgba(255,255,255,.025); border: 1px solid rgba(255,255,255,.04); border-radius: 11px; padding: .8rem 1rem; }
.lv__news-hd { font-size: .58rem; font-weight: 800; color: rgba(255,255,255,.26); text-transform: uppercase; letter-spacing: .1em; margin-bottom: .55rem; }
.lv__nitem { display: flex; align-items: center; gap: .48rem; font-size: .72rem; color: rgba(255,255,255,.4); padding: .22rem 0; }
.lv__nitem + .lv__nitem { border-top: 1px solid rgba(255,255,255,.04); }
.lv__ndot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
</style>




