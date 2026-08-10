<template>
  <div class="iwa">

    <!-- Card de estado -->
    <div class="iwa__card" :class="configurado ? 'iwa__card--ok' : 'iwa__card--pending'">
      <div class="iwa__card-left">
        <div class="iwa__icon">
          <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/>
            <path d="M12 0C5.374 0 0 5.373 0 12c0 2.117.549 4.107 1.508 5.84L.058 23.765a.5.5 0 0 0 .614.634l6.109-1.598A11.94 11.94 0 0 0 12 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 21.932a9.91 9.91 0 0 1-5.064-1.388l-.362-.215-3.755.982 1.001-3.645-.236-.376A9.867 9.867 0 0 1 2.068 12C2.068 6.517 6.517 2.068 12 2.068S21.932 6.517 21.932 12 17.483 21.932 12 21.932z"/>
          </svg>
        </div>
        <div>
          <div class="iwa__card-title">WhatsApp Business</div>
          <div class="iwa__card-sub">
            <template v-if="configurado">
              Activo · <span class="iwa__number">{{ data.twilio_whatsapp_from }}</span>
            </template>
            <template v-else>
              Notificá a tus socios cuando el delivery salga o entregue su paquete
            </template>
          </div>
        </div>
      </div>
      <div class="iwa__card-right">
        <div class="iwa__badge" :class="configurado ? 'iwa__badge--ok' : 'iwa__badge--off'">
          {{ configurado ? '● Activo' : '○ No configurado' }}
        </div>
        <button v-if="!showWizard" class="iwa__btn-config" @click="abrirWizard">
          {{ configurado ? 'Editar' : 'Configurar →' }}
        </button>
        <button v-if="configurado && !showWizard" class="iwa__btn-danger" @click="confirmarEliminar">
          Desactivar
        </button>
      </div>
    </div>

    <!-- Wizard -->
    <Transition name="iwa-slide">
      <div v-if="showWizard" class="iwa__wizard">

        <!-- Steps nav -->
        <div class="iwa__steps">
          <div
            v-for="(s, i) in STEPS"
            :key="i"
            class="iwa__step"
            :class="{
              'iwa__step--active': step === i,
              'iwa__step--done': step > i
            }"
          >
            <div class="iwa__step-dot">
              <span v-if="step > i" class="iwa__step-check">✓</span>
              <span v-else>{{ i + 1 }}</span>
            </div>
            <span class="iwa__step-label">{{ s.label }}</span>
          </div>
        </div>

        <!-- Step content -->
        <div class="iwa__step-body">

          <!-- Paso 1: Crear cuenta -->
          <div v-if="step === 0" class="iwa__pane">
            <div class="iwa__pane-icon">🚀</div>
            <h3 class="iwa__pane-title">Creá tu cuenta Twilio</h3>
            <p class="iwa__pane-text">
              Twilio es el servicio que usaremos para enviar mensajes de WhatsApp.
              La creación de cuenta es gratuita y el costo por mensaje es muy bajo (fracciones de centavo).
              <strong>Cada organización tiene su propia cuenta</strong> — los mensajes van desde tu número, con el nombre de tu organización.
            </p>
            <div class="iwa__step-actions">
              <a href="https://www.twilio.com/try-twilio" target="_blank" rel="noopener" class="iwa__btn-primary">
                Crear cuenta gratuita en Twilio →
              </a>
            </div>
            <p class="iwa__pane-hint">Si ya tenés cuenta, pasá al siguiente paso.</p>
          </div>

          <!-- Paso 2: Activar WhatsApp -->
          <div v-if="step === 1" class="iwa__pane">
            <div class="iwa__pane-icon">💬</div>
            <h3 class="iwa__pane-title">Activá WhatsApp Business</h3>
            <p class="iwa__pane-text">
              Dentro de tu cuenta Twilio, necesitás activar un número de WhatsApp Business.
              Podés empezar con el <strong>Sandbox de WhatsApp</strong> para probar (gratis), o solicitar
              un <strong>número de producción aprobado por Meta</strong> para uso real.
            </p>
            <div class="iwa__guide-steps">
              <div class="iwa__guide-step">
                <span class="iwa__guide-n">1</span>
                <span>En Twilio Console, andá a <strong>Messaging → Try it out → WhatsApp</strong></span>
              </div>
              <div class="iwa__guide-step">
                <span class="iwa__guide-n">2</span>
                <span>Seguí los pasos para activar tu número de WhatsApp Business</span>
              </div>
              <div class="iwa__guide-step">
                <span class="iwa__guide-n">3</span>
                <span>Anotá el número asignado (empieza con <code>+1</code> o el que te den)</span>
              </div>
            </div>
            <div class="iwa__step-actions">
              <a href="https://console.twilio.com/us1/develop/sms/try-it-out/whatsapp-learn" target="_blank" rel="noopener" class="iwa__btn-secondary">
                Ir a Twilio WhatsApp →
              </a>
            </div>
          </div>

          <!-- Paso 3: Copiar credenciales -->
          <div v-if="step === 2" class="iwa__pane">
            <div class="iwa__pane-icon">🔑</div>
            <h3 class="iwa__pane-title">Copiá tus credenciales</h3>
            <p class="iwa__pane-text">
              Estos 3 datos los encontrás en tu Twilio Console. Los vas a necesitar en el siguiente paso.
            </p>
            <div class="iwa__creds-guide">
              <div class="iwa__cred-item">
                <div class="iwa__cred-name">Account SID</div>
                <div class="iwa__cred-desc">
                  En la página principal del Console. Empieza con <code>AC...</code>
                </div>
              </div>
              <div class="iwa__cred-item">
                <div class="iwa__cred-name">Auth Token</div>
                <div class="iwa__cred-desc">
                  Abajo del Account SID, hacé click en el <strong>candado 🔒</strong> para verlo.
                </div>
              </div>
              <div class="iwa__cred-item">
                <div class="iwa__cred-name">Número WhatsApp</div>
                <div class="iwa__cred-desc">
                  El número que activaste en WhatsApp Business. Formato: <code>whatsapp:+14155238886</code>
                </div>
              </div>
            </div>
            <div class="iwa__step-actions">
              <a href="https://console.twilio.com" target="_blank" rel="noopener" class="iwa__btn-secondary">
                Abrir Twilio Console →
              </a>
            </div>
          </div>

          <!-- Paso 4: Ingresar y verificar -->
          <div v-if="step === 3" class="iwa__pane">
            <div class="iwa__pane-icon">✅</div>
            <h3 class="iwa__pane-title">Ingresá tus datos y verificá</h3>

            <div class="iwa__form">
              <div class="iwa__field">
                <label class="iwa__label">
                  Account SID
                  <span class="iwa__tooltip-wrap">
                    <span class="iwa__help">?</span>
                    <span class="iwa__tooltip">Empieza con "AC". Lo encontrás en la página principal de Twilio Console.</span>
                  </span>
                </label>
                <input
                  v-model.trim="form.account_sid"
                  class="iwa__input"
                  placeholder="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                  autocomplete="off"
                />
              </div>

              <div class="iwa__field">
                <label class="iwa__label">
                  Auth Token
                  <span class="iwa__tooltip-wrap">
                    <span class="iwa__help">?</span>
                    <span class="iwa__tooltip">Token secreto de Twilio. Hacé click en el candado en el Console para verlo.</span>
                  </span>
                </label>
                <div class="iwa__input-wrap">
                  <input
                    v-model.trim="form.auth_token"
                    :type="showToken ? 'text' : 'password'"
                    class="iwa__input iwa__input--token"
                    placeholder="••••••••••••••••••••••••••••••••"
                    autocomplete="off"
                  />
                  <button type="button" class="iwa__toggle-vis" @click="showToken = !showToken">
                    {{ showToken ? 'Ocultar' : 'Ver' }}
                  </button>
                </div>
                <p v-if="configurado" class="iwa__hint">Dejá vacío para mantener el token actual.</p>
              </div>

              <div class="iwa__field">
                <label class="iwa__label">
                  Número WhatsApp
                  <span class="iwa__tooltip-wrap">
                    <span class="iwa__help">?</span>
                    <span class="iwa__tooltip">El número que activaste en Twilio. Debe incluir el prefijo "whatsapp:" y el código de país.</span>
                  </span>
                </label>
                <input
                  v-model.trim="form.whatsapp_from"
                  class="iwa__input"
                  placeholder="whatsapp:+14155238886"
                  autocomplete="off"
                />
                <p class="iwa__hint">Formato exacto: <code>whatsapp:+14155238886</code></p>
              </div>
            </div>

            <div v-if="errorMsg" class="iwa__error">
              <span>⚠️ {{ errorMsg }}</span>
            </div>
            <div v-if="testOk" class="iwa__success">
              <span>✅ {{ testOk }}</span>
            </div>

            <div class="iwa__form-actions">
              <button
                class="iwa__btn-test"
                :disabled="!formValido || testing"
                @click="probarConexion"
              >
                <span v-if="testing">Enviando prueba…</span>
                <span v-else>Probar conexión (te mando un WhatsApp)</span>
              </button>
              <button
                class="iwa__btn-save"
                :disabled="!formValido || saving"
                @click="guardar"
              >
                <span v-if="saving">Guardando…</span>
                <span v-else>Guardar configuración</span>
              </button>
            </div>
          </div>

        </div>

        <!-- Wizard footer nav -->
        <div class="iwa__wizard-footer">
          <button class="iwa__btn-ghost" @click="cerrarWizard">Cancelar</button>
          <div class="iwa__nav-btns">
            <button v-if="step > 0" class="iwa__btn-ghost" @click="step--">← Anterior</button>
            <button v-if="step < 3" class="iwa__btn-next" @click="step++">Siguiente →</button>
          </div>
        </div>

      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { updateTwilio, destroyTwilio, testTwilio } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props  = defineProps({ data: { type: Object, required: true } })
