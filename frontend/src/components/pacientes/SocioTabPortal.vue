<template>
  <div class="stp__card">
    <div class="stp__header">
      <div class="stp__header-icon"><component :is="KeyRound" :size="15" /></div>
      <div>
        <div class="stp__title">Acceso al portal</div>
        <div class="stp__subtitle">Con esta cuenta el paciente entra a ver lo suyo</div>
      </div>
    </div>

    <!-- Ya tiene cuenta -->
    <template v-if="acceso?.tiene">
      <div class="stp__dato">
        <span class="stp__lbl">Usuario</span>
        <code class="stp__val">{{ acceso.email }}</code>
      </div>
      <div class="stp__dato">
        <span class="stp__lbl">Estado</span>
        <span class="stp__pill" :class="acceso.activo ? 'stp__pill--on' : 'stp__pill--off'">
          {{ acceso.activo ? 'Puede entrar' : 'No puede entrar' }}
        </span>
      </div>

      <p v-if="!acceso.activo" class="stp__nota stp__nota--warn">
        El paciente está desactivado en la organización, así que su cuenta no entra al portal.
        Se reactiva desde <strong>Datos</strong>, con el mismo interruptor que le permite retirar.
      </p>
      <p v-else-if="acceso.mail_posible" class="stp__nota">
        La contraseña no se guarda en ningún lado. Si la perdió, generá una nueva: le llega por mail
        y también te la mostramos acá para pasársela.
      </p>
      <p v-else class="stp__nota stp__nota--warn">
        La contraseña no se guarda en ningún lado, y a este paciente <strong>no se la podemos mandar
        por mail</strong>: {{ acceso.mail_falta }} Si la perdió, generá una nueva y pasásela vos.
      </p>

      <div v-if="acceso.puede_gestionar" class="stp__acts">
        <button class="stp__btn" :disabled="trabajando" @click="restablecer">
          <RefreshCw :size="13" />
          Generar contraseña nueva
        </button>
      </div>
    </template>

    <!-- Todavía no tiene -->
    <template v-else>
      <p class="stp__nota">
        Todavía no tiene cuenta. La reciben los pacientes que se dan de alta desde que existe el
        portal; a los de antes hay que crearla acá.
      </p>
      <p v-if="acceso && !acceso.mail_posible" class="stp__nota stp__nota--warn">
        La contraseña <strong>no se le va a poder mandar por mail</strong>: {{ acceso.mail_falta }}
        Vas a tener que pasársela vos, y se muestra una sola vez.
      </p>
      <div v-if="acceso?.sugerido" class="stp__dato">
        <span class="stp__lbl">Le quedaría</span>
        <code class="stp__val">{{ acceso.sugerido }}</code>
      </div>

      <div v-if="acceso?.puede_gestionar" class="stp__acts">
        <button class="stp__btn stp__btn--primary" :disabled="trabajando" @click="crear">
          <KeyRound :size="13" />
          Crear su acceso
        </button>
      </div>
      <p v-else class="stp__nota stp__nota--warn">
        Sólo un administrador o el médico puede crear el acceso.
      </p>
    </template>

    <CredencialesNuevas :datos="credenciales" @cerrar="credenciales = null" />
  </div>
</template>

<script setup>
// La cuenta del portal, en la ficha del paciente.
//
// Antes la contraseña inicial se mostraba UNA vez al dar el alta y después no había ningún lugar
// donde ver siquiera cuál era el usuario. Y los pacientes cargados antes del portal no tenían
// cuenta ni forma de conseguirla más que borrarlos y volverlos a cargar.
import { ref } from 'vue'
import { KeyRound, RefreshCw } from 'lucide-vue-next'
import { crearAccesoPaciente, restablecerAccesoPaciente } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import CredencialesNuevas from '../ui/CredencialesNuevas.vue'

const props = defineProps({
  socioId: { type: [String, Number], required: true },
  nombre:  { type: String, default: '' },
  acceso:  { type: Object, default: null },
})
const emit = defineEmits(['actualizado'])

const toast = useToast()
const { confirm } = useConfirm()
const trabajando  = ref(false)
const credenciales = ref(null)

async function crear() {
  trabajando.value = true
  try {
    const { data } = await crearAccesoPaciente(props.socioId)
    credenciales.value = { ...data.credenciales, nombre: props.nombre }
    emit('actualizado')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo crear el acceso')
  } finally {
    trabajando.value = false
  }
}

async function restablecer() {
  // Se avisa antes: la clave vieja deja de servir en el acto, y si el paciente la tenía anotada
  // se queda afuera sin entender por qué.
  const ok = await confirm({
    title: 'Generar una contraseña nueva',
    message: 'La contraseña actual deja de servir en el momento. Vas a tener que pasarle la nueva.',
    confirmText: 'Generar',
  })
  if (!ok) return

  trabajando.value = true
  try {
    const { data } = await restablecerAccesoPaciente(props.socioId)
    credenciales.value = { ...data.credenciales, nombre: props.nombre }
    emit('actualizado')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo restablecer la contraseña')
  } finally {
    trabajando.value = false
  }
}
</script>

<style scoped>
.stp__card {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 1.25rem;
}
.stp__header { display: flex; align-items: flex-start; gap: .7rem; margin-bottom: 1.1rem; }
.stp__header-icon {
  width: 30px; height: 30px; border-radius: 8px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: var(--c-slate-100); color: var(--c-slate-600);
}
.stp__title { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.stp__subtitle { font-size: .78rem; color: var(--c-slate-500); }

.stp__dato { display: flex; align-items: center; gap: .75rem; margin-bottom: .6rem; }
.stp__lbl {
  font-size: .7rem; color: var(--c-slate-500); width: 92px; flex-shrink: 0;
  text-transform: uppercase; letter-spacing: .04em; font-weight: 700;
}
.stp__val {
  font-family: monospace; font-size: .88rem; background: var(--c-slate-50);
  border: 1px solid var(--c-slate-200); border-radius: 7px; padding: .3rem .6rem;
  color: var(--c-slate-900); user-select: all;
}
.stp__pill {
  font-size: .72rem; font-weight: 700; padding: .18rem .55rem; border-radius: 20px;
}
.stp__pill--on  { background: #dcfce7; color: #15803d; }
.stp__pill--off { background: var(--c-slate-100); color: var(--c-slate-500); }

.stp__nota { font-size: .82rem; color: var(--c-slate-500); margin: .9rem 0 0; line-height: 1.55; }
.stp__nota--warn { color: #92400e; }

.stp__acts { display: flex; gap: .6rem; margin-top: 1.1rem; }
.stp__btn {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .45rem .85rem; border-radius: 8px; font-size: .82rem; font-weight: 600;
  border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); cursor: pointer;
}
.stp__btn:hover:not(:disabled) { background: var(--c-slate-50); }
.stp__btn:disabled { opacity: .55; cursor: default; }
.stp__btn--primary { background: #15803d; border-color: #15803d; color: #fff; }
.stp__btn--primary:hover:not(:disabled) { background: #166534; }
</style>
