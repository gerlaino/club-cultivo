<template>
  <div class="ppa">
    <div v-if="!panel" class="ppa__cargando"><DsSpinner :size="48" /></div>

    <template v-else>
      <!-- El estado, siempre arriba y con su interruptor: se guarda al tocarlo. -->
      <section class="ppa__estado" :class="{ 'ppa__estado--on': panel.abierto }" data-testid="portal-estado">
        <div class="ppa__estado-txt">
          <span class="ppa__dot" :class="{ 'ppa__dot--on': panel.abierto }" aria-hidden="true"></span>
          <div>
            <p class="ppa__estado-t">{{ panel.abierto ? 'Portal abierto' : 'Portal cerrado' }}</p>
            <p class="ppa__estado-s">
              {{ panel.abierto
                ? `Tus pacientes entran con su DNI. ${panel.pacientes.entran} ${panel.pacientes.entran === 1 ? 'ya entra' : 'ya entran'}.`
                : 'Tus pacientes no pueden entrar. Abrilo cuando esté listo.' }}
            </p>
          </div>
        </div>
        <DsSwitch :model-value="panel.abierto" :disabled="guardando === 'abierto'"
                  :aria-label="panel.abierto ? 'Cerrar el portal' : 'Abrir el portal'"
                  data-testid="portal-abrir" @update:model-value="cambiar('abierto', $event)" />
      </section>

      <!-- PRIMERA VEZ: los pasos, hasta que estén todos. -->
      <section v-if="armando" class="ppa__card ppa__pasos" data-testid="portal-pasos">
        <header class="ppa__pasos-hd">
          <h2 class="ppa__h2">Armá tu portal</h2>
          <span class="ppa__avance">{{ hechos }} de {{ PASOS.length }} listos</span>
          <div class="ppa__barra" role="progressbar" :aria-valuenow="hechos" aria-valuemin="0" :aria-valuemax="PASOS.length">
            <div class="ppa__barra-in" :style="{ width: `${(hechos / PASOS.length) * 100}%` }"></div>
          </div>
        </header>
        <ol class="ppa__lista">
          <li v-for="(p, i) in PASOS" :key="p.key" class="ppa__paso" :class="{ 'ppa__paso--ok': panel.pasos[p.key] }">
            <span class="ppa__num" :aria-label="panel.pasos[p.key] ? 'Listo' : `Paso ${i + 1}`">
              <Check v-if="panel.pasos[p.key]" :size="16" aria-hidden="true" />
              <template v-else>{{ i + 1 }}</template>
            </span>
            <div class="ppa__paso-txt">
              <p class="ppa__paso-t">{{ p.titulo }}</p>
              <p class="ppa__paso-s">{{ p.ayuda }}</p>
            </div>
            <button v-if="p.key === 'abierto' && !panel.pasos.abierto" type="button" class="ppa__btn ppa__btn--p"
                    :disabled="guardando === 'abierto'" @click="cambiar('abierto', true)">Abrir</button>
            <button v-else-if="p.key === 'presentacion'" type="button" class="ppa__btn" @click="$emit('editar', 'presentacion')">
              {{ panel.pasos.presentacion ? 'Editar' : 'Completar' }}
            </button>
            <button v-else-if="p.key === 'contenido'" type="button" class="ppa__btn" @click="$emit('editar', 'geneticas')">
              {{ panel.pasos.contenido ? 'Ver' : 'Elegir' }}
            </button>
            <button v-else-if="p.key === 'invitados'" type="button" class="ppa__btn" :class="{ 'ppa__btn--p': panel.pasos.abierto }"
                    :disabled="!panel.abierto || !panel.pacientes.ids_invitar.length || invitando"
                    @click="invitar(panel.pacientes.ids_invitar, 'invitar')">
              Invitar a {{ panel.pacientes.ids_invitar.length }}
            </button>
          </li>
          <li class="ppa__paso">
            <span class="ppa__num">{{ PASOS.length + 1 }}</span>
            <div class="ppa__paso-txt">
              <p class="ppa__paso-t">Probalo como paciente</p>
              <p class="ppa__paso-s">Cargate como paciente con tu DNI y tu mail, invitate desde tu ficha y entrá en otra ventana: ves exactamente lo que ve tu gente.</p>
            </div>
          </li>
        </ol>
      </section>

      <!-- Lo que espera respuesta: es lo único urgente. -->
      <section v-if="hayParaAtender" class="ppa__atender" data-testid="portal-atender">
        <h2 class="ppa__h2">Para atender</h2>
        <div class="ppa__grid3">
          <article v-if="panel.reservar" class="ppa__card">
            <header class="ppa__card-hd"><h3 class="ppa__h3">Pedidos para confirmar</h3><span v-if="pa.pedidos.total" class="ppa__count">{{ pa.pedidos.total }}</span></header>
            <p v-if="!pa.pedidos.total" class="ppa__vacio">Ninguno.</p>
            <RouterLink v-for="r in pa.pedidos.items" :key="r.id" class="ppa__item" to="/reservas?estado=solicitada">
              <strong>{{ r.paciente }}</strong> · {{ diaRetiro(r.fecha) }}
              <span class="ppa__item-s">{{ r.detalle }}<template v-if="r.sede"> · {{ r.sede }}</template></span>
            </RouterLink>
            <RouterLink v-if="pa.pedidos.total" class="ppa__link" to="/reservas?estado=solicitada">Confirmarlos</RouterLink>
          </article>
          <article v-if="panel.mensajes" class="ppa__card">
            <header class="ppa__card-hd"><h3 class="ppa__h3">Mensajes sin contestar</h3><span v-if="pa.mensajes.total" class="ppa__count">{{ pa.mensajes.total }}</span></header>
            <p v-if="!pa.mensajes.total" class="ppa__vacio">Ninguno.</p>
            <RouterLink v-for="m in pa.mensajes.items" :key="m.paciente_id" class="ppa__item" :to="`/pacientes/${m.paciente_id}?tab=chat`">
              <strong>{{ m.paciente }}</strong>
              <span class="ppa__item-s">{{ hace(m.at) }}</span>
            </RouterLink>
          </article>
          <article class="ppa__card">
            <header class="ppa__card-hd"><h3 class="ppa__h3">REPROCANN para revisar</h3><span v-if="pa.renovaciones.total" class="ppa__count">{{ pa.renovaciones.total }}</span></header>
            <p v-if="!pa.renovaciones.total" class="ppa__vacio">Ninguno.</p>
            <RouterLink v-for="r in pa.renovaciones.items" :key="r.paciente_id" class="ppa__item" :to="`/pacientes/${r.paciente_id}?tab=reprocann`">
              <strong>{{ r.paciente }}</strong>
              <span class="ppa__item-s">Mandó la renovación {{ hace(r.at) }}</span>
            </RouterLink>
          </article>
        </div>
      </section>

      <div class="ppa__grid2">
        <!-- Quiénes entran, con la acción que destraba a cada grupo. -->
        <section class="ppa__card" data-testid="portal-pacientes">
          <h2 class="ppa__h3">Tus pacientes en el portal</h2>
          <div class="ppa__numeros">
            <div><p class="ppa__big ppa__big--ok">{{ panel.pacientes.entran }}</p><p class="ppa__big-s">entran</p></div>
            <div><p class="ppa__big">{{ panel.pacientes.invitados_sin_entrar }}</p><p class="ppa__big-s">invitados, sin entrar</p></div>
            <div><p class="ppa__big">{{ panel.pacientes.sin_invitar }}</p><p class="ppa__big-s">sin invitar</p></div>
          </div>
          <div class="ppa__acciones">
            <button v-if="panel.pacientes.ids_invitar.length" type="button" class="ppa__btn ppa__btn--p" data-testid="portal-invitar"
                    :disabled="!panel.abierto || invitando" @click="invitar(panel.pacientes.ids_invitar, 'invitar')">
              Invitar a {{ panel.pacientes.ids_invitar.length }} por mail
            </button>
            <button v-if="panel.pacientes.ids_recordar.length" type="button" class="ppa__btn" data-testid="portal-recordar"
                    :disabled="!panel.abierto || invitando" @click="invitar(panel.pacientes.ids_recordar, 'recordar')">
              Recordarles a {{ panel.pacientes.ids_recordar.length }}
            </button>
            <RouterLink class="ppa__btn" to="/configuracion/portal/cartel">Imprimir el cartel con QR</RouterLink>
          </div>
          <p class="ppa__nota">
            <template v-if="panel.pacientes.sin_mail">{{ panel.pacientes.sin_mail }} sin mail en su ficha: cargáselo, o copiá su link desde la ficha y pasáselo. </template>
            Con el cartel, el paciente escanea, pone su DNI y le llega el link a su mail. No hace falta invitarlo.
          </p>
          <p v-if="!panel.abierto" class="ppa__nota ppa__nota--aviso">Abrí el portal para poder invitar.</p>
        </section>

        <!-- Qué ofrece: las partes que piden que alguien conteste se apagan. -->
        <section class="ppa__card" data-testid="portal-partes">
          <h2 class="ppa__h3">Qué pueden hacer</h2>
          <div class="ppa__op">
            <div><p class="ppa__op-t">Ver su credencial, su REPROCANN y sus dispensas</p><p class="ppa__op-s">Siempre, con la trazabilidad de cada una</p></div>
            <span class="ppa__op-fijo">Incluido</span>
          </div>
          <div class="ppa__op">
            <div><p class="ppa__op-t">Reservar para retirar hoy o mañana</p><p class="ppa__op-s">Vos o un supervisor confirman cada pedido</p></div>
            <DsSwitch :model-value="panel.reservar" :disabled="guardando === 'reservar'" aria-label="Reservar"
                      data-testid="portal-reservar" @update:model-value="cambiar('reservar', $event)" />
          </div>
          <div class="ppa__op">
            <div><p class="ppa__op-t">Escribirle a la organización</p><p class="ppa__op-s">Te llega como aviso; contestás desde su ficha</p></div>
            <DsSwitch :model-value="panel.mensajes" :disabled="guardando === 'mensajes'" aria-label="Mensajes"
                      data-testid="portal-mensajes" @update:model-value="cambiar('mensajes', $event)" />
          </div>
          <div class="ppa__op">
            <div><p class="ppa__op-t">Lo que publicás</p>
              <p class="ppa__op-s">{{ panel.publicado.geneticas }} {{ panel.publicado.geneticas === 1 ? 'genética' : 'genéticas' }} ·
                {{ panel.publicado.noticias }} {{ panel.publicado.noticias === 1 ? 'novedad' : 'novedades' }} ·
                {{ panel.publicado.eventos }} {{ panel.publicado.eventos === 1 ? 'evento' : 'eventos' }}</p></div>
            <button type="button" class="ppa__btn" @click="$emit('editar', 'noticias')">Publicar</button>
          </div>
        </section>
      </div>
    </template>
  </div>
