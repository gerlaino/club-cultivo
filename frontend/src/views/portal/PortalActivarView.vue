<template>
  <!-- El link que le manda la organización (o el de «me olvidé la clave»), 27-oct-2026. Muestra de
       quién es, pide su DNI y la clave que elige, y lo deja adentro. El link sirve una vez. -->
  <div class="herbario hb-pagina">
    <div class="pa__col">
      <div class="hb-ficha">
        <div v-if="cargandoLink" class="pa__cargando"><DsSpinner :size="28" /></div>

        <template v-else-if="link">
          <img v-if="link.organizacion.logo_url" :src="link.organizacion.logo_url" alt="" class="pa__logo" />
          <span v-else class="pa__logo pa__logo--ini" aria-hidden="true">{{ inicial }}</span>
          <p class="hb-ceja">{{ link.organizacion.nombre }}</p>
          <h1 class="hb-titulo">Hola, {{ link.nombre }}</h1>
          <p class="hb-bajada" data-testid="activar-organizacion">
            <template v-if="esInvitacion">Activá tu portal de paciente de <strong>{{ link.organizacion.nombre }}</strong>: confirmá tu DNI y elegí tu clave.</template>
            <template v-else>Elegí una clave nueva para tu portal de <strong>{{ link.organizacion.nombre }}</strong>. Confirmá tu DNI.</template>
          </p>

          <form class="hb-form" novalidate @submit.prevent="activar">
            <div class="hb-campo">
              <label class="hb-label" for="pa-dni">Tu DNI</label>
              <input id="pa-dni" v-model.trim="dni" class="hb-input" inputmode="numeric" autocomplete="username"
                     placeholder="Sin puntos ni espacios" :disabled="enviando" required />
            </div>
            <div class="hb-campo">
              <label class="hb-label" for="pa-clave">Elegí tu clave</label>
              <input id="pa-clave" v-model="clave" type="password" class="hb-input" autocomplete="new-password"
                     :disabled="enviando" required aria-describedby="pa-clave-ayuda" />
              <p id="pa-clave-ayuda" class="hb-ayuda" :class="{ 'pa__ok': clave.length >= MINIMO }">
                {{ clave.length >= MINIMO ? 'Bien: tiene 8 caracteres o más.' : 'Al menos 8 caracteres.' }}
              </p>
            </div>
            <div class="hb-campo">
              <label class="hb-label" for="pa-clave2">Repetila</label>
              <input id="pa-clave2" v-model="confirmacion" type="password" class="hb-input" autocomplete="new-password"
                     :disabled="enviando" required />
            </div>

            <Transition name="err"><div v-if="error" class="hb-error" role="alert">{{ error }}</div></Transition>

            <button class="hb-btn" type="submit" :disabled="enviando || !puedeEnviar">
              <DsSpinner v-if="enviando" :size="18" />
              <span v-else>{{ esInvitacion ? 'Activar y entrar' : 'Guardar la clave y entrar' }}</span>
            </button>
          </form>
          <p class="hb-pie">De ahora en más entrás a {{ link.organizacion.nombre }} con tu DNI y esta clave.</p>
        </template>

        <!-- El link no sirve (venció, ya se usó, hay uno más nuevo o no existe) -->
        <template v-else>
          <p class="hb-ceja">{{ organizacion?.nombre || 'Portal del paciente' }}</p>
          <h1 class="hb-titulo">Este link no sirve</h1>
          <p class="hb-bajada">{{ error }}</p>
          <RouterLink :to="organizacion?.slug ? `/paciente/${organizacion.slug}` : '/paciente'" class="hb-btn pa__ir">Entrar con mi DNI</RouterLink>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { linkPortal } from '../../lib/api'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { cargarFuentesHerbario } from '../../lib/fuentesHerbario.js'
import '../../assets/herbario.css'

const MINIMO = 8
const route = useRoute()
const auth = useAuthStore()
cargarFuentesHerbario()

const token = String(route.params.token || '')
const cargandoLink = ref(true)
const link = ref(null)
const organizacion = ref(null)
const dni = ref('')
const clave = ref('')
const confirmacion = ref('')
const enviando = ref(false)
const error = ref(null)

const esInvitacion = computed(() => link.value?.motivo === 'invitacion')
const inicial = computed(() => (link.value?.organizacion?.nombre || '?').trim().charAt(0).toUpperCase())
const puedeEnviar = computed(() => dni.value && clave.value.length >= MINIMO && confirmacion.value)

onMounted(async () => {
  try {
    const { data } = await linkPortal(token)
    link.value = data
  } catch (e) {
    organizacion.value = e?.response?.data?.organizacion || null
    error.value = e?.response?.data?.error || 'No pudimos abrir el link. Revisá tu conexión y volvé a probar.'
  } finally {
    cargandoLink.value = false
  }
})

async function activar() {
  if (enviando.value) return
  if (clave.value !== confirmacion.value) {
    error.value = 'Las dos claves no son iguales.'
    return
  }
  enviando.value = true
  error.value = null
  try {
    await auth.activarPortalPaciente(token, dni.value, clave.value, confirmacion.value)
  } catch (e) {
    const status = e?.response?.status
    const msg = e?.response?.data?.error
    if (status === 410) {
      // Se cayó (5 DNI equivocados) o venció mientras tanto: la pantalla pasa a «no sirve».
      link.value = null
      error.value = msg
    } else if (status === 429) {
      error.value = 'Hiciste muchos intentos seguidos. Esperá unos minutos y probá de nuevo.'
    } else {
      error.value = msg || 'No pudimos guardar tu clave. Probá de nuevo.'
    }
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
.pa__col { width: 100%; max-width: 446px; display: flex; flex-direction: column; align-items: center; }
.pa__cargando { display: grid; place-items: center; min-height: 220px; }
.pa__logo { width: 64px; height: 64px; border-radius: 18px; object-fit: cover; margin: 0 auto 6px; display: block; }
.pa__logo--ini { display: grid; place-items: center; background: var(--hb-verde); color: var(--hb-papel-claro); font: 700 26px var(--hb-serif); }
.pa__ok { color: var(--hb-verde); }
.pa__ir { text-decoration: none; text-align: center; margin-top: 8px; }

.err-enter-active, .err-leave-active { transition: all .2s; }
.err-enter-from, .err-leave-to { opacity: 0; transform: translateY(-4px); }
</style>
