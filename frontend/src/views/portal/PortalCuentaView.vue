<template>
  <div class="pcv">
    <header class="pcv__hd">
      <h1 class="pcv__title">Mi cuenta</h1>
      <p class="pcv__sub">Cómo entrás, tu contraseña y la salida.</p>
    </header>

    <!-- El usuario interno (`…@<org>.paciente`) no se muestra: el paciente entra con su DNI y no
         lo usa nunca. Mostrarlo como «tu usuario» confundía. -->
    <section class="pcv__bloque">
      <h2 class="pcv__h2">Cómo entrás</h2>
      <p class="pcv__nota pcv__nota--arriba" data-testid="cuenta-puerta">
        En <strong>{{ puertaTexto }}</strong> con tu DNI y tu contraseña.
      </p>
    </section>

    <section class="pcv__bloque">
      <h2 class="pcv__h2">Cambiar la contraseña</h2>
      <p class="pcv__nota">
        Si entraste con la contraseña que te dieron, cambiala por una tuya.
      </p>

      <form class="pcv__form" @submit.prevent="cambiar">
        <label class="pcv__campo">
          <span class="pcv__campo-lbl">Contraseña actual</span>
          <input v-model="actual" type="password" class="pcv__input" autocomplete="current-password" />
        </label>
        <label class="pcv__campo">
          <span class="pcv__campo-lbl">Contraseña nueva</span>
          <input v-model="nueva" type="password" class="pcv__input" autocomplete="new-password" />
          <span class="pcv__hint">Al menos 6 caracteres.</span>
        </label>
        <label class="pcv__campo">
          <span class="pcv__campo-lbl">Repetila</span>
          <input v-model="repetida" type="password" class="pcv__input" autocomplete="new-password" />
        </label>

        <p v-if="error" class="pcv__error">{{ error }}</p>

        <button class="pcv__btn" type="submit" :disabled="guardando || !completo">
          {{ guardando ? 'Guardando…' : 'Cambiar contraseña' }}
        </button>
      </form>
    </section>

    <section class="pcv__bloque">
      <h2 class="pcv__h2">Cerrar sesión</h2>
      <p class="pcv__nota pcv__nota--arriba">
        Si este teléfono o esta compu no es tuyo, cerrá la sesión al terminar.
      </p>
      <button type="button" class="pcv__salir" data-testid="cuenta-salir" :disabled="saliendo" @click="salir">
        {{ saliendo ? 'Cerrando…' : 'Cerrar sesión' }}
      </button>
    </section>
  </div>
</template>

<script setup>
// El paciente cambia SU contraseña, dentro de su portal.
//
// Va acá y no en `/perfil` a propósito: esa pantalla vive en el shell de administración, y un
// paciente que la abre aterriza en la barra lateral de la organización — ve una app que no es la
// suya. El endpoint es el mismo que usa todo el equipo.
import { ref, computed } from 'vue'
import { storeToRefs } from 'pinia'
import { updateMyPassword } from '@/lib/api'
import { useAuthStore } from '@/stores/auth'
import { usePortalClubStore } from '@/stores/portalClub'
import { useToast } from '@/composables/useToast'

const auth  = useAuthStore()
const toast = useToast()
const { club } = storeToRefs(usePortalClubStore())

const puertaTexto = computed(() => `${window.location.host}/paciente${club.value?.slug ? `/${club.value.slug}` : ''}`)

const saliendo = ref(false)
async function salir() {
  saliendo.value = true
  await auth.logOut()
}

const actual    = ref('')
const nueva     = ref('')
const repetida  = ref('')
const guardando = ref(false)
const error     = ref(null)

const completo = computed(() => actual.value && nueva.value && repetida.value)

async function cambiar() {
  error.value = null
  // Se compara acá además del backend: mandar la petición para que vuelva con "no coinciden" es
  // hacerle esperar por algo que ya se sabe.
  if (nueva.value !== repetida.value) {
    error.value = 'Las dos contraseñas nuevas no coinciden.'
    return
  }

  guardando.value = true
  try {
    await updateMyPassword({
      current_password: actual.value,
      password: nueva.value,
      password_confirmation: repetida.value,
    })
    actual.value = nueva.value = repetida.value = ''
    toast.success('Listo, tu contraseña quedó cambiada.')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'No pudimos cambiarla. Probá de nuevo.'
  } finally {
    guardando.value = false
  }
}
</script>

<style scoped>
.pcv { max-width: 520px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }
.pcv__hd { margin-bottom: 1.75rem; }
.pcv__title { font-size: 1.5rem; font-weight: 800; color: var(--p-tinta); margin: 0 0 .25rem; }
.pcv__sub { color: var(--p-suave); font-size: .9rem; margin: 0; }

.pcv__bloque {
  border: 1px solid var(--p-linea); border-radius: 12px; padding: 1.25rem; margin-bottom: 1rem;
  background: #fff;
}
.pcv__h2 { font-size: 1rem; font-weight: 700; color: var(--p-tinta); margin: 0 0 .35rem; }

.pcv__nota { font-size: .82rem; color: var(--p-suave); margin: .8rem 0 0; line-height: 1.55; }
.pcv__nota--arriba { margin-top: .35rem; }
.pcv__salir {
  margin-top: 1rem; background: none; color: var(--p-urgente); border: 1px solid currentColor;
  border-radius: 8px; padding: .55rem 1.1rem; font-size: .9rem; font-weight: 600; cursor: pointer;
}
.pcv__salir:disabled { opacity: .5; cursor: default; }

.pcv__form { display: flex; flex-direction: column; gap: .9rem; margin-top: 1.1rem; }
.pcv__campo { display: flex; flex-direction: column; gap: .3rem; }
.pcv__campo-lbl { font-size: .82rem; font-weight: 600; color: var(--p-tinta); }
.pcv__input {
  border: 1px solid var(--p-linea); border-radius: 8px; padding: .55rem .7rem; font-size: .92rem;
  background: #fff; color: var(--p-tinta);
}
.pcv__input:focus { outline: 2px solid var(--p-marca-linea); outline-offset: 1px; border-color: var(--p-marca-linea); }
.pcv__hint { font-size: .75rem; color: var(--p-suave); }
.pcv__error { color: var(--p-urgente); font-size: .85rem; margin: 0; }

.pcv__btn {
  align-self: flex-start; background: var(--p-marca); color: #fff; border: none;
  border-radius: 8px; padding: .55rem 1.1rem; font-size: .9rem; font-weight: 600; cursor: pointer;
}
.pcv__btn:hover:not(:disabled) { background: var(--p-marca-fuerte); }
.pcv__btn:disabled { opacity: .5; cursor: default; }
</style>
