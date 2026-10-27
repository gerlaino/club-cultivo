<template>
  <!-- La puerta del paciente (27-oct-2026): entra con su DNI y su clave. Es la misma ficha que el
       login del equipo («Herbario»), con lo suyo: DNI en vez de usuario, elegir organización si es
       paciente en más de una, y «me olvidé la clave» que se resuelve solo. -->
  <div class="herbario hb-pagina">
    <button type="button" class="hb-volver" @click="router.push('/bienvenida')">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>
      Volver
    </button>

    <div class="pe__col">
      <div class="hb-ficha">
        <RouterLink to="/bienvenida" class="hb-ficha__logo" aria-label="Volver a la página de inicio">
          <img src="/logo-ce-redondo.png" alt="Cultivo Espacial" />
        </RouterLink>

        <!-- ── Entrar ── -->
        <template v-if="paso === 'entrar'">
          <p class="hb-ceja">Portal del paciente</p>
          <h1 class="hb-titulo">Entrá con tu DNI</h1>

          <form class="hb-form" novalidate @submit.prevent="entrar()">
            <div class="hb-campo">
              <label class="hb-label" for="pe-dni">DNI</label>
              <input id="pe-dni" v-model.trim="dni" class="hb-input" inputmode="numeric" autocomplete="username"
                     placeholder="Sin puntos ni espacios" :disabled="cargando" required />
            </div>
            <div class="hb-campo">
              <label class="hb-label" for="pe-clave">Clave</label>
              <div class="pe__pass">
                <input id="pe-clave" v-model="clave" :type="verClave ? 'text' : 'password'" class="hb-input pe__pass-input"
                       autocomplete="current-password" :disabled="cargando" required />
                <button type="button" class="pe__ojo" :aria-label="verClave ? 'Ocultar la clave' : 'Mostrar la clave'" @click="verClave = !verClave">
                  {{ verClave ? 'Ocultar' : 'Ver' }}
                </button>
              </div>
              <button type="button" class="hb-link pe__olvide" @click="irARecuperar">Me olvidé la clave</button>
            </div>

            <Transition name="err"><div v-if="error" class="hb-error" role="alert">{{ error }}</div></Transition>

            <button class="hb-btn" type="submit" :disabled="cargando || !dni || !clave">
              <DsSpinner v-if="cargando" :size="18" />
              <span v-else>Entrar</span>
            </button>
          </form>

          <p class="hb-pie">¿Es la primera vez? Entrá con el link que te mandó tu organización.</p>
        </template>

        <!-- ── Paciente en más de una organización: elige después de validar ── -->
        <template v-else-if="paso === 'elegir'">
          <p class="hb-ceja">Portal del paciente</p>
          <h1 class="hb-titulo">¿A cuál entrás?</h1>
          <p class="hb-bajada">Sos paciente en más de una organización.</p>
          <div class="pe__orgs">
            <button v-for="o in organizaciones" :key="o.id" type="button" class="pe__org" :disabled="cargando" @click="entrar(o.id)">
              <img v-if="o.logo_url" :src="o.logo_url" alt="" class="pe__org-logo" />
              <span v-else class="pe__org-logo pe__org-logo--ini" :style="{ background: o.theme_primary || undefined }" aria-hidden="true">{{ inicial(o.nombre) }}</span>
              <span class="pe__org-nombre">{{ o.nombre }}</span>
            </button>
          </div>
          <Transition name="err"><div v-if="error" class="hb-error" role="alert">{{ error }}</div></Transition>
          <button type="button" class="hb-link pe__volver" @click="volverAEntrar">Usar otro DNI</button>
        </template>

        <!-- ── Me olvidé la clave ── -->
        <template v-else>
          <p class="hb-ceja">Portal del paciente</p>
          <h1 class="hb-titulo">Elegí una clave nueva</h1>
          <template v-if="!recuperacionEnviada">
            <p class="hb-bajada">Poné tu DNI. Si tenés un mail cargado en tu organización, te mandamos un link para elegirla.</p>
            <form class="hb-form" novalidate @submit.prevent="recuperar">
              <div class="hb-campo">
                <label class="hb-label" for="pe-dni-rec">DNI</label>
                <input id="pe-dni-rec" v-model.trim="dni" class="hb-input" inputmode="numeric" autocomplete="username" :disabled="cargando" required />
              </div>
              <Transition name="err"><div v-if="error" class="hb-error" role="alert">{{ error }}</div></Transition>
              <button class="hb-btn" type="submit" :disabled="cargando || !dni">
                <DsSpinner v-if="cargando" :size="18" />
                <span v-else>Mandarme el link</span>
              </button>
            </form>
          </template>
          <div v-else class="hb-nota" role="status">{{ recuperacionEnviada }}</div>
          <button type="button" class="hb-link pe__volver" @click="volverAEntrar">Volver a entrar</button>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { recuperarPortal } from '../../lib/api'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { cargarFuentesHerbario } from '../../lib/fuentesHerbario.js'
