<template>
  <Teleport to="body">
    <div v-if="datos" class="cred-ov" @click.self="cerrar">
      <div class="cred">
        <div class="cred__head">
          <i class="bi bi-check-circle-fill"></i>
          <div>
            <h3 class="cred__title">{{ datos.nombre }} ya puede entrar</h3>
            <p class="cred__sub">Pasale estos datos. La contraseña no se puede volver a ver.</p>
          </div>
        </div>
        <div class="cred__row">
          <span class="cred__lbl">Usuario</span>
          <code class="cred__val">{{ datos.email }}</code>
        </div>
        <div class="cred__row">
          <span class="cred__lbl">Contraseña</span>
          <code class="cred__val cred__val--big">{{ datos.password_inicial }}</code>
        </div>
        <p v-if="datos.mail_enviado === true" class="cred__mail">
          <i class="bi bi-envelope-check"></i> También se las mandamos por mail.
        </p>
        <p v-else-if="datos.mail_enviado === false" class="cred__mail cred__mail--off">
          <i class="bi bi-envelope-slash"></i>
          El mail no salió, así que <strong>pasáselas vos</strong>: es la única copia.
        </p>
        <p v-else class="cred__mail cred__mail--off">
          <i class="bi bi-telephone"></i> Se dicta por teléfono sin equívocos: no lleva ceros ni eles.
        </p>
        <div class="cred__acts">
          <button class="cred__btn" @click="copiar">
            <i class="bi bi-clipboard"></i> Copiar
          </button>
          <button class="cred__btn cred__btn--primary" @click="cerrar">Listo</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
// Las credenciales de un alta se muestran UNA vez y no se recuperan: para eso está
// "Restablecer contraseña" en la ficha. Vive acá y no dentro de una pantalla porque son dos las
// que dan de alta gente que después entra —el equipo y los pacientes— y la misma regla escrita
// en dos lados es exactamente lo que se nos viene rompiendo.
import { useToast } from '../../composables/useToast'

const props = defineProps({
  // `{ nombre, email, password_inicial, mail_enviado? }` o null para no mostrar nada.
  datos: { type: Object, default: null },
})
const emit = defineEmits(['cerrar'])
const toast = useToast()

async function copiar() {
  await navigator.clipboard.writeText(
    `Usuario: ${props.datos.email}\nContraseña: ${props.datos.password_inicial}`
  )
  toast.success('Copiado')
}

function cerrar() { emit('cerrar') }
</script>

<style scoped>
.cred-ov { position: fixed; inset: 0; background: rgba(15,23,42,.5); display: flex; align-items: center; justify-content: center; z-index: 1200; padding: 1rem; }
.cred { background: #fff; border-radius: 16px; max-width: 460px; width: 100%; padding: 1.5rem; box-shadow: 0 24px 64px rgba(0,0,0,.2); }
.cred__head { display: flex; gap: .75rem; align-items: flex-start; margin-bottom: 1.25rem; }
.cred__head > i { color: #15803d; font-size: 1.5rem; flex-shrink: 0; }
.cred__title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .15rem; }
.cred__sub { font-size: .8rem; color: var(--c-slate-500); margin: 0; }
.cred__row { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.cred__lbl { font-size: .7rem; color: var(--c-slate-500); width: 82px; flex-shrink: 0; text-transform: uppercase; letter-spacing: .04em; font-weight: 700; }
.cred__val { font-family: monospace; font-size: .9rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 7px; padding: .35rem .65rem; color: var(--c-slate-900); user-select: all; flex: 1; }
.cred__val--big { font-size: 1.1rem; font-weight: 700; letter-spacing: .05em; }
.cred__mail { font-size: .78rem; color: #15803d; margin: .9rem 0 0; display: flex; align-items: center; gap: .4rem; }
.cred__mail--off { color: #92400e; }
.cred__acts { display: flex; gap: .6rem; justify-content: flex-end; margin-top: 1.35rem; }
.cred__btn {
  padding: .5rem 1rem; border-radius: 8px; font-size: .85rem; font-weight: 600; cursor: pointer;
  border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700);
}
.cred__btn:hover { background: var(--c-slate-50); }
.cred__btn--primary { background: #15803d; border-color: #15803d; color: #fff; }
.cred__btn--primary:hover { background: #166534; }
</style>