</template>

<script setup>
// El portal del lado del admin (Germán, 28-oct-2026: «pensá que no es alguien de sistemas»).
// Contesta tres preguntas: ¿está listo? (los pasos), ¿qué espera que conteste? (pedidos, mensajes,
// renovaciones) y ¿quiénes entran? (con el botón que destraba a cada grupo). Los números y los pasos
// los manda el backend (`Portal::Panel`); los interruptores se guardan al tocarlos, sin un
// «Guardar» escondido al pie (el portal «no quedaba abierto» por eso).
import { computed, ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { Check } from 'lucide-vue-next'
import api, { updatePreferences, invitarPortalLote } from '@/lib/api'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { useRecargaEnCambios } from '@/composables/useRecargaEnCambios'
import { useClubStore } from '@/stores/club'
import DsSpinner from '@/design-system/components/Spinner.vue'
import DsSwitch from '@/design-system/components/Switch.vue'

defineEmits(['editar'])

const toast = useToast()
const { confirm } = useConfirm()
const clubStore = useClubStore()

const panel = ref(null)
const guardando = ref(null)
const invitando = ref(false)

const PASOS = [
  { key: 'abierto',      titulo: 'Abrí el portal',               ayuda: 'Hasta que lo abras, tus pacientes no pueden entrar.' },
  { key: 'presentacion', titulo: 'Presentá la organización',     ayuda: 'Quiénes son, horarios y WhatsApp: lo ven en el inicio.' },
  { key: 'contenido',    titulo: 'Elegí qué ven',                ayuda: 'Las genéticas que les mostrás y tus novedades.' },
  { key: 'invitados',    titulo: 'Invitá a tus pacientes',       ayuda: 'Les llega un mail con su link. También pueden entrar solos con el cartel del mostrador.' },
]
const hechos  = computed(() => PASOS.filter(p => panel.value?.pasos[p.key]).length)
const armando = computed(() => panel.value && hechos.value < PASOS.length)
const pa      = computed(() => panel.value?.para_atender)
const hayParaAtender = computed(() => panel.value?.abierto && pa.value &&
  (pa.value.pedidos.total + pa.value.mensajes.total + pa.value.renovaciones.total > 0 || !armando.value))

async function cargar() {
  try {
    const { data } = await api.get('/portal_panel')
    panel.value = data
  } catch {
    toast.error('No se pudo cargar el portal')
  }
}
onMounted(cargar)
defineExpose({ recargar: cargar })
useRecargaEnCambios(['reservas', 'pacientes'], cargar)

const CAMPO = { abierto: 'vista_paciente_activa', reservar: 'portal_reservar_activo', mensajes: 'portal_mensajes_activo' }
const MENSAJE = {
  abierto:  (v) => v ? 'Portal abierto: tus pacientes ya pueden entrar' : 'Portal cerrado',
  reservar: (v) => v ? 'Reservar prendido' : 'Reservar apagado: no aparece en el portal',
  mensajes: (v) => v ? 'Mensajes prendidos' : 'Mensajes apagados: no aparecen en el portal',
}

async function cambiar(cual, valor) {
  if (cual === 'abierto' && !valor) {
    const ok = await confirm({
      title: 'Cerrar el portal',
      message: 'Tus pacientes no van a poder entrar hasta que lo vuelvas a abrir. Los que estén adentro quedan afuera.',
      confirmText: 'Cerrar el portal',
      variant: 'warning',
    })
    if (!ok) return
  }
  guardando.value = cual
  try {
    const { data } = await updatePreferences({ [CAMPO[cual]]: valor })
    if (clubStore.data) clubStore.data[CAMPO[cual]] = data?.[CAMPO[cual]] ?? valor
    toast.success(MENSAJE[cual](valor))
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo guardar. Probá de nuevo.')
  } finally {
    guardando.value = null
  }
}

async function invitar(ids, modo) {
  const n = ids.length
  if (!n) return
  const ok = await confirm({
    title: modo === 'recordar' ? 'Recordarles' : 'Invitar al portal',
    message: modo === 'recordar'
      ? `A ${n === 1 ? 'este paciente le llega' : `estos ${n} pacientes les llega`} un link nuevo por mail. El que tenían deja de servir.`
      : `A ${n === 1 ? 'este paciente le llega' : `estos ${n} pacientes les llega`} un mail con un link para entrar a su portal y elegir su clave. El link vence en 72 horas.`,
    confirmText: n === 1 ? 'Mandar' : `Mandar ${n}`,
    variant: 'default',
  })
  if (!ok) return
  invitando.value = true
  try {
    const { data } = await invitarPortalLote(ids)
    const r = data?.data || {}
    const omitidos = r.omitidos?.length || 0
    toast.success(`${r.enviados === 1 ? 'Se mandó 1 mail' : `Se mandaron ${r.enviados} mails`}${omitidos ? ` · ${omitidos} sin mandar (mirá su ficha)` : ''}`)
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.errors?.[0] || 'No se pudieron mandar las invitaciones')
  } finally {
    invitando.value = false
  }
}