const emit   = defineEmits(['updated'])
const toast  = useToast()

const STEPS = [
  { label: 'Crear cuenta' },
  { label: 'Activar WhatsApp' },
  { label: 'Credenciales' },
  { label: 'Verificar' },
]

const showWizard = ref(false)
const step       = ref(0)
const showToken  = ref(false)
const saving     = ref(false)
const testing    = ref(false)
const errorMsg   = ref(null)
const testOk     = ref(null)

const form = ref({ account_sid: '', auth_token: '', whatsapp_from: '' })

const configurado = computed(() => props.data?.twilio_configurado)

const formValido = computed(() =>
  form.value.account_sid.trim() &&
  (form.value.auth_token.trim() || configurado.value) &&
  form.value.whatsapp_from.trim()
)

function abrirWizard() {
  form.value = {
    account_sid:   props.data?.twilio_account_sid   || '',
    auth_token:    '',
    whatsapp_from: props.data?.twilio_whatsapp_from || '',
  }
  step.value      = configurado.value ? 3 : 0
  errorMsg.value  = null
  testOk.value    = null
  showWizard.value = true
}

function cerrarWizard() {
  showWizard.value = false
  errorMsg.value   = null
  testOk.value     = null
}

async function guardar() {
  errorMsg.value = null
  testOk.value   = null
  saving.value   = true
  try {
    const payload = {
      twilio_account_sid:   form.value.account_sid,
      twilio_whatsapp_from: form.value.whatsapp_from,
    }
    if (form.value.auth_token.trim()) payload.twilio_auth_token = form.value.auth_token
    const { data } = await updateTwilio(payload)
    emit('updated', data)
    toast.success('Configuración de WhatsApp guardada')
    cerrarWizard()
  } catch (e) {
    errorMsg.value = e.response?.data?.errors?.join(', ') || e.response?.data?.error || 'Error al guardar'
  } finally {
    saving.value = false
  }
}

