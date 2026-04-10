<template>
  <div class="cv">

    <section class="cv__hero">
      <div class="cv__hero-inner">
        <h1 class="cv__hero-title">Ponete en <span class="cv__hero-accent">contacto</span></h1>
        <p class="cv__hero-sub">¿Tenés autorización REPROCANN o querés más información? Estamos para ayudarte.</p>
      </div>
    </section>

    <section class="cv__section">
      <div class="cv__container cv__layout">

        <!-- Info del club -->
        <div class="cv__info">

          <div class="cv__info-card">
            <h2 class="cv__info-title">Información del club</h2>

            <div v-if="club" class="cv__info-items">
              <div v-if="club.address" class="cv__info-item">
                <div class="cv__info-icon">
                  <i class="bi bi-geo-alt-fill"></i>
                </div>
                <div>
                  <div class="cv__info-label">Dirección</div>
                  <div class="cv__info-val">{{ club.address }}, {{ club.city }}</div>
                </div>
              </div>
              <div v-if="club.phone" class="cv__info-item">
                <div class="cv__info-icon">
                  <i class="bi bi-telephone-fill"></i>
                </div>
                <div>
                  <div class="cv__info-label">Teléfono</div>
                  <a :href="`tel:${club.phone}`" class="cv__info-val cv__info-link">{{ club.phone }}</a>
                </div>
              </div>
              <div v-if="club.email" class="cv__info-item">
                <div class="cv__info-icon">
                  <i class="bi bi-envelope-fill"></i>
                </div>
                <div>
                  <div class="cv__info-label">Email</div>
                  <a :href="`mailto:${club.email}`" class="cv__info-val cv__info-link">{{ club.email }}</a>
                </div>
              </div>
              <div v-if="club.whatsapp" class="cv__info-item">
                <div class="cv__info-icon cv__info-icon--wa">
                  <i class="bi bi-whatsapp"></i>
                </div>
                <div>
                  <div class="cv__info-label">WhatsApp</div>
                  <a :href="`https://wa.me/${club.whatsapp?.replace(/\D/g,'')}`"
                     target="_blank" class="cv__info-val cv__info-link">{{ club.whatsapp }}</a>
                </div>
              </div>
            </div>

            <!-- Redes sociales -->
            <div class="cv__redes" v-if="club?.instagram_url || club?.facebook_url">
              <div class="cv__redes-title">Seguinos</div>
              <div class="cv__redes-links">
                <a v-if="club.instagram_url" :href="club.instagram_url" target="_blank" class="cv__red cv__red--ig">
                  <i class="bi bi-instagram"></i>
                </a>
                <a v-if="club.facebook_url" :href="club.facebook_url" target="_blank" class="cv__red cv__red--fb">
                  <i class="bi bi-facebook"></i>
                </a>
              </div>
            </div>
          </div>

          <!-- Horarios -->
          <div v-if="club?.horarios_atencion" class="cv__horarios-card">
            <div class="cv__horarios-icon"><i class="bi bi-clock"></i></div>
            <div>
              <div class="cv__horarios-title">Horarios de atención</div>
              <div class="cv__horarios-texto">{{ club.horarios_atencion }}</div>
            </div>
          </div>

        </div>

        <!-- Formulario -->
        <div class="cv__form-card">
          <h2 class="cv__form-title">Envianos un mensaje</h2>
          <p class="cv__form-sub">Te respondemos a la brevedad.</p>

          <div v-if="enviado" class="cv__success">
            <i class="bi bi-check-circle-fill"></i>
            ¡Mensaje enviado! Te respondemos pronto.
          </div>

          <div v-if="errorEnvio" class="cv__error">
            <i class="bi bi-exclamation-circle"></i>
            {{ errorEnvio }}
          </div>

          <form v-if="!enviado" @submit.prevent="enviarMensaje" class="cv__form">
            <div class="cv__form-row">
              <div class="cv__field">
                <label class="cv__label">Nombre *</label>
                <input v-model="form.nombre" class="cv__input" type="text" placeholder="Tu nombre" required />
              </div>
              <div class="cv__field">
                <label class="cv__label">Email *</label>
                <input v-model="form.email" class="cv__input" type="email" placeholder="tu@email.com" required />
              </div>
            </div>
            <div class="cv__field">
              <label class="cv__label">Teléfono</label>
              <input v-model="form.telefono" class="cv__input" type="tel" placeholder="+54 9 11 xxxx-xxxx" />
            </div>
            <div class="cv__field">
              <label class="cv__label">Asunto *</label>
              <select v-model="form.asunto" class="cv__input" required>
                <option value="">Seleccioná un asunto...</option>
                <option value="socio">Quiero ser socio / asociarme</option>
                <option value="reprocann">Consulta sobre REPROCANN</option>
                <option value="geneticas">Consulta sobre variedades</option>
                <option value="informacion">Información general</option>
                <option value="otro">Otro</option>
              </select>
            </div>
            <div class="cv__field">
              <label class="cv__label">Mensaje *</label>
              <textarea v-model="form.mensaje" class="cv__textarea" rows="5"
                        placeholder="Contanos tu consulta..." required></textarea>
            </div>
            <button type="submit" class="cv__submit-btn" :disabled="enviando">
              <span v-if="enviando"><i class="bi bi-hourglass-split"></i> Enviando...</span>
              <span v-else><i class="bi bi-send"></i> Enviar mensaje</span>
            </button>
          </form>
        </div>

      </div>
    </section>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '../api/publicApi.js'

