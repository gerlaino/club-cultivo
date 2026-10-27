<template>
  <Teleport to="body">
    <div v-modal="cerrar" v-if="datos" class="lpn-ov" @click.self="cerrar">
      <div class="lpn" role="dialog" aria-labelledby="lpn-titulo">
        <div class="lpn__head">
          <i class="bi bi-send-check-fill"></i>
          <div>
            <h3 id="lpn-titulo" class="lpn__title">Mandale el link a {{ primerNombre }}</h3>
            <p class="lpn__sub">Con este link entra a su portal: pone su DNI y elige su clave. Sirve una sola vez y vence {{ vence }}.</p>
          </div>
        </div>

        <div class="lpn__row">
          <code class="lpn__val" data-testid="link-portal">{{ datos.url }}</code>
          <button type="button" class="lpn__copy" aria-label="Copiar el link" @click="copiar(datos.url, 'Link copiado')">
            <i class="bi bi-clipboard"></i>
          </button>
        </div>

        <p v-if="datos.mail_enviado" class="lpn__mail"><i class="bi bi-envelope-check"></i> También se lo mandamos a su mail.</p>
        <p v-else class="lpn__mail lpn__mail--off"><i class="bi bi-envelope-slash"></i> No tiene mail cargado: mandáselo por WhatsApp.</p>

        <div class="lpn__acts">
          <a class="lpn__btn lpn__btn--wa" :href="whatsapp" target="_blank" rel="noopener" data-testid="link-portal-whatsapp">
            <i class="bi bi-whatsapp"></i> Mandar por WhatsApp
          </a>
          <button class="lpn__btn" @click="copiar(datos.texto, 'Mensaje copiado')">Copiar el mensaje</button>
          <button class="lpn__btn lpn__btn--primary" @click="cerrar">Listo</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
// El link del portal recién generado (al dar el alta, al aprobarla o desde la ficha), 27-oct-2026.
// Reemplaza a mostrar la contraseña una vez: ahora la clave la elige el paciente y nadie la ve.
// El link sí se ve sólo acá: la ficha dice si hay uno vigente, pero no lo vuelve a mostrar (para
// mandarlo de nuevo se genera otro, que anula el anterior).
import { computed } from 'vue'
import { useToast } from '../../composables/useToast'

const props = defineProps({
  // `{ nombre, url, texto, expira_at, mail_enviado }` o null para no mostrar nada.
  datos: { type: Object, default: null },
})
const emit = defineEmits(['cerrar'])
const toast = useToast()

const primerNombre = computed(() => (props.datos?.nombre || '').trim().split(/\s+/)[0] || 'el paciente')
const vence = computed(() => {
  if (!props.datos?.expira_at) return 'en 72 horas'
  const d = new Date(props.datos.expira_at)
  return `el ${d.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'numeric' })} a las ${d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })}`
})
// Sin número: WhatsApp le pregunta a quién mandárselo. Adivinar el número a partir de cómo se
// cargó el teléfono (con o sin 15, con o sin 0) manda el link a otra persona.
const whatsapp = computed(() => `https://wa.me/?text=${encodeURIComponent(props.datos?.texto || '')}`)

async function copiar(texto, aviso) {
  try {
    await navigator.clipboard.writeText(texto)
    toast.success(aviso)
  } catch {
    toast.warning('No se pudo copiar: seleccioná el link y copialo a mano')
  }
}

function cerrar() { emit('cerrar') }
</script>

<style scoped>
.lpn-ov { position: fixed; inset: 0; background: rgba(15,23,42,.5); display: flex; align-items: center; justify-content: center; z-index: 1200; padding: 1rem; }
.lpn { background: #fff; border-radius: 16px; max-width: 500px; width: 100%; padding: 1.5rem; box-shadow: 0 24px 64px rgba(0,0,0,.2); }
.lpn__head { display: flex; gap: .75rem; align-items: flex-start; margin-bottom: 1.1rem; }
.lpn__head > i { color: var(--c-leaf-600); font-size: 1.5rem; flex-shrink: 0; }
.lpn__title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .2rem; }
.lpn__sub { font-size: .82rem; color: var(--c-slate-500); margin: 0; line-height: 1.5; }
.lpn__row { display: flex; align-items: center; gap: .6rem; }
.lpn__val {
  flex: 1; min-width: 0; font-family: monospace; font-size: .8rem; background: var(--c-slate-50);
  border: 1px solid var(--c-slate-200); border-radius: 7px; padding: .45rem .65rem; color: var(--c-slate-900);
  user-select: all; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.lpn__copy { flex-shrink: 0; width: 38px; height: 38px; border-radius: 8px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); cursor: pointer; }
.lpn__copy:hover { background: var(--c-slate-50); }
.lpn__mail { font-size: .8rem; color: var(--c-leaf-600); margin: .9rem 0 0; display: flex; align-items: center; gap: .4rem; }
.lpn__mail--off { color: var(--c-gold-500); }
.lpn__acts { display: flex; flex-wrap: wrap; gap: .6rem; justify-content: flex-end; margin-top: 1.35rem; }
.lpn__btn {
  display: inline-flex; align-items: center; gap: .4rem; min-height: 40px;
  padding: .5rem 1rem; border-radius: 8px; font-size: .85rem; font-weight: 600; cursor: pointer; text-decoration: none;
  border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700);
}
.lpn__btn:hover { background: var(--c-slate-50); }
.lpn__btn--wa { border-color: var(--c-leaf-600); color: var(--c-leaf-700); }
.lpn__btn--primary { background: var(--c-leaf-700); border-color: var(--c-leaf-700); color: #fff; }
.lpn__btn--primary:hover { background: var(--c-leaf-800); }
</style>