async function probarConexion() {
  if (!formValido.value) return
  errorMsg.value = null
  testOk.value   = null

  // Guarda primero, luego prueba
  saving.value = true
  try {
    const payload = {
      twilio_account_sid:   form.value.account_sid,
      twilio_whatsapp_from: form.value.whatsapp_from,
    }
    if (form.value.auth_token.trim()) payload.twilio_auth_token = form.value.auth_token
    await updateTwilio(payload)
  } catch (e) {
    errorMsg.value = e.response?.data?.errors?.join(', ') || e.response?.data?.error || 'Error al guardar'
    saving.value = false
    return
  } finally {
    saving.value = false
  }

  testing.value = true
  try {
    const { data } = await testTwilio()
    testOk.value = `Mensaje enviado a ${data.enviado_a}. ¡Revisá tu WhatsApp!`
    emit('updated', { twilio_configurado: true, twilio_account_sid: form.value.account_sid, twilio_whatsapp_from: form.value.whatsapp_from })
  } catch (e) {
    errorMsg.value = e.response?.data?.error || 'No se pudo enviar el mensaje de prueba'
  } finally {
    testing.value = false
  }
}

async function confirmarEliminar() {
  if (!confirm('¿Desactivar WhatsApp? Los mensajes de delivery volverán a enviarse por email.')) return
  try {
    await destroyTwilio()
    emit('updated', { twilio_configurado: false, twilio_account_sid: null, twilio_whatsapp_from: null })
    toast.success('WhatsApp desactivado')
  } catch {
    toast.error('Error al desactivar')
  }
}
</script>

<style scoped>
.iwa { display: flex; flex-direction: column; gap: 0; }

