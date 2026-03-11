<template>
  <div class="contacto-view">
    <div class="container py-5">
      <div class="row">
        <!-- Información del club -->
        <div class="col-lg-5 mb-5">
          <h1 class="mb-4">Contacto</h1>
          <p class="lead text-muted mb-4">
            ¿Tenés dudas o querés más información? Estamos para ayudarte.
          </p>

          <div v-if="club" class="contact-info">
            <div v-if="club.address" class="info-item mb-4">
              <div class="icon-wrapper bg-success text-white">
                <i class="bi bi-geo-alt-fill"></i>
              </div>
              <div>
                <h6 class="mb-1">Dirección</h6>
                <p class="text-muted mb-0">
                  {{ club.address }}<br>
                  {{ club.city }}, {{ club.state }}<br>
                  {{ club.country }}
                </p>
              </div>
            </div>

            <div v-if="club.phone" class="info-item mb-4">
              <div class="icon-wrapper bg-success text-white">
                <i class="bi bi-telephone-fill"></i>
              </div>
              <div>
                <h6 class="mb-1">Teléfono</h6>
                <p class="text-muted mb-0">
                  <a :href="`tel:${club.phone}`" class="text-decoration-none">
                    {{ club.phone }}
                  </a>
                </p>
              </div>
            </div>

            <div v-if="club.email" class="info-item mb-4">
              <div class="icon-wrapper bg-success text-white">
                <i class="bi bi-envelope-fill"></i>
              </div>
              <div>
                <h6 class="mb-1">Email</h6>
                <p class="text-muted mb-0">
                  <a :href="`mailto:${club.email}`" class="text-decoration-none">
                    {{ club.email }}
                  </a>
                </p>
              </div>
            </div>

            <div v-if="club.website" class="info-item mb-4">
              <div class="icon-wrapper bg-success text-white">
                <i class="bi bi-globe"></i>
              </div>
              <div>
                <h6 class="mb-1">Sitio Web</h6>
                <p class="text-muted mb-0">
                  <a :href="club.website" target="_blank" class="text-decoration-none">
                    {{ club.website }}
                  </a>
                </p>
              </div>
            </div>

            <!-- Redes sociales -->
            <div class="mt-4">
              <h6 class="mb-3">Seguinos en redes</h6>
              <div class="d-flex gap-3">
                <a href="#" class="social-link">
                  <i class="bi bi-facebook"></i>
                </a>
                <a href="#" class="social-link">
                  <i class="bi bi-instagram"></i>
                </a>
                <a href="#" class="social-link">
                  <i class="bi bi-twitter"></i>
                </a>
                <a href="#" class="social-link">
                  <i class="bi bi-whatsapp"></i>
                </a>
              </div>
            </div>
          </div>
        </div>

        <!-- Formulario de contacto -->
        <div class="col-lg-7">
          <div class="card shadow-sm">
            <div class="card-body p-4">
              <h3 class="mb-4">Envianos un mensaje</h3>

              <div v-if="enviado" class="alert alert-success">
                <i class="bi bi-check-circle"></i>
                ¡Mensaje enviado! Te responderemos a la brevedad.
              </div>

              <div v-if="errorEnvio" class="alert alert-danger">
                <i class="bi bi-exclamation-circle"></i>
                {{ errorEnvio }}
              </div>

              <form @submit.prevent="enviarMensaje">
                <div class="row g-3">
                  <div class="col-md-6">
                    <label for="nombre" class="form-label">Nombre *</label>
                    <input
                        type="text"
                        class="form-control"
                        id="nombre"
                        v-model="form.nombre"
                        required
                    >
                  </div>

                  <div class="col-md-6">
                    <label for="email" class="form-label">Email *</label>
                    <input
                        type="email"
                        class="form-control"
                        id="email"
                        v-model="form.email"
                        required
                    >
                  </div>

                  <div class="col-12">
                    <label for="telefono" class="form-label">Teléfono</label>
                    <input
                        type="tel"
                        class="form-control"
                        id="telefono"
                        v-model="form.telefono"
                    >
                  </div>

                  <div class="col-12">
                    <label for="asunto" class="form-label">Asunto *</label>
                    <select class="form-select" id="asunto" v-model="form.asunto" required>
                      <option value="">Seleccionar...</option>
                      <option value="informacion">Información general</option>
                      <option value="socio">Quiero ser socio</option>
                      <option value="reprocann">Consulta REPROCANN</option>
                      <option value="geneticas">Consulta sobre genéticas</option>
                      <option value="eventos">Consulta sobre eventos</option>
                      <option value="otro">Otro</option>
                    </select>
                  </div>

                  <div class="col-12">
                    <label for="mensaje" class="form-label">Mensaje *</label>
                    <textarea
                        class="form-control"
                        id="mensaje"
                        rows="5"
                        v-model="form.mensaje"
                        required
                    ></textarea>
                  </div>

                  <div class="col-12">
                    <button
                        type="submit"
                        class="btn btn-success btn-lg w-100"
                        :disabled="enviando"
                    >
                      <span v-if="enviando">
                        <span class="spinner-border spinner-border-sm me-2"></span>
                        Enviando...
                      </span>
                      <span v-else>
                        <i class="bi bi-send"></i>
                        Enviar mensaje
                      </span>
                    </button>
                  </div>

                  <div class="col-12">
                    <small class="text-muted">
                      * Campos obligatorios
                    </small>
                  </div>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>

      <!-- Horarios de atención (opcional) -->
      <div class="row mt-5">
        <div class="col-12">
          <div class="card bg-light">
            <div class="card-body">
              <h4 class="mb-3">
                <i class="bi bi-clock text-success"></i>
                Horarios de Atención
              </h4>
              <div class="row">
                <div class="col-md-6">
                  <p class="mb-2"><strong>Lunes a Viernes:</strong> 10:00 - 18:00 hs</p>
                  <p class="mb-2"><strong>Sábados:</strong> 10:00 - 14:00 hs</p>
                  <p class="mb-0"><strong>Domingos y feriados:</strong> Cerrado</p>
                </div>
                <div class="col-md-6">
                  <div class="alert alert-info mb-0">
                    <i class="bi bi-info-circle"></i>
                    Se atiende con turno previo. Contactanos para coordinar tu visita.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const club = ref(null)