const club = ref(null)
const form = ref({ nombre: '', email: '', telefono: '', asunto: '', mensaje: '' })
const enviando   = ref(false)
const enviado    = ref(false)
const errorEnvio = ref(null)

async function enviarMensaje() {
  enviando.value = true
  errorEnvio.value = null
  try {
    await new Promise(r => setTimeout(r, 1200))
    enviado.value = true
    form.value = { nombre: '', email: '', telefono: '', asunto: '', mensaje: '' }
  } catch {
    errorEnvio.value = 'Hubo un error. Intentá de nuevo o contactanos directamente.'
  } finally {
    enviando.value = false
  }
}

onMounted(async () => {
  try { club.value = await publicApi.getClub() }
  catch (e) { console.error(e) }
})
</script>

<style scoped>
.cv { min-height: 100vh; background: #f0fdf4; }

.cv__hero { background: #060f07; padding: 5rem 2rem 4rem; position: relative; overflow: hidden; }
.cv__hero::before {
  content: ''; position: absolute; inset: 0;
  background: radial-gradient(ellipse at 30% 50%, #1b5e2018 0%, transparent 65%);
}
.cv__hero-inner { max-width: 1200px; margin: 0 auto; position: relative; z-index: 1; }
.cv__hero-title { color: #f0fdf4; font-size: 40px; font-weight: 500; margin-bottom: 1rem; }
.cv__hero-accent { color: #66bb6a; }
.cv__hero-sub { color: #81c784; font-size: 16px; opacity: .8; margin: 0; max-width: 480px; }

.cv__section { padding: 3.5rem 0 5rem; }
.cv__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }
.cv__layout { display: grid; grid-template-columns: 1fr 1.4fr; gap: 2.5rem; align-items: start; }

/* Info */
.cv__info { display: flex; flex-direction: column; gap: 16px; }
.cv__info-card {
  background: #060f07; border: 1px solid #1b5e2033;
  border-radius: 18px; padding: 1.75rem;
}
.cv__info-title { color: #f0fdf4; font-size: 17px; font-weight: 600; margin-bottom: 1.5rem; }
.cv__info-items { display: flex; flex-direction: column; gap: 1.25rem; }
.cv__info-item { display: flex; align-items: flex-start; gap: 14px; }
.cv__info-icon {
  width: 40px; height: 40px; border-radius: 10px;
  background: #1b5e2022; border: 1px solid #1b5e2033;
  display: flex; align-items: center; justify-content: center;
  color: #66bb6a; font-size: 16px; flex-shrink: 0;
}
.cv__info-icon--wa { background: #25d36620; border-color: #25d36640; color: #25d366; }
.cv__info-label { font-size: 11px; color: #4a7c59; text-transform: uppercase; letter-spacing: .07em; margin-bottom: 3px; }
.cv__info-val { font-size: 14px; color: #a5d6a7; }
.cv__info-link { text-decoration: none; transition: color .15s; }
.cv__info-link:hover { color: #66bb6a; }

.cv__redes { margin-top: 1.5rem; padding-top: 1.25rem; border-top: 1px solid #1b5e2022; }
.cv__redes-title { font-size: 12px; color: #4a7c59; text-transform: uppercase; letter-spacing: .07em; margin-bottom: 10px; }
.cv__redes-links { display: flex; gap: 10px; }
.cv__red {
  width: 40px; height: 40px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 18px; text-decoration: none; transition: opacity .2s;
}
.cv__red--ig { background: #e1306c20; color: #e1306c; border: 1px solid #e1306c30; }
.cv__red--fb { background: #1877f220; color: #1877f2; border: 1px solid #1877f230; }
.cv__red:hover { opacity: .8; }

.cv__horarios-card {
  background: #0d1f0e; border: 1px solid #1b5e2033;
  border-radius: 14px; padding: 1.25rem 1.5rem;
  display: flex; gap: 14px; align-items: flex-start;
}
.cv__horarios-icon {
  width: 36px; height: 36px; border-radius: 9px;
  background: #1b5e2022; border: 1px solid #1b5e2033;
  display: flex; align-items: center; justify-content: center;
  color: #66bb6a; font-size: 15px; flex-shrink: 0;
}
.cv__horarios-title { font-size: 13px; font-weight: 600; color: #a5d6a7; margin-bottom: 5px; }
.cv__horarios-texto { font-size: 13px; color: #81c784; opacity: .8; white-space: pre-wrap; line-height: 1.6; }

/* Formulario */
.cv__form-card {
  background: white; border: 1px solid #d4edda;
  border-radius: 20px; padding: 2.25rem;
  box-shadow: 0 4px 24px #1b5e2008;
}
.cv__form-title { font-size: 20px; font-weight: 600; color: #1a2e1b; margin-bottom: 6px; }
.cv__form-sub { font-size: 14px; color: #4a7c59; margin-bottom: 1.75rem; }

.cv__success {
  display: flex; align-items: center; gap: 10px;
  background: #e8f5e9; border: 1px solid #a5d6a7;
  color: #1b5e20; padding: 1rem 1.25rem; border-radius: 12px;
  font-size: 14px; font-weight: 500; margin-bottom: 1rem;
}
.cv__error {
  display: flex; align-items: center; gap: 10px;
  background: #fef2f2; border: 1px solid #fecaca;
  color: #dc2626; padding: 1rem 1.25rem; border-radius: 12px;
  font-size: 14px; margin-bottom: 1rem;
}

.cv__form { display: flex; flex-direction: column; gap: 16px; }
.cv__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.cv__field { display: flex; flex-direction: column; gap: 6px; }
.cv__label { font-size: 13px; font-weight: 500; color: #4a7c59; }
.cv__input {
  padding: 11px 14px; border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: 14px; background: #f8fafc; color: #1a2e1b; outline: none;
  transition: border-color .15s, box-shadow .15s; font-family: inherit;
}
.cv__input:focus { border-color: #1b5e20; box-shadow: 0 0 0 3px #1b5e2015; }
.cv__textarea {
  padding: 11px 14px; border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: 14px; background: #f8fafc; color: #1a2e1b; outline: none;
  resize: vertical; transition: border-color .15s, box-shadow .15s; font-family: inherit; line-height: 1.5;
}
.cv__textarea:focus { border-color: #1b5e20; box-shadow: 0 0 0 3px #1b5e2015; }
.cv__submit-btn {
  background: linear-gradient(135deg, #1b5e20, #2e7d32); color: #e8f5e9;
  border: none; padding: 13px; border-radius: 10px; font-size: 15px;
  cursor: pointer; transition: opacity .2s; box-shadow: 0 2px 8px #1b5e2030;
  display: flex; align-items: center; justify-content: center; gap: 8px;
}
.cv__submit-btn:hover { opacity: .88; }
.cv__submit-btn:disabled { opacity: .5; cursor: not-allowed; }

@media (max-width: 900px) {
  .cv__layout { grid-template-columns: 1fr; }
  .cv__form-row { grid-template-columns: 1fr; }
  .cv__hero-title { font-size: 28px; }
}
</style>