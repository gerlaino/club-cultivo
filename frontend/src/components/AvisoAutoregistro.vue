<script setup>
// El aviso para quien se registró solo (uso personal, /registro): confirmar el mail antes de que la
// cuenta se pause, y cuántos días de prueba le quedan cuando faltan pocos. Los datos vienen de
// `/me` (`autoregistro`): la fecha de la pausa la calcula el backend.
//
// Se puede cerrar («Más tarde») y vuelve en la próxima sesión del navegador: es un recordatorio,
// no un muro. El muro, si llega, es el cartel de cuenta pausada (OrganizacionSuspendida).
import { ref, computed } from 'vue'
import { useAuthStore } from '../stores/auth'
import { reenviarConfirmacion } from '../lib/api.js'
import { formatFechaLarga, hoyISO } from '../utils/dates.js'

const auth = useAuthStore()
const CLAVE = 'aviso_autoregistro_cerrado'

const cerrado = ref((() => { try { return sessionStorage.getItem(CLAVE) === '1' } catch { return false } })())
const reenviado = ref(false)

const reg = computed(() => auth.user?.autoregistro || null)
const diasPrueba = computed(() => {
  if (!reg.value?.prueba_hasta) return null
  const ms = new Date(reg.value.prueba_hasta + 'T00:00:00') - new Date(hoyISO() + 'T00:00:00')
  return Math.round(ms / 86400000)
})
const faltaMail = computed(() => reg.value && !reg.value.mail_confirmado)
const pruebaCorta = computed(() => diasPrueba.value != null && diasPrueba.value <= 7)
const visible = computed(() => !cerrado.value && (faltaMail.value || pruebaCorta.value))

function cerrar() {
  cerrado.value = true
  try { sessionStorage.setItem(CLAVE, '1') } catch {}
}
async function reenviar() {
  try { await reenviarConfirmacion(reg.value.email) } catch {}
  reenviado.value = true
}
</script>

<template>
  <div v-if="visible" class="aar" role="status">
    <div class="aar__txt">
      <template v-if="faltaMail">
        <strong>Confirmá tu mail.</strong>
        Te mandamos un link a {{ reg.email }}.
        <span v-if="reg.pausa_el">Si no lo confirmás, la cuenta se pausa el {{ formatFechaLarga(reg.pausa_el) }}.</span>
      </template>
      <template v-if="pruebaCorta">
        <span :class="{ 'aar__sep': faltaMail }">
          {{ diasPrueba > 0 ? `Te quedan ${diasPrueba} ${diasPrueba === 1 ? 'día' : 'días'} de prueba.` : 'Hoy termina tu prueba.' }}
          <a href="/contacto?tipo=personal">Consultanos para seguir</a>.
        </span>
      </template>
    </div>
    <div class="aar__acc">
      <button v-if="faltaMail && !reenviado" type="button" class="aar__btn" @click="reenviar">Reenviar link</button>
      <span v-else-if="faltaMail" class="aar__ok">Enviado</span>
      <button type="button" class="aar__cerrar" aria-label="Más tarde" @click="cerrar">Más tarde</button>
    </div>
  </div>
</template>

<style scoped>
.aar {
  position: fixed; z-index: 1500; left: 50%; transform: translateX(-50%);
  top: calc(env(safe-area-inset-top, 0px) + 8px);
  width: min(640px, calc(100% - 16px));
  display: flex; flex-wrap: wrap; align-items: center; gap: .5rem .75rem;
  background: var(--c-amber-100); color: #5c4000; border: 1px solid #F5D98B;
  border-radius: 12px; padding: .65rem .8rem; box-shadow: 0 10px 30px rgb(0 0 0 / .18);
  font-size: .84rem; line-height: 1.45;
}
.aar__txt { flex: 1 1 260px; }
.aar__sep { display: block; margin-top: .2rem; }
.aar__txt a { color: inherit; font-weight: 700; }
.aar__acc { display: flex; gap: .4rem; align-items: center; }
.aar__btn { background: #5c4000; color: #fff; border: none; border-radius: 8px; padding: .45rem .8rem; font-weight: 700; font-size: .8rem; cursor: pointer; min-height: 36px; }
.aar__cerrar { background: transparent; color: #5c4000; border: 1px solid rgb(92 64 0 / .3); border-radius: 8px; padding: .45rem .7rem; font-size: .8rem; cursor: pointer; min-height: 36px; }
.aar__ok { font-weight: 700; font-size: .8rem; }
</style>