const form = ref({
  nombre: '',
  email: '',
  telefono: '',
  asunto: '',
  mensaje: ''
})
const enviando = ref(false)
const enviado = ref(false)
const errorEnvio = ref(null)

async function enviarMensaje() {
  enviando.value = true
  enviado.value = false
  errorEnvio.value = null

  try {
    // Por ahora solo simulamos el envío
    // TODO: Implementar endpoint de contacto en el backend
    await new Promise(resolve => setTimeout(resolve, 1500))

    // Simular éxito
    enviado.value = true

    // Resetear formulario
    form.value = {
      nombre: '',
      email: '',
      telefono: '',
      asunto: '',
      mensaje: ''
    }

    // Scroll al mensaje de éxito
    window.scrollTo({ top: 0, behavior: 'smooth' })
  } catch (err) {
    console.error('Error enviando mensaje:', err)
    errorEnvio.value = 'Hubo un error al enviar el mensaje. Por favor, intenta de nuevo o contactanos directamente por email o teléfono.'
  } finally {
    enviando.value = false
  }
}

onMounted(async () => {
  try {
    club.value = await publicApi.getClub()
  } catch (error) {
    console.error('Error cargando info del club:', error)
  }
})
</script>

<style scoped>
.info-item {
  display: flex;
  gap: 1rem;
}

.icon-wrapper {
  width: 50px;
  height: 50px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  flex-shrink: 0;
}

.social-link {
  width: 45px;
  height: 45px;
  border-radius: 50%;
  background: #198754;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
  text-decoration: none;
  transition: transform 0.2s, background 0.2s;
}

.social-link:hover {
  transform: translateY(-3px);
  background: #146c43;
}

.form-label {
  font-weight: 500;
}

.form-control:focus,
.form-select:focus {
  border-color: #198754;
  box-shadow: 0 0 0 0.25rem rgba(25, 135, 84, 0.25);
}
</style>