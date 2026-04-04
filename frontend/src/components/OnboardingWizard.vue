<script setup>
import { ref } from 'vue'
import { createSede } from '../lib/api.js'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth   = useAuthStore()
const emit   = defineEmits(['completado'])

const paso   = ref(1)
const saving = ref(false)
const error  = ref(null)

const sede = ref({
  nombre: '',
  tipo: 'produccion',
  direccion: '',
  ciudad: '',
  provincia: '',
  declarada_reprocann: false,
})

const TIPOS = [
  {
    key: 'produccion',
    label: 'Producción',
    desc: 'Salas de cultivo, lotes y plantas',
    icon: `<svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M11 2C11 2 5 7 5 12a6 6 0 0012 0c0-5-6-10-6-10z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M11 22v-8M8 16l3-3 3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  },
  {
    key: 'social',
    label: 'Dispensario',
    desc: 'Atención de pacientes y dispensaciones',
    icon: `<svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="6" width="18" height="14" rx="2" stroke="currentColor" stroke-width="1.5"/><path d="M7 6V4a4 4 0 018 0v2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M11 11v4M9 13h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
  },
  {
    key: 'mixta',
    label: 'Mixta',
    desc: 'Producción y dispensación en un mismo espacio',
    icon: `<svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="11" cy="11" r="9" stroke="currentColor" stroke-width="1.5"/><path d="M11 2v18M2 11h18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
  },
]

const nombreInvalido = ref(false)

async function avanzar() {
  if (!sede.value.nombre.trim()) {
    nombreInvalido.value = true
    return
  }
  nombreInvalido.value = false
  paso.value = 2
}

async function crearSede() {
  saving.value = true
  error.value  = null
  try {
    await createSede(sede.value)
    paso.value = 3
    setTimeout(() => {
      emit('completado')
      router.push({ name: 'sedes' })
    }, 2200)
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Error al crear la sede. Intentá de nuevo.'
    paso.value = 1
  } finally {
    saving.value = false
  }
}

function tipoSeleccionado(key) {
  return sede.value.tipo === key
}

const nombreClub = auth.user?.club_name || auth.clubName || ''
const nombreUsuario = auth.user?.first_name || ''
</script>

<template>
  <div class="ob">

    <!-- Fondo animado -->
    <div class="ob__bg">
      <div class="ob__bg-orb ob__bg-orb--1"></div>
      <div class="ob__bg-orb ob__bg-orb--2"></div>
      <div class="ob__bg-orb ob__bg-orb--3"></div>
    </div>

    <!-- Logo superior -->
    <div class="ob__logo">
      <div class="ob__logo-mark">
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M11 2C11 2 5 7 5 12a6 6 0 0012 0c0-5-6-10-6-10z" fill="white" opacity="0.9"/>
          <path d="M11 22v-8" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </div>
      <span class="ob__logo-text">Club Cultivo</span>
    </div>

    <!-- Contenido central -->
    <div class="ob__center">

      <!-- ── PASO 1 ── Bienvenida + Datos de sede -->
      <Transition name="ob-fade" mode="out-in">
        <div v-if="paso === 1" class="ob__panel" key="paso1">

          <div class="ob__welcome">
            <div class="ob__leaf">
              <svg viewBox="0 0 60 60" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="30" cy="30" r="30" fill="rgba(255,255,255,0.12)"/>
                <path d="M30 10C30 10 14 22 14 34a16 16 0 0032 0c0-12-16-24-16-24z" fill="white" opacity="0.85"/>
                <path d="M30 50V32" stroke="white" stroke-width="2" stroke-linecap="round"/>
                <path d="M24 38l6-6 6 6" stroke="white" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <h1 class="ob__title">
              Bienvenido{{ nombreUsuario ? `, ${nombreUsuario}` : '' }}
            </h1>
            <p class="ob__subtitle">
              Estamos muy contentos de tenerte acá.<br>
              Juntos vamos a configurar tu espacio.
            </p>
          </div>

          <div class="ob__card">
            <div class="ob__card-eyebrow">Tu primera sede</div>
            <h2 class="ob__card-title">¿Dónde opera el club?</h2>
            <p class="ob__card-desc">
              Una sede es el domicilio físico donde funciona el club.
              Podés agregar más después.
            </p>

            <div class="ob__field">
              <label class="ob__label">Nombre de la sede <span class="ob__req">*</span></label>
              <input
                v-model.trim="sede.nombre"
                class="ob__input"
                :class="{ 'ob__input--err': nombreInvalido }"
                placeholder="Ej: Sede Palermo, Dispensario Centro..."
                @input="nombreInvalido = false"
                @keyup.enter="avanzar"
                autofocus
              />
              <span v-if="nombreInvalido" class="ob__err">El nombre es obligatorio</span>
            </div>

            <div class="ob__field">
              <label class="ob__label">Tipo de sede</label>
              <div class="ob__tipos">
                <button
                  v-for="t in TIPOS"
                  :key="t.key"
                  class="ob__tipo"
                  :class="{ 'ob__tipo--selected': tipoSeleccionado(t.key) }"
                  @click="sede.tipo = t.key"
                  type="button"
                >
                  <span class="ob__tipo-icon" v-html="t.icon"></span>
                  <div class="ob__tipo-body">
                    <div class="ob__tipo-label">{{ t.label }}</div>
                    <div class="ob__tipo-desc">{{ t.desc }}</div>
                  </div>
                  <div class="ob__tipo-check">
                    <svg v-if="tipoSeleccionado(t.key)" width="14" height="14" viewBox="0 0 14 14" fill="none">
                      <path d="M2 7l4 4 6-7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                  </div>
                </button>
              </div>
            </div>

            <div class="ob__field">
              <label class="ob__label">Ubicación <span class="ob__opt">(opcional)</span></label>
              <input v-model.trim="sede.direccion" class="ob__input" placeholder="Calle y número" />
              <div class="ob__row">
                <input v-model.trim="sede.ciudad" class="ob__input" placeholder="Ciudad" />
                <input v-model.trim="sede.provincia" class="ob__input" placeholder="Provincia" />
              </div>
            </div>

            <div class="ob__toggle">
              <div class="ob__toggle-info">
                <div class="ob__toggle-label">Declarada ante REPROCANN</div>
                <div class="ob__toggle-desc">Resolución 1780/2025 del Ministerio de Salud</div>
              </div>
              <button
                type="button"
                class="ob__switch"
                :class="{ 'ob__switch--on': sede.declarada_reprocann }"
                @click="sede.declarada_reprocann = !sede.declarada_reprocann"
              >
                <div class="ob__switch-thumb"></div>
              </button>
            </div>

            <button class="ob__btn-primary" @click="avanzar">
              Continuar
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                <path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
          </div>

        </div>

        <!-- ── PASO 2 ── Confirmar -->
        <div v-else-if="paso === 2" class="ob__panel" key="paso2">

          <div class="ob__welcome ob__welcome--sm">
            <h1 class="ob__title">Revisá antes de continuar</h1>
            <p class="ob__subtitle">Todo bien? Creamos la sede y ya podés empezar.</p>
          </div>

          <div class="ob__card">

            <div v-if="error" class="ob__alert">{{ error }}</div>

            <!-- Preview sede -->
            <div class="ob__preview">
              <div class="ob__preview-icon" :class="`ob__preview-icon--${sede.tipo}`">
                <span v-html="TIPOS.find(t => t.key === sede.tipo)?.icon"></span>
              </div>
              <div class="ob__preview-body">
                <div class="ob__preview-nombre">{{ sede.nombre }}</div>
                <div class="ob__preview-tipo">{{ TIPOS.find(t => t.key === sede.tipo)?.label }}</div>
                <div v-if="sede.direccion || sede.ciudad" class="ob__preview-loc">
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                    <path d="M6 1a3.5 3.5 0 00-3.5 3.5C2.5 7 6 11 6 11s3.5-4 3.5-6.5A3.5 3.5 0 006 1z" stroke="currentColor" stroke-width="1.2"/>
                    <circle cx="6" cy="4.5" r="1" fill="currentColor"/>
                  </svg>
                  {{ [sede.direccion, sede.ciudad, sede.provincia].filter(Boolean).join(', ') }}
                </div>
              </div>
              <div v-if="sede.declarada_reprocann" class="ob__preview-rep">
                <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
                  <path d="M6.5 1L8 4.5H12L9 7l1 4-3.5-2.5L3 11l1-4-3-2.5H5.5z" fill="currentColor" opacity="0.8"/>
                </svg>
                REPROCANN
              </div>
            </div>

            <!-- Qué viene después -->
            <div class="ob__steps">
              <div class="ob__steps-title">Después de crear la sede vas a poder</div>
              <div class="ob__step">
                <div class="ob__step-num">1</div>
                <div class="ob__step-text">Agregar salas de cultivo dentro de la sede</div>
              </div>
              <div class="ob__step">
                <div class="ob__step-num">2</div>
                <div class="ob__step-text">Crear lotes y asignar genéticas INASE</div>
              </div>
              <div class="ob__step">
                <div class="ob__step-num">3</div>
                <div class="ob__step-text">Registrar pacientes y generar informes REPROCANN</div>
              </div>
            </div>

            <div class="ob__actions">
              <button class="ob__btn-ghost" @click="paso = 1" :disabled="saving">
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                  <path d="M11 7H3M7 3L3 7l4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                Volver
              </button>
              <button class="ob__btn-primary ob__btn-primary--wide" @click="crearSede" :disabled="saving">
                <div v-if="saving" class="ob__spinner"></div>
                <template v-else>
                  Crear sede y empezar
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                    <path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                </template>
              </button>
            </div>
          </div>

        </div>

        <!-- ── PASO 3 ── Éxito -->
        <div v-else-if="paso === 3" class="ob__panel ob__panel--success" key="paso3">
          <div class="ob__success">
            <div class="ob__success-ring">
              <svg width="44" height="44" viewBox="0 0 44 44" fill="none">
                <circle cx="22" cy="22" r="20" stroke="white" stroke-width="2" opacity="0.3"/>
                <path d="M12 22l8 8 12-14" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <h1 class="ob__title ob__title--light">Todo listo</h1>
            <p class="ob__subtitle ob__subtitle--light">
              {{ sede.nombre }} fue creada.<br>
              Te llevamos al panel ahora mismo.
            </p>
            <div class="ob__dots">
              <div class="ob__dot"></div>
              <div class="ob__dot"></div>
              <div class="ob__dot"></div>
            </div>
          </div>
        </div>

      </Transition>
    </div>

    <!-- Progreso -->
    <div class="ob__progress" v-if="paso < 3">
      <div class="ob__progress-step" :class="{ 'ob__progress-step--done': paso > 1, 'ob__progress-step--active': paso === 1 }">
        <div class="ob__progress-dot">
          <svg v-if="paso > 1" width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M1 5l3 3 5-6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>
        <span>Datos</span>
      </div>
      <div class="ob__progress-line" :class="{ 'ob__progress-line--done': paso > 1 }"></div>
      <div class="ob__progress-step" :class="{ 'ob__progress-step--active': paso === 2 }">
        <div class="ob__progress-dot"></div>
        <span>Confirmar</span>
      </div>
    </div>

  </div>
</template>

<style scoped>
/* ── Base ─────────────────────────────────── */
.ob {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: flex;
  flex-direction: column;
  align-items: center;
  background: #0d1f0f;
  overflow-y: auto;
  font-family: system-ui, -apple-system, sans-serif;
}

/* ── Fondo animado ─────────────────────────── */
.ob__bg {
  position: fixed;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}
.ob__bg-orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.18;
}
.ob__bg-orb--1 {
  width: 600px; height: 600px;
  background: #2e7d32;
  top: -200px; left: -200px;
  animation: orb-drift 18s ease-in-out infinite alternate;
}
.ob__bg-orb--2 {
  width: 400px; height: 400px;
  background: #1b5e20;
  bottom: -100px; right: -100px;
  animation: orb-drift 22s ease-in-out infinite alternate-reverse;
}
.ob__bg-orb--3 {
  width: 300px; height: 300px;
  background: #388e3c;
  top: 40%; left: 60%;
  animation: orb-drift 15s ease-in-out infinite alternate;
}
@keyframes orb-drift {
  from { transform: translate(0, 0) scale(1); }
  to   { transform: translate(40px, 30px) scale(1.1); }
}

/* ── Logo ──────────────────────────────────── */
.ob__logo {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2rem 1.5rem 0;
  z-index: 1;
  align-self: flex-start;
}
.ob__logo-mark {
  width: 36px; height: 36px;
  background: rgba(255,255,255,0.12);
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  border: 1px solid rgba(255,255,255,0.15);
}
.ob__logo-text {
  font-size: .875rem;
  font-weight: 600;
  color: rgba(255,255,255,0.7);
  letter-spacing: .02em;
}

/* ── Centro ────────────────────────────────── */
.ob__center {
  flex: 1;
  width: 100%;
  max-width: 520px;
  padding: 2rem 1.25rem;
  z-index: 1;
  display: flex;
  flex-direction: column;
}

/* ── Panel ─────────────────────────────────── */
.ob__panel {
  display: flex;
  flex-direction: column;
  gap: 1.75rem;
}
.ob__panel--success {
  flex: 1;
  justify-content: center;
  align-items: center;
  min-height: 60vh;
}

/* ── Welcome ───────────────────────────────── */
.ob__welcome {
  text-align: center;
  padding-top: .5rem;
}
.ob__welcome--sm {
  padding-top: 0;
}
.ob__leaf {
  width: 72px; height: 72px;
  margin: 0 auto 1.5rem;
  animation: leaf-float 4s ease-in-out infinite;
}
@keyframes leaf-float {
  0%, 100% { transform: translateY(0) rotate(-2deg); }
  50%       { transform: translateY(-10px) rotate(2deg); }
}
.ob__title {
  font-size: 2rem;
  font-weight: 700;
  color: #fff;
  margin: 0 0 .625rem;
  letter-spacing: -.04em;
  line-height: 1.1;
}
.ob__title--light { color: #fff; }
.ob__subtitle {
  font-size: .9rem;
  color: rgba(255,255,255,0.55);
  margin: 0;
  line-height: 1.65;
}
.ob__subtitle--light { color: rgba(255,255,255,0.7); }

/* ── Card ──────────────────────────────────── */
.ob__card {
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 20px;
  padding: 1.75rem;
  backdrop-filter: blur(12px);
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}
.ob__card-eyebrow {
  font-size: .72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .1em;
  color: #4caf50;
}
.ob__card-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #fff;
  margin: 0;
  letter-spacing: -.02em;
}
.ob__card-desc {
  font-size: .83rem;
  color: rgba(255,255,255,.45);
  margin: 0;
  line-height: 1.6;
}

/* ── Fields ─────────────────────────────────── */
.ob__field {
  display: flex;
  flex-direction: column;
  gap: .5rem;
}
.ob__label {
  font-size: .78rem;
  font-weight: 600;
  color: rgba(255,255,255,0.65);
  letter-spacing: .01em;
}
.ob__req { color: #ef5350; margin-left: 2px; }
.ob__opt { color: rgba(255,255,255,0.3); font-weight: 400; }
.ob__err { font-size: .75rem; color: #ef9a9a; }

.ob__input {
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.12);
  border-radius: 10px;
  padding: .7rem .875rem;
  font-size: .875rem;
  color: #fff;
  width: 100%;
  box-sizing: border-box;
  transition: border-color .15s, background .15s;
  outline: none;
}
.ob__input::placeholder { color: rgba(255,255,255,0.25); }
.ob__input:focus {
  border-color: rgba(76,175,80,0.6);
  background: rgba(255,255,255,0.09);
}
.ob__input--err { border-color: #ef5350; }

.ob__row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: .5rem;
}

/* ── Tipos ─────────────────────────────────── */
.ob__tipos {
  display: flex;
  flex-direction: column;
  gap: .5rem;
}
.ob__tipo {
  display: flex;
  align-items: center;
  gap: .875rem;
  padding: .875rem 1rem;
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 12px;
  cursor: pointer;
  transition: all .15s;
  text-align: left;
  width: 100%;
  color: rgba(255,255,255,0.7);
}
.ob__tipo:hover {
  background: rgba(255,255,255,0.07);
  border-color: rgba(255,255,255,0.2);
}
.ob__tipo--selected {
  background: rgba(76,175,80,0.12);
  border-color: rgba(76,175,80,0.4);
  color: #fff;
}
.ob__tipo-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  flex-shrink: 0;
  opacity: 0.8;
}
.ob__tipo--selected .ob__tipo-icon { opacity: 1; }
.ob__tipo-body { flex: 1; }
.ob__tipo-label {
  font-size: .85rem;
  font-weight: 600;
  margin-bottom: .1rem;
}
.ob__tipo-desc {
  font-size: .73rem;
  color: rgba(255,255,255,0.4);
}
.ob__tipo--selected .ob__tipo-desc { color: rgba(255,255,255,0.55); }
.ob__tipo-check {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 1.5px solid rgba(255,255,255,0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: all .15s;
}
.ob__tipo--selected .ob__tipo-check {
  background: #4caf50;
  border-color: #4caf50;
  color: #fff;
}

/* ── Toggle REPROCANN ──────────────────────── */
.ob__toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .875rem 1rem;
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 12px;
  gap: 1rem;
}
.ob__toggle-label {
  font-size: .83rem;
  font-weight: 600;
  color: rgba(255,255,255,0.8);
}
.ob__toggle-desc {
  font-size: .72rem;
  color: rgba(255,255,255,0.35);
  margin-top: .15rem;
}
.ob__switch {
  width: 44px;
  height: 24px;
  border-radius: 12px;
  background: rgba(255,255,255,0.1);
  border: none;
  cursor: pointer;
  position: relative;
  flex-shrink: 0;
  transition: background .2s;
}
.ob__switch--on { background: #4caf50; }
.ob__switch-thumb {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: white;
  transition: transform .2s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.3);
}
.ob__switch--on .ob__switch-thumb { transform: translateX(20px); }

/* ── Botones ───────────────────────────────── */
.ob__btn-primary {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: .5rem;
  background: #2e7d32;
  color: #fff;
  border: none;
  padding: .875rem 1.5rem;
  border-radius: 12px;
  font-size: .9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background .15s, transform .1s;
  width: 100%;
  letter-spacing: .01em;
}
.ob__btn-primary:hover { background: #1b5e20; transform: translateY(-1px); }
.ob__btn-primary:active { transform: translateY(0); }
.ob__btn-primary:disabled { opacity: .6; cursor: not-allowed; transform: none; }

.ob__btn-ghost {
  display: inline-flex;
  align-items: center;
  gap: .4rem;
  background: rgba(255,255,255,0.06);
  color: rgba(255,255,255,0.6);
  border: 1px solid rgba(255,255,255,0.1);
  padding: .875rem 1.25rem;
  border-radius: 12px;
  font-size: .875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all .15s;
  white-space: nowrap;
}
.ob__btn-ghost:hover {
  background: rgba(255,255,255,0.1);
  color: rgba(255,255,255,0.8);
}
.ob__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }

.ob__actions {
  display: flex;
  gap: .75rem;
  align-items: center;
}
.ob__btn-primary--wide { flex: 1; }

/* ── Preview (paso 2) ──────────────────────── */
.ob__preview {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  padding: 1.25rem;
  background: rgba(76,175,80,0.08);
  border: 1px solid rgba(76,175,80,0.25);
  border-radius: 14px;
}
.ob__preview-icon {
  width: 44px;
  height: 44px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: #fff;
}
.ob__preview-icon--produccion { background: rgba(46,125,50,0.5); }
.ob__preview-icon--social     { background: rgba(25,118,210,0.4); }
.ob__preview-icon--mixta      { background: rgba(123,31,162,0.4); }
.ob__preview-body { flex: 1; }
.ob__preview-nombre {
  font-size: 1rem;
  font-weight: 700;
  color: #fff;
  margin-bottom: .2rem;
}
.ob__preview-tipo {
  font-size: .78rem;
  color: rgba(255,255,255,0.5);
  margin-bottom: .3rem;
}
.ob__preview-loc {
  display: flex;
  align-items: center;
  gap: .35rem;
  font-size: .75rem;
  color: rgba(255,255,255,0.4);
}
.ob__preview-rep {
  display: flex;
  align-items: center;
  gap: .35rem;
  font-size: .7rem;
  font-weight: 700;
  color: #4caf50;
  background: rgba(76,175,80,0.15);
  padding: .25em .65em;
  border-radius: 999px;
  white-space: nowrap;
}

/* ── Steps info (paso 2) ───────────────────── */
.ob__steps {
  display: flex;
  flex-direction: column;
  gap: .6rem;
}
.ob__steps-title {
  font-size: .72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: rgba(255,255,255,0.3);
  margin-bottom: .25rem;
}
.ob__step {
  display: flex;
  align-items: center;
  gap: .875rem;
}
.ob__step-num {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: rgba(76,175,80,0.15);
  border: 1px solid rgba(76,175,80,0.3);
  color: #4caf50;
  font-size: .72rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.ob__step-text {
  font-size: .82rem;
  color: rgba(255,255,255,0.55);
}

/* ── Alert ─────────────────────────────────── */
.ob__alert {
  background: rgba(239,83,80,0.15);
  border: 1px solid rgba(239,83,80,0.3);
  color: #ef9a9a;
  padding: .75rem 1rem;
  border-radius: 10px;
  font-size: .83rem;
}

/* ── Spinner ───────────────────────────────── */
.ob__spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: ob-spin .6s linear infinite;
}
@keyframes ob-spin { to { transform: rotate(360deg); } }

/* ── Éxito ─────────────────────────────────── */
.ob__success {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 1rem;
}
.ob__success-ring {
  width: 88px;
  height: 88px;
  border-radius: 50%;
  background: rgba(76,175,80,0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  animation: success-pop .4s cubic-bezier(.34,1.56,.64,1);
}
@keyframes success-pop {
  from { transform: scale(0.5); opacity: 0; }
  to   { transform: scale(1);   opacity: 1; }
}
.ob__dots {
  display: flex;
  gap: 6px;
  margin-top: .5rem;
}
.ob__dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgba(255,255,255,0.3);
  animation: dot-blink 1.2s ease-in-out infinite;
}
.ob__dot:nth-child(2) { animation-delay: .2s; }
.ob__dot:nth-child(3) { animation-delay: .4s; }
@keyframes dot-blink {
  0%, 100% { opacity: 0.3; transform: scale(1); }
  50%       { opacity: 1;   transform: scale(1.3); }
}

/* ── Progreso inferior ─────────────────────── */
.ob__progress {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  padding: 1.5rem;
  z-index: 1;
}
.ob__progress-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: .35rem;
  font-size: .7rem;
  color: rgba(255,255,255,0.3);
  transition: color .2s;
}
.ob__progress-step--active { color: rgba(255,255,255,0.7); }
.ob__progress-step--done   { color: #4caf50; }
.ob__progress-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  border: 1.5px solid currentColor;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all .2s;
}
.ob__progress-step--active .ob__progress-dot {
  background: rgba(255,255,255,0.7);
  border-color: rgba(255,255,255,0.7);
}
.ob__progress-step--done .ob__progress-dot {
  background: #4caf50;
  border-color: #4caf50;
  width: 16px;
  height: 16px;
}
.ob__progress-line {
  width: 60px;
  height: 1px;
  background: rgba(255,255,255,0.1);
  margin: 0 .5rem;
  margin-bottom: 1.1rem;
  transition: background .3s;
}
.ob__progress-line--done { background: rgba(76,175,80,0.5); }

/* ── Transición ────────────────────────────── */
.ob-fade-enter-active,
.ob-fade-leave-active { transition: opacity .25s ease, transform .25s ease; }
.ob-fade-enter-from   { opacity: 0; transform: translateY(12px); }
.ob-fade-leave-to     { opacity: 0; transform: translateY(-8px); }
</style>
