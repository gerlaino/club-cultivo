<template>
  <div class="stp__card">
    <div class="stp__header">
      <div class="stp__header-icon"><component :is="KeyRound" :size="15" /></div>
      <div>
        <div class="stp__title">Acceso al portal</div>
        <div class="stp__subtitle">Entra con su DNI y una clave que elige él: nadie de la organización la conoce</div>
      </div>
    </div>

    <template v-if="acceso">
      <div class="stp__dato">
        <span class="stp__lbl">Estado</span>
        <span class="stp__pill" :class="estado.clase" data-testid="portal-estado">{{ estado.texto }}</span>
      </div>
      <div v-if="acceso.ultimo_ingreso" class="stp__dato">
        <span class="stp__lbl">Entró</span>
        <span class="stp__txt">{{ fechaHora(acceso.ultimo_ingreso) }}</span>
      </div>
      <div v-if="acceso.link_vigente" class="stp__dato">
        <span class="stp__lbl">Link</span>
        <span class="stp__txt">
          {{ acceso.link_vigente.motivo === 'recuperacion' ? 'Pidió una clave nueva' : 'Invitación mandada' }} el
          {{ fechaHora(acceso.link_vigente.creado_at) }} · vence {{ fechaHora(acceso.link_vigente.expira_at) }}
        </span>
      </div>

      <p v-if="!acceso.portal_abierto" class="stp__nota stp__nota--warn">
        Tu organización tiene el portal <strong>cerrado</strong>. Abrilo en Configuración → Portal del paciente
        y después mandale el link.
      </p>
      <p v-else-if="!acceso.activo" class="stp__nota stp__nota--warn">
        El paciente está dado de baja, así que no entra al portal. Se reactiva desde <strong>Datos</strong>,
        con el mismo interruptor que le permite retirar.
      </p>
      <p v-else-if="acceso.activado" class="stp__nota">
        Si perdió la clave, la recupera solo con «Me olvidé la clave»{{ acceso.tiene_mail ? '' : ' (le llega por mail, y no tiene uno cargado)' }}.
        También podés mandarle un link nuevo desde acá.
      </p>
      <p v-else class="stp__nota">
        Mandale el link: lo abre, pone su DNI y elige su clave. {{ acceso.tiene_mail ? 'Le llega también a su mail.' : 'No tiene mail cargado: cargáselo en la ficha, o copiá el link y pasáselo vos.' }}
      </p>

      <div v-if="acceso.puede_gestionar && acceso.portal_abierto && acceso.activo" class="stp__acts">
        <button class="stp__btn stp__btn--primary" :disabled="trabajando" data-testid="portal-invitar" @click="invitar">
          <Send :size="13" />
          {{ acceso.activado || acceso.link_vigente ? 'Mandar un link nuevo' : 'Invitar al portal' }}
        </button>
      </div>
      <p v-else-if="!acceso.puede_gestionar" class="stp__nota stp__nota--warn">
        Sólo administración o el médico puede mandarle el link.
      </p>
    </template>

    <LinkPortalNuevo :datos="link" @cerrar="link = null" />
  </div>
</template>

<script setup>
// El acceso al portal, en la ficha del paciente (27-oct-2026).
//
// Antes acá se creaba la cuenta y se mostraba UNA vez una contraseña para dictársela; si la
// perdía, se generaba otra. Ahora el paciente entra con su DNI y elige su clave desde un link:
// la ficha dice si ya lo activó, cuándo entró y si tiene un link vigente, y manda uno nuevo.
import { computed, ref } from 'vue'
import { KeyRound, Send } from 'lucide-vue-next'
import { invitarPortalPaciente } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import LinkPortalNuevo from './LinkPortalNuevo.vue'

const props = defineProps({
  socioId: { type: [String, Number], required: true },
  nombre:  { type: String, default: '' },
  acceso:  { type: Object, default: null },
})
const emit = defineEmits(['actualizado'])

const toast = useToast()
const { confirm } = useConfirm()
const trabajando = ref(false)
const link = ref(null)

const estado = computed(() => {
  const a = props.acceso || {}
  if (!a.portal_abierto) return { texto: 'Portal cerrado', clase: 'stp__pill--off' }
  if (!a.activo) return { texto: 'Dado de baja', clase: 'stp__pill--off' }
  if (a.activado) return { texto: 'Activó su portal', clase: 'stp__pill--on' }
  if (a.link_vigente) return { texto: 'Invitado, sin activar', clase: 'stp__pill--espera' }
  return { texto: 'Sin invitar', clase: 'stp__pill--off' }
})

const fechaHora = (iso) => {
  if (!iso) return ''
  const d = new Date(iso)
  return `${d.toLocaleDateString('es-AR', { day: 'numeric', month: 'numeric' })} ${d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })}`
}

async function invitar() {
  // Si ya hay un link sin usar, el nuevo lo anula: el paciente que lo tenía guardado se encuentra
  // con «este link ya no sirve». Se avisa antes.
  if (props.acceso?.link_vigente) {
    const ok = await confirm({
      title: 'Mandar un link nuevo',
      message: 'El link que le mandaste antes deja de servir. Mandale este.',
      confirmText: 'Generar link nuevo',
    })
    if (!ok) return
  }
  trabajando.value = true
  try {
    const { data } = await invitarPortalPaciente(props.socioId)
    link.value = { ...data.link, nombre: props.nombre }
    emit('actualizado')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo generar el link')
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
.stp__pill--espera { background: var(--c-amber-100); color: var(--c-gold-500); }
.stp__txt { font-size: .85rem; color: var(--c-slate-700); }

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