import '../../assets/herbario.css'

const auth = useAuthStore()
const router = useRouter()
cargarFuentesHerbario()

const paso = ref('entrar')            // entrar · elegir · recuperar
const dni = ref('')
const clave = ref('')
const verClave = ref(false)
const cargando = ref(false)
const error = ref(null)
const organizaciones = ref([])
const recuperacionEnviada = ref(null)

function mensajeDe(e, porDefecto) {
  if (!e?.response) return 'No hay conexión con el servidor. Probá de nuevo en un momento.'
  if (e.response.status === 429) return 'Hiciste muchos intentos seguidos. Esperá unos minutos y probá de nuevo.'
  return e.response.data?.error || porDefecto
}

async function entrar(organizacionId = null) {
  if (cargando.value) return
  cargando.value = true
  error.value = null
  try {
    const r = await auth.loginPaciente(dni.value, clave.value, organizacionId)
    if (r?.elegir) {
      organizaciones.value = r.elegir
      paso.value = 'elegir'
    }
  } catch (e) {
    error.value = mensajeDe(e, 'No pudimos hacerte entrar. Probá de nuevo.')
  } finally {
    cargando.value = false
  }
}

function irARecuperar() {
  error.value = null
  recuperacionEnviada.value = null
  paso.value = 'recuperar'
}

function volverAEntrar() {
  error.value = null
  clave.value = ''
  organizaciones.value = []
  paso.value = 'entrar'
}

async function recuperar() {
  cargando.value = true
  error.value = null
  try {
    const { data } = await recuperarPortal(dni.value)
    recuperacionEnviada.value = data.mensaje
  } catch (e) {
    error.value = mensajeDe(e, 'No pudimos mandar el link. Probá de nuevo.')
  } finally {
    cargando.value = false
  }
}

const inicial = (nombre) => (nombre || '?').trim().charAt(0).toUpperCase()
</script>

<style scoped>
.pe__col { width: 100%; max-width: 446px; display: flex; flex-direction: column; align-items: center; }
.pe__pass { position: relative; }
.pe__pass-input { padding-right: 4.6rem; }
.pe__ojo {
  position: absolute; top: 0; right: 0; bottom: 0; padding: 0 .9rem;
  background: none; border: none; color: var(--hb-tinta-2); font: inherit; font-size: .82rem; font-weight: 600; cursor: pointer;
}
.pe__ojo:hover { color: var(--hb-tinta); }
.pe__olvide { align-self: flex-end; margin-top: 2px; font-size: .82rem; background: none; border: 0; padding: 4px 0; cursor: pointer; }
.pe__volver { margin-top: 14px; align-self: center; background: none; border: 0; cursor: pointer; font-size: .9rem; }

.pe__orgs { display: flex; flex-direction: column; gap: 10px; width: 100%; margin-top: 8px; }
.pe__org {
  display: flex; align-items: center; gap: 12px; min-height: 56px; padding: 8px 14px; width: 100%;
  border: 1px solid var(--hb-regla); border-radius: 14px; background: var(--hb-papel-claro); cursor: pointer;
  font: inherit; color: var(--hb-tinta); text-align: left;
}
.pe__org:hover:not(:disabled) { border-color: var(--hb-tinta-2); }
.pe__org-logo { width: 38px; height: 38px; border-radius: 10px; object-fit: cover; flex: none; }
.pe__org-logo--ini { display: grid; place-items: center; background: var(--hb-verde); color: var(--hb-papel-claro); font-weight: 700; }
.pe__org-nombre { font-weight: 600; }

.err-enter-active, .err-leave-active { transition: all .2s; }
.err-enter-from, .err-leave-to { opacity: 0; transform: translateY(-4px); }
</style>
