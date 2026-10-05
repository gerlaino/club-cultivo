<template>
  <div v-if="enviado" class="cf" role="status">
    <h3 class="hb__h3">Gracias, {{ enviado.nombre }}.</h3>
    <p>Recibimos tu {{ enviado.tipo === 'baja' ? 'pedido' : 'mensaje' }}. Te respondemos a <strong>{{ enviado.email }}</strong>.</p>
    <p class="cf__codigo">Código de trámite · <strong>{{ enviado.codigo }}</strong></p>
  </div>

  <form v-else class="cf" novalidate @submit.prevent="enviar">
    <div v-if="TIPOS_VISIBLES.length > 1" class="cf__tipos" role="radiogroup" aria-label="Sobre qué nos escribís">
      <button v-for="t in TIPOS_VISIBLES" :key="t.id" type="button" role="radio" :aria-checked="tipo === t.id"
              class="cf__tipo" :class="{ 'cf__tipo--on': tipo === t.id }" @click="tipo = t.id">{{ t.label }}</button>
    </div>
    <p v-if="tipo === 'baja'" class="cf__aviso">
      <strong>Botón de arrepentimiento.</strong> Si contrataste en los últimos 10 días, lo podés
      revocar sin costo ni explicaciones; también sirve para pedir la baja en cualquier momento.
      Te damos un código de trámite en el momento.
    </p>
    <label class="cf__campo">
      <span>Nombre</span>
      <input v-model="form.nombre" type="text" maxlength="120" autocomplete="name" required />
    </label>
    <label class="cf__campo">
      <span>Mail</span>
      <input v-model.trim="form.email" type="email" maxlength="160" autocomplete="email" required />
    </label>
    <label v-if="tipo === 'organizacion'" class="cf__campo">
      <span>Organización o proyecto</span>
      <input v-model="form.organizacion" type="text" maxlength="160" autocomplete="organization" />
    </label>
    <label class="cf__campo">
      <span>Teléfono o WhatsApp <em>opcional</em></span>
      <input v-model="form.telefono" type="tel" maxlength="40" autocomplete="tel" />
    </label>
    <label class="cf__campo">
      <span>{{ tipo === 'baja' ? 'Con qué mail entrás, y lo que quieras agregar' : 'Mensaje' }} <em v-if="tipo !== 'baja'">opcional</em></span>
      <textarea v-model="form.mensaje" rows="4" maxlength="3000"></textarea>
    </label>
    <!-- Campo trampa: una persona no lo ve; un robot lo completa y el backend lo descarta. -->
    <input v-model="form.sitio" type="text" name="sitio" class="cf__trampa" tabindex="-1" autocomplete="off" aria-hidden="true" />
    <p v-if="error" class="cf__error">{{ error }}</p>
    <button type="submit" class="hb__btn" :disabled="enviando || !form.nombre || !form.email">
      {{ enviando ? 'Enviando…' : (tipo === 'baja' ? 'Enviar pedido' : 'Enviar') }}
    </button>
    <p class="cf__legal">Usamos tus datos sólo para responderte. <RouterLink to="/privacidad">Política de privacidad</RouterLink>.</p>
  </form>
</template>

<script setup>
// EL FORMULARIO DE CONTACTO de las páginas públicas (sale de la portada el 5-oct-2026, cuando
// /bienvenida se partió en autocultivo y proyectos). Va a `POST /public/contacto` y cae en Super admin →
// Consultas. Los tipos son los del backend (`organizacion`, `personal`, `baja`): en pantalla la
// organización se ofrece como «proyecto», pero el valor que viaja no cambia.
import { ref, reactive, computed, watch } from 'vue'
import { enviarContacto } from '../../lib/api.js'

const props = defineProps({
  // Con cuál arranca elegido.
  tipoInicial: { type: String, default: 'organizacion' },
  // Cuáles se ofrecen. En la página de proyectos, uno solo (y entonces no se muestra el selector).
  tipos: { type: Array, default: () => ['organizacion', 'personal', 'baja'] },
})

const TIPOS = [
  { id: 'organizacion', label: 'Proyecto u organización' },
  { id: 'personal',     label: 'Autocultivo' },
  { id: 'baja',         label: 'Arrepentimiento / baja' },
]
const TIPOS_VISIBLES = computed(() => TIPOS.filter(t => props.tipos.includes(t.id)))

const tipo = ref(props.tipos.includes(props.tipoInicial) ? props.tipoInicial : props.tipos[0])
watch(() => props.tipoInicial, (t) => { if (props.tipos.includes(t)) tipo.value = t })

const form = reactive({ nombre: '', email: '', organizacion: '', telefono: '', mensaje: '', sitio: '' })
const enviando = ref(false)
const error = ref(null)
const enviado = ref(null)

async function enviar () {
  error.value = null
  enviando.value = true
  try {
    const { data } = await enviarContacto({ ...form, tipo: tipo.value, organizacion: tipo.value === 'organizacion' ? form.organizacion : '' })
    enviado.value = { nombre: form.nombre.split(' ')[0], email: form.email, tipo: tipo.value, codigo: data?.codigo }
  } catch (e) {
    error.value = e?.response?.status === 429
      ? 'Llegaron muchos mensajes desde esta conexión. Probá en un rato o escribinos por mail.'
      : (e?.response?.data?.error || 'No se pudo enviar. Revisá tu conexión y probá de nuevo.')
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
.cf { display: flex; flex-direction: column; gap: 14px; padding: 24px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); }
.cf p { margin: 0; }
.cf__codigo { font: 14px var(--hb-mono); }
.cf__tipos { display: flex; flex-wrap: wrap; gap: 8px; }
.cf__tipo { min-height: 38px; border: 1px solid var(--hb-regla); background: var(--hb-papel-claro); color: var(--hb-tinta-2); border-radius: 999px; padding: .4rem .95rem; font: 500 14px var(--hb-sans); cursor: pointer; }
.cf__tipo--on { background: var(--hb-tinta); border-color: var(--hb-tinta); color: var(--hb-papel-claro); }
.cf__aviso { border-left: 3px solid var(--hb-ambar); padding-left: 12px; color: var(--hb-tinta-2); font-size: .92rem; }
.cf__campo { display: flex; flex-direction: column; gap: 5px; font: 500 12px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.cf__campo em { font-style: normal; text-transform: none; letter-spacing: 0; opacity: .75; }
.cf__campo input, .cf__campo textarea {
  font: 16px var(--hb-sans); text-transform: none; letter-spacing: 0; color: var(--hb-tinta);
  background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); border-radius: 6px; padding: .7rem .8rem; resize: vertical;
}
.cf__campo input:focus, .cf__campo textarea:focus { border-color: var(--hb-verde); outline: none; box-shadow: 0 0 0 3px var(--hb-salvia-suave); }
.cf__trampa { position: absolute; left: -10000px; width: 1px; height: 1px; opacity: 0; }
.cf .hb__btn { align-self: flex-start; }
.cf__error { color: var(--hb-error); font-size: 14px; }
.cf__legal { font-size: 13px; color: var(--hb-tinta-2); }
.cf__legal a { color: var(--hb-verde); }
</style>