/* Card */
.iwa__card {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  padding: 1.1rem 1.25rem; border-radius: 12px; border: 1.5px solid #e5e7eb;
  background: #fff; transition: border-color .15s;
  flex-wrap: wrap;
}
.iwa__card--ok     { border-color: #bbf7d0; background: #f0fdf4; }
.iwa__card--pending { border-color: #e5e7eb; }
.iwa__card-left { display: flex; align-items: center; gap: .875rem; }
.iwa__icon {
  width: 40px; height: 40px; background: #25d366; color: #fff;
  border-radius: 10px; display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.iwa__card-title { font-size: .9rem; font-weight: 700; color: #111827; }
.iwa__card-sub   { font-size: .78rem; color: #6b7280; margin-top: .1rem; }
.iwa__number     { font-family: monospace; color: #15803d; font-weight: 600; }
.iwa__card-right { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.iwa__badge { font-size: .72rem; font-weight: 700; padding: .2rem .6rem; border-radius: 99px; }
.iwa__badge--ok  { background: #dcfce7; color: #15803d; }
.iwa__badge--off { background: var(--c-slate-100); color: #6b7280; }
.iwa__btn-config {
  padding: .45rem .9rem; background: #15803d; color: #fff; border: none;
  border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer;
}
.iwa__btn-config:hover { background: #166534; }
.iwa__btn-danger {
  padding: .45rem .9rem; background: #fff; color: #dc2626; border: 1px solid #fca5a5;
  border-radius: 8px; font-size: .8rem; font-weight: 500; cursor: pointer;
}
.iwa__btn-danger:hover { background: #fef2f2; }

/* Wizard */
.iwa__wizard {
  border: 1.5px solid #e5e7eb; border-top: none; border-radius: 0 0 12px 12px;
  background: #fff; overflow: hidden;
}

/* Steps nav */
.iwa__steps {
  display: flex; border-bottom: 1px solid var(--c-slate-100);
  background: #f9fafb; padding: 1rem 1.5rem; gap: .5rem; overflow-x: auto;
}
.iwa__step { display: flex; align-items: center; gap: .5rem; flex: 1; min-width: 0; }
.iwa__step:not(:last-child)::after {
  content: ''; flex: 1; height: 1px; background: #e5e7eb; min-width: 12px;
}
.iwa__step-dot {
  width: 24px; height: 24px; border-radius: 50%; border: 2px solid #d1d5db;
  display: flex; align-items: center; justify-content: center;
  font-size: .7rem; font-weight: 700; color: #9ca3af; flex-shrink: 0;
  background: #fff; transition: all .2s;
}
.iwa__step--active .iwa__step-dot  { border-color: #15803d; color: #15803d; background: #f0fdf4; }
.iwa__step--done   .iwa__step-dot  { border-color: #15803d; background: #15803d; color: #fff; }
.iwa__step-label { font-size: .72rem; font-weight: 600; color: #9ca3af; white-space: nowrap; }
.iwa__step--active .iwa__step-label { color: #15803d; }
.iwa__step--done   .iwa__step-label { color: #374151; }
.iwa__step-check { font-size: .75rem; }

/* Pane */
.iwa__step-body { min-height: 280px; }
.iwa__pane { padding: 1.75rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.iwa__pane-icon  { font-size: 2rem; }
.iwa__pane-title { font-size: 1rem; font-weight: 700; color: #111827; margin: 0; }
.iwa__pane-text  { font-size: .875rem; color: #374151; line-height: 1.6; margin: 0; }
.iwa__pane-hint  { font-size: .75rem; color: #9ca3af; margin: 0; }

.iwa__step-actions { display: flex; gap: .75rem; flex-wrap: wrap; }
.iwa__btn-primary {
  display: inline-flex; align-items: center; padding: .55rem 1.1rem;
  background: #15803d; color: #fff; border-radius: 8px; font-size: .85rem; font-weight: 600;
  text-decoration: none; border: none; cursor: pointer;
}
.iwa__btn-primary:hover { background: #166534; }
.iwa__btn-secondary {
  display: inline-flex; align-items: center; padding: .55rem 1.1rem;
  background: #fff; color: #374151; border: 1.5px solid #d1d5db; border-radius: 8px;
  font-size: .85rem; font-weight: 600; text-decoration: none;
}
.iwa__btn-secondary:hover { background: #f9fafb; }

/* Guide steps */
.iwa__guide-steps { display: flex; flex-direction: column; gap: .6rem; }
.iwa__guide-step  { display: flex; align-items: flex-start; gap: .6rem; font-size: .85rem; color: #374151; }
.iwa__guide-n {
  width: 20px; height: 20px; background: #e0f2fe; color: #0284c7; border-radius: 50%;
  display: flex; align-items: center; justify-content: center; font-size: .7rem; font-weight: 700;
  flex-shrink: 0; margin-top: .05rem;
}

/* Creds guide */
.iwa__creds-guide  { display: flex; flex-direction: column; gap: .6rem; }
.iwa__cred-item    { background: #f9fafb; border-radius: 8px; padding: .75rem 1rem; }
.iwa__cred-name    { font-size: .8rem; font-weight: 700; color: #111827; margin-bottom: .2rem; }
.iwa__cred-desc    { font-size: .78rem; color: #6b7280; line-height: 1.4; }
code { background: var(--c-slate-100); padding: .1em .35em; border-radius: 4px; font-size: .8em; color: #374151; }

/* Form */
.iwa__form  { display: flex; flex-direction: column; gap: .875rem; }
.iwa__field { display: flex; flex-direction: column; gap: .3rem; }
.iwa__label {
  font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase;
  letter-spacing: .04em; display: flex; align-items: center; gap: .4rem;
}
.iwa__input {
  padding: .55rem .8rem; border: 1.5px solid #d1d5db; border-radius: 8px;
  font-size: .875rem; color: #111827; background: #fff; width: 100%; box-sizing: border-box;
}
.iwa__input:focus { outline: none; border-color: #15803d; box-shadow: 0 0 0 2px #dcfce7; }
.iwa__input-wrap { position: relative; display: flex; }
.iwa__input--token { flex: 1; padding-right: 4.5rem; }
.iwa__toggle-vis {
  position: absolute; right: .5rem; top: 50%; transform: translateY(-50%);
  background: none; border: none; font-size: .75rem; color: #6b7280; cursor: pointer;
  padding: .2rem .4rem;
}
.iwa__toggle-vis:hover { color: #374151; }
.iwa__hint { font-size: .72rem; color: #9ca3af; margin: 0; }

/* Tooltip */
.iwa__tooltip-wrap { position: relative; display: inline-flex; align-items: center; }
.iwa__help {
  width: 16px; height: 16px; background: #e5e7eb; color: #6b7280; border-radius: 50%;
  font-size: .65rem; font-weight: 700; display: flex; align-items: center; justify-content: center;
  cursor: default; flex-shrink: 0;
}
.iwa__tooltip {
  display: none; position: absolute; left: 1.5rem; top: -4px; z-index: 10;
  background: #111827; color: #fff; font-size: .72rem; font-weight: 400;
  padding: .4rem .65rem; border-radius: 6px; width: 200px; line-height: 1.4;
  text-transform: none; letter-spacing: 0;
}
.iwa__tooltip-wrap:hover .iwa__tooltip { display: block; }

/* Error / success */
.iwa__error   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .9rem; border-radius: 8px; font-size: .82rem; }
.iwa__success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; padding: .65rem .9rem; border-radius: 8px; font-size: .82rem; }

/* Form actions */
.iwa__form-actions { display: flex; gap: .75rem; flex-wrap: wrap; padding-top: .25rem; }
.iwa__btn-test {
  flex: 1; padding: .55rem 1rem; background: #f0fdf4; color: #15803d;
  border: 1.5px solid #bbf7d0; border-radius: 8px; font-size: .85rem; font-weight: 600; cursor: pointer;
}
.iwa__btn-test:hover:not(:disabled) { background: #dcfce7; }
.iwa__btn-test:disabled { opacity: .45; cursor: not-allowed; }
.iwa__btn-save {
  flex: 1; padding: .55rem 1rem; background: #15803d; color: #fff;
  border: none; border-radius: 8px; font-size: .85rem; font-weight: 600; cursor: pointer;
}
.iwa__btn-save:hover:not(:disabled) { background: #166534; }
.iwa__btn-save:disabled { opacity: .45; cursor: not-allowed; }

/* Wizard footer */
.iwa__wizard-footer {
  display: flex; align-items: center; justify-content: space-between;
  padding: .875rem 1.5rem; border-top: 1px solid var(--c-slate-100); background: #f9fafb;
}
.iwa__nav-btns { display: flex; gap: .5rem; }
.iwa__btn-ghost {
  padding: .5rem .9rem; background: #fff; color: #374151;
  border: 1px solid #d1d5db; border-radius: 8px; font-size: .82rem; font-weight: 500; cursor: pointer;
}
.iwa__btn-ghost:hover { background: #f9fafb; }
.iwa__btn-next {
  padding: .5rem 1rem; background: #111827; color: #fff;
  border: none; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer;
}
.iwa__btn-next:hover { background: #1f2937; }

/* Transition */
.iwa-slide-enter-active, .iwa-slide-leave-active { transition: opacity .2s, transform .2s; }
.iwa-slide-enter-from, .iwa-slide-leave-to { opacity: 0; transform: translateY(-8px); }
</style>