function diaRetiro(fecha) {
  if (!fecha) return ''
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  const [y, m, d] = String(fecha).slice(0, 10).split('-').map(Number)
  const dias = Math.round((new Date(y, m - 1, d) - hoy) / 86400000)
  return dias === 0 ? 'para hoy' : dias === 1 ? 'para mañana' : `para el ${d}/${m}`
}
function hace(at) {
  if (!at) return ''
  const min = Math.round((Date.now() - new Date(at)) / 60000)
  if (min < 60) return `hace ${Math.max(min, 1)} min`
  const h = Math.round(min / 60)
  if (h < 24) return `hace ${h} h`
  const d = Math.round(h / 24)
  return d === 1 ? 'ayer' : `hace ${d} días`
}
</script>

<style scoped>
.ppa { display: flex; flex-direction: column; gap: var(--sp-5, 1.25rem); }
.ppa__cargando { display: flex; justify-content: center; padding: 3rem 0; }

.ppa__card { background: var(--c-surface, #fff); border: 1px solid var(--c-border, var(--c-slate-200)); border-radius: var(--r-lg, 14px); padding: 1.25rem; }
.ppa__h2 { margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--c-ink-900); }
.ppa__h3 { margin: 0; font-size: .8rem; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; color: var(--c-slate-600); }

.ppa__estado { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap;
  padding: 1.1rem 1.25rem; border-radius: var(--r-lg, 14px); border: 1px solid var(--c-slate-200); background: var(--c-slate-50); }
.ppa__estado--on { background: var(--c-leaf-50); border-color: var(--c-leaf-300); }
.ppa__estado-txt { display: flex; gap: .85rem; align-items: center; min-width: 0; }
.ppa__estado-t { margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--c-ink-900); }
.ppa__estado-s { margin: .15rem 0 0; font-size: .9rem; color: var(--c-slate-600); }
.ppa__dot { flex: 0 0 12px; height: 12px; border-radius: 50%; background: var(--c-slate-400); }
.ppa__dot--on { background: var(--c-leaf-500); box-shadow: 0 0 0 4px var(--c-leaf-100); }

