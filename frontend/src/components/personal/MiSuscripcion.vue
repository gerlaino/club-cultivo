<template>
  <div class="msu" data-testid="mi-suscripcion">
    <p v-if="cargando" class="msu__mut">Cargando…</p>

    <template v-else-if="actual?.estado === 'activa'">
      <p class="msu__ok"><i class="bi bi-check-circle-fill"></i> Suscripción activa · {{ ars(actual.monto_ars) }} por mes</p>
      <p v-if="planHasta" class="msu__mut">Pagado hasta el {{ fecha(planHasta) }}. Se renueva sola con Mercado Pago ({{ actual.payer_email }}).</p>
      <p class="msu__mut">Para darla de baja, hacelo desde tu cuenta de Mercado Pago o <a href="/contacto?tipo=personal">escribinos</a>.</p>
    </template>

    <template v-else-if="!disponible">
      <p class="msu__mut">Para seguir {{ enPrueba ? 'después de la prueba' : '' }}, <a href="/contacto?tipo=personal">escribinos</a> y te pasamos cómo pagar.</p>
    </template>

    <template v-else>
      <p class="msu__precio"><strong>{{ ars(precio) }}</strong> por mes, con Mercado Pago.</p>
      <p v-if="actual?.estado === 'pendiente' && actual.link" class="msu__mut">
        Ya empezaste a suscribirte: <a :href="actual.link">seguí en Mercado Pago</a>, o generá el link de nuevo.
      </p>
      <label class="msu__campo">
        <span>Mail de tu cuenta de Mercado Pago</span>
        <input v-model.trim="email" type="email" class="msu__input" autocomplete="email" />
        <small>Tenés que entrar a Mercado Pago con este mail para que el pago se asocie a tu cuenta.</small>
      </label>
      <button type="button" class="msu__btn" :disabled="enviando || !email" @click="suscribirme">
        {{ enviando ? 'Abriendo Mercado Pago…' : 'Suscribirme' }}
      </button>
      <p v-if="error" class="msu__error">{{ error }}</p>
    </template>
  </div>
</template>

<script setup>
// La suscripción del autocultivo con Mercado Pago (12-oct-2026). El precio es el fijo de la
// plataforma (lo carga super admin): la persona sólo dice con qué mail de Mercado Pago paga, y se
// va a Mercado Pago a completar. Que el pago entró lo avisa Mercado Pago al backend (webhook), no
// la vuelta del navegador: por eso al volver puede tardar un momento en verse activa.
//
// Anda con la cuenta pausada por fin de prueba o falta de pago: es lo que la despausa.
import { ref, computed, onMounted } from 'vue'
import { getMiSuscripcion, crearMiSuscripcion } from '../../lib/api.js'
import { formatARS } from '../../lib/formatters.js'

const cargando = ref(true)
const precio = ref(null)
const mpConfigurado = ref(false)
const actual = ref(null)
const planHasta = ref(null)
const enPrueba = ref(false)
const email = ref('')
const enviando = ref(false)
const error = ref('')

const disponible = computed(() => mpConfigurado.value && precio.value > 0)
const ars = (n) => formatARS(n)
const fecha = (d) => (d ? new Date(`${d}T00:00:00`).toLocaleDateString('es-AR', { day: 'numeric', month: 'long' }) : '')

onMounted(async () => {
  try {
    const { data } = await getMiSuscripcion()
    precio.value = data.precio_ars
    mpConfigurado.value = data.mp_configurado
    actual.value = data.actual
    planHasta.value = data.plan_activo_hasta
    enPrueba.value = data.en_prueba
    email.value = data.email_sugerido || ''
  } catch { /* sin esto se ve el «escribinos» */ } finally { cargando.value = false }
})

async function suscribirme() {
  error.value = ''
  enviando.value = true
  try {
    const { data } = await crearMiSuscripcion({ payer_email: email.value })
    if (data.link) window.location.href = data.link
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'No se pudo abrir Mercado Pago. Probá de nuevo.'
    enviando.value = false
  }
}
</script>

<style scoped>
.msu { display: flex; flex-direction: column; gap: .6rem; text-align: left; }
.msu__mut { margin: 0; font-size: .85rem; color: var(--c-slate-500); line-height: 1.5; }
.msu__ok { margin: 0; font-size: .92rem; font-weight: 600; color: var(--c-leaf-800); }
.msu__precio { margin: 0; font-size: .95rem; color: var(--c-ink-900); }
.msu__campo { display: flex; flex-direction: column; gap: .3rem; font-size: .8rem; font-weight: 600; color: var(--c-slate-600); }
.msu__campo small { font-weight: 400; color: var(--c-slate-500); }
.msu__input { border: 1px solid var(--c-slate-300); border-radius: 9px; padding: .55rem .75rem; font-size: .9rem; width: 100%; box-sizing: border-box; }
.msu__btn { align-self: flex-start; background: var(--c-leaf-800); color: #fff; border: 0; border-radius: 9px; padding: .6rem 1.2rem; font-size: .9rem; font-weight: 700; cursor: pointer; }
.msu__btn:disabled { opacity: .6; cursor: default; }
.msu__error { margin: 0; font-size: .82rem; color: var(--c-rust-600); }
</style>
