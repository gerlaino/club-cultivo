<script setup>
// Cartel a pantalla completa cuando la organización está suspendida.
//
// El backend responde 403 a TODA la API, así que sin esto la app se convertía en una sucesión
// de pantallas vacías y errores sueltos, y quien la usaba no tenía forma de saber por qué.
//
// Lo que más importa del texto es la última línea: un 403 pelado —o un "no autorizado"— le hace
// creer al club que perdió su información. No la perdió, y hay que decírselo.
import { ref, computed } from 'vue'
import { useAuthStore } from '../stores/auth'
import { reenviarConfirmacion } from '../lib/api.js'

const auth = useAuthStore()

// Qué pasó y qué hacer, según el motivo que cargó la plataforma al suspender. Sin motivo (una
// suspensión vieja) queda el texto genérico.
const TEXTOS = {
  no_pago:            'El plan de la organización está impago. Apenas se regularice, el acceso vuelve completo.',
  lo_pidio:           'La organización pidió pausar el acceso. Para retomarlo, avisá a Cultivo Espacial.',
  prueba_terminada:   'El período de prueba terminó. Para seguir usando la app, hablá con Cultivo Espacial.',
  mail_sin_confirmar: 'Falta confirmar tu mail. Tocá el link del mail que te mandamos y la cuenta vuelve sola.',
}
const detalle = computed(() => TEXTOS[auth.clubSuspendidoMotivo] || null)

// Uso personal: es la cuenta de UNA persona, no «la organización». Y si se pausó por el mail, lo
// que corresponde es reenviar el link, no escribirle a soporte.
const personal = computed(() => auth.clubSuspendidoPersonal)
const porMail  = computed(() => auth.clubSuspendidoMotivo === 'mail_sin_confirmar')
const titulo   = computed(() => {
  if (porMail.value) return 'Confirmá tu mail para seguir'
  if (personal.value && auth.clubSuspendidoMotivo === 'prueba_terminada') return 'Terminó tu prueba gratis'
  return personal.value ? 'Tu cuenta está pausada' : 'Organización suspendida'
})
const reenviado = ref(false)
async function reenviar() {
  try { await reenviarConfirmacion(auth.clubSuspendidoEmail) } catch {}
  reenviado.value = true
}

async function salir() {
  try { await auth.logout() } catch {}
  window.location.href = '/login'
}
</script>

<template>
  <div class="susp">
    <div class="susp__card">
      <img src="/logo-ce-redondo.png" alt="" class="susp__logo" />
      <h1 class="susp__title">{{ titulo }}</h1>
      <p v-if="!porMail" class="susp__text">
        {{ personal ? 'Tu cuenta está pausada por ahora' : 'El acceso de tu organización está temporalmente suspendido' }},
        así que las secciones de la app no van a responder.
      </p>
      <p v-if="detalle" class="susp__text susp__text--motivo">{{ detalle }}</p>
      <template v-if="porMail && auth.clubSuspendidoEmail">
        <p class="susp__text">Lo mandamos a <strong>{{ auth.clubSuspendidoEmail }}</strong>. Si no lo encontrás, revisá en Spam.</p>
        <button v-if="!reenviado" class="susp__btn susp__btn--sec" @click="reenviar">Mandarme el link de nuevo</button>
        <p v-else class="susp__text">Listo, te lo mandamos de nuevo.</p>
      </template>
      <p v-else class="susp__text">
        Ante cualquier duda, escribinos a <a href="mailto:cultivoespacial.arg@gmail.com">cultivoespacial.arg@gmail.com</a>
        o desde <a href="/bienvenida#contacto">la página de Cultivo Espacial</a>.
      </p>
      <p class="susp__resguardo">
        <i class="bi bi-shield-check"></i>
        {{ personal ? 'Todo lo que cargaste está resguardado' : 'Toda la información de tu organización está resguardada' }}.
        No se borró nada y vuelve completa apenas se reactive el acceso.
      </p>
      <button class="susp__btn" @click="salir">Cerrar sesión</button>
    </div>
  </div>
</template>

<style scoped>
.susp { position: fixed; inset: 0; z-index: 3000; display: grid; place-items: center; padding: 1.5rem; background: #14251a; }
.susp__card { width: min(480px, 100%); background: #fff; border-radius: 16px; padding: 2rem 1.75rem; text-align: center; box-shadow: 0 24px 60px rgb(0 0 0 / .35); }
.susp__logo { width: 56px; height: 56px; border-radius: 50%; object-fit: cover; margin-bottom: 1rem; }
.susp__title { margin: 0 0 .75rem; font-size: 1.25rem; font-weight: 800; color: #0f172a; letter-spacing: -.01em; }
.susp__text { margin: 0 0 .6rem; font-size: .9rem; color: #475569; line-height: 1.6; }
.susp__text--motivo { color: #0f172a; font-weight: 600; }
.susp__resguardo { display: flex; align-items: flex-start; gap: .5rem; text-align: left; margin: 1.1rem 0 1.4rem; padding: .75rem .9rem; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; font-size: .82rem; color: #15803d; line-height: 1.55; }
.susp__resguardo i { flex-shrink: 0; margin-top: .1rem; }
.susp__btn { background: #1b5e20; color: #fff; border: none; border-radius: 9px; padding: .6rem 1.4rem; font-size: .875rem; font-weight: 700; cursor: pointer; }
.susp__btn:hover { background: #144a18; }
.susp__btn--sec { background: transparent; color: #1b5e20; border: 1.5px solid #1b5e20; margin-bottom: .6rem; }
.susp__btn--sec:hover { background: #f0fdf4; }
</style>