.ppa__pasos { padding: 0; overflow: hidden; }
.ppa__pasos-hd { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; padding: 1.1rem 1.25rem; background: var(--c-leaf-50); border-bottom: 1px solid var(--c-slate-200); }
.ppa__avance { font-size: .9rem; font-weight: 600; color: var(--c-slate-600); }
.ppa__barra { flex: 1 1 160px; max-width: 280px; height: 8px; border-radius: 999px; background: var(--c-slate-200); overflow: hidden; margin-left: auto; }
.ppa__barra-in { height: 100%; background: var(--c-leaf-800); transition: width .3s; }
.ppa__lista { list-style: none; margin: 0; padding: 0; }
.ppa__paso { display: flex; align-items: center; gap: 1rem; padding: 1rem 1.25rem; border-top: 1px solid var(--c-slate-100); }
.ppa__paso:first-child { border-top: none; }
.ppa__num { flex: 0 0 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center;
  font-size: .85rem; font-weight: 700; border: 2px solid var(--c-slate-300); color: var(--c-slate-600); background: var(--c-surface, #fff); }
.ppa__paso--ok .ppa__num { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; }
.ppa__paso-txt { flex: 1; min-width: 0; }
.ppa__paso-t { margin: 0; font-size: 1rem; font-weight: 600; color: var(--c-ink-900); }
.ppa__paso--ok .ppa__paso-t { color: var(--c-slate-600); }
.ppa__paso-s { margin: .15rem 0 0; font-size: .875rem; color: var(--c-slate-600); }

.ppa__btn { display: inline-flex; align-items: center; justify-content: center; min-height: 40px; padding: 0 1rem; border-radius: 10px;
  border: 1px solid var(--c-slate-300); background: var(--c-surface, #fff); color: var(--c-leaf-800); font: inherit; font-size: .9rem; font-weight: 600;
  cursor: pointer; text-decoration: none; white-space: nowrap; }
.ppa__btn:hover:not(:disabled) { border-color: var(--c-leaf-500); }
.ppa__btn--p { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; }
.ppa__btn--p:hover:not(:disabled) { background: var(--c-leaf-900); }
.ppa__btn:disabled { opacity: .5; cursor: not-allowed; }

.ppa__atender { display: flex; flex-direction: column; gap: .75rem; }
.ppa__grid3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; }
.ppa__grid2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
@media (max-width: 960px) { .ppa__grid3, .ppa__grid2 { grid-template-columns: minmax(0, 1fr); } }
.ppa__card-hd { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin-bottom: .5rem; }
.ppa__count { min-width: 24px; height: 24px; padding: 0 7px; border-radius: 999px; background: var(--c-amber-500); color: #fff;
  font-size: .8rem; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; }
.ppa__vacio { margin: .5rem 0 0; font-size: .9rem; color: var(--c-slate-500); }
.ppa__item { display: block; padding: .7rem 0; border-top: 1px solid var(--c-slate-100); color: var(--c-ink-900); text-decoration: none; font-size: .95rem; }
.ppa__item:hover strong { text-decoration: underline; }
.ppa__item-s { display: block; font-size: .85rem; color: var(--c-slate-600); margin-top: .1rem; }
.ppa__link { display: inline-block; margin-top: .5rem; font-size: .9rem; font-weight: 600; color: var(--c-leaf-800); }

.ppa__numeros { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .75rem; margin: 1rem 0; }
.ppa__big { margin: 0; font-size: 1.9rem; font-weight: 700; color: var(--c-ink-900); line-height: 1; }
.ppa__big--ok { color: var(--c-leaf-700); }
.ppa__big-s { margin: .3rem 0 0; font-size: .85rem; color: var(--c-slate-600); }
.ppa__acciones { display: flex; flex-wrap: wrap; gap: .5rem; }
.ppa__nota { margin: .85rem 0 0; font-size: .85rem; color: var(--c-slate-600); line-height: 1.45; }
.ppa__nota--aviso { color: var(--c-gold-500); font-weight: 600; }

.ppa__op { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .85rem 0; border-top: 1px solid var(--c-slate-100); }
.ppa__op:first-of-type { margin-top: .5rem; }
.ppa__op-t { margin: 0; font-size: .95rem; font-weight: 600; color: var(--c-ink-900); }
.ppa__op-s { margin: .1rem 0 0; font-size: .85rem; color: var(--c-slate-600); }
.ppa__op-fijo { font-size: .85rem; color: var(--c-slate-500); white-space: nowrap; }
</style>
