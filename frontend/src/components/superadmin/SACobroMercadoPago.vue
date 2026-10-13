<template>
  <section class="scm" data-testid="cobro-mp">
    <div class="scm__hd">
      <h3 class="scm__t">Cobro con Mercado Pago</h3>
      <span v-if="actual" class="scm__estado" :class="`scm__estado--${actual.estado}`">{{ actual.estado_label }}</span>
    </div>

    <p v-if="cargando" class="scm__mut">Cargando…</p>
    <p v-else-if="!mpConfigurado" class="scm__aviso">
      Mercado Pago no está configurado: falta cargar <code>MP_ACCESS_TOKEN</code> y <code>MP_WEBHOOK_SECRET</code> en Render
      (web y worker). Hasta entonces no se pueden generar links.
    </p>

    <template v-else>
      <div v-if="actual" class="scm__actual">
        <div class="scm__fila"><span>Monto</span><strong>{{ ars(actual.monto_ars) }} por mes</strong></div>
        <div class="scm__fila"><span>Paga con</span><strong>{{ actual.payer_email }}</strong></div>
        <div v-if="planHasta" class="scm__fila"><span>Pagado hasta</span><strong>{{ fecha(planHasta) }}</strong></div>
        <div v-if="actual.link && actual.estado === 'pendiente'" class="scm__link">
          <input :value="actual.link" readonly class="scm__input" aria-label="Link para suscribirse" @focus="$event.target.select()" />
          <button type="button" class="sa-btn sa-btn--chico" @click="copiar">{{ copiado ? 'Copiado' : 'Copiar link' }}</button>
        </div>
        <p v-if="actual.estado === 'pendiente'" class="scm__mut">Mandale el link: se suscribe en Mercado Pago con la cuenta de ese mail. Cuando lo haga, esto cambia solo.</p>
      </div>
      <p v-else class="scm__mut">Todavía no tiene cobro con Mercado Pago.</p>

      <div v-if="formAbierto" class="scm__form">
        <label class="scm__campo">
          <span>Monto mensual (ARS)</span>
          <input v-model.number="form.monto_ars" type="number" min="1" step="100" class="scm__input" />
        </label>
        <label class="scm__campo scm__campo--grow">
          <span>Mail de la cuenta de Mercado Pago que paga</span>
          <input v-model.trim="form.payer_email" type="email" class="scm__input" />
        </label>
        <p v-if="actual && actual.estado !== 'cancelada'" class="scm__aviso">Generar un link nuevo cancela el actual.</p>
        <div class="scm__acc">
          <button type="button" class="sa-btn sa-btn--chico" @click="formAbierto = false">Cancelar</button>
          <button type="button" class="sa-btn sa-btn--chico sa-btn--primario" :disabled="guardando || !(form.monto_ars > 0) || !form.payer_email" @click="generar">Generar link</button>
        </div>
      </div>
      <div v-else class="scm__acc">
        <button v-if="actual && actual.estado !== 'cancelada'" type="button" class="sa-btn sa-btn--chico sa-btn--peligro" :disabled="guardando" @click="cancelar">Cancelar suscripción</button>
        <button type="button" class="sa-btn sa-btn--chico sa-btn--primario" @click="abrirForm">{{ actual ? 'Generar otro link' : 'Generar link de cobro' }}</button>
      </div>

      <div v-if="actual?.cobros?.length" class="scm__cobros">
        <div class="scm__sub">Cobros</div>
        <div v-for="c in actual.cobros" :key="c.id" class="scm__cobro">
          <span>{{ fecha(c.cobrado_at) }}</span>
          <span>{{ ars(c.monto_ars) }}</span>
          <span :class="c.estado === 'aprobado' ? 'scm__ok' : 'scm__mal'">{{ c.estado === 'aprobado' ? `Aprobado · hasta ${fecha(c.extiende_hasta)}` : c.estado }}</span>
        </div>
      </div>
    </template>
  </section>
</template>

<script setup>
// El cobro con Mercado Pago de UNA organización (12-oct-2026): super admin genera el link con el
// monto de esta organización y se lo manda. Lo que pasa después (se suscribió, cobró, rebotó) lo
// trae el webhook: acá sólo se muestra.
import { ref, onMounted } from 'vue'
import { getSuscripcionClub, crearSuscripcionClub, cancelarSuscripcionClub } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { formatARS } from '../../lib/formatters.js'

const props = defineProps({ clubId: { type: [Number, String], required: true } })
const toast = useToast()
const { confirm } = useConfirm()

const cargando = ref(true)
const guardando = ref(false)
const mpConfigurado = ref(false)
const actual = ref(null)
const planHasta = ref(null)
const emailSugerido = ref('')
const formAbierto = ref(false)
const form = ref({ monto_ars: null, payer_email: '' })
const copiado = ref(false)

const ars = (n) => formatARS(n)
const fecha = (d) => (d ? new Date(String(d).length === 10 ? `${d}T00:00:00` : d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' }) : '—')

async function cargar() {
  try {
    const { data } = await getSuscripcionClub(props.clubId)
    mpConfigurado.value = data.mp_configurado
    actual.value = data.actual
    planHasta.value = data.plan_activo_hasta
    emailSugerido.value = data.email_sugerido || ''
  } catch { toast.error('No se pudo cargar el cobro') } finally { cargando.value = false }
}
function abrirForm() {
  form.value = { monto_ars: actual.value?.monto_ars || null, payer_email: actual.value?.payer_email || emailSugerido.value }
  formAbierto.value = true
}
async function generar() {
  guardando.value = true
  try {
    actual.value = (await crearSuscripcionClub(props.clubId, form.value)).data
    formAbierto.value = false
    toast.success('Link generado: copialo y mandáselo')
  } catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo generar el link') }
  finally { guardando.value = false }
}
async function cancelar() {
  const ok = await confirm({ title: '¿Cancelar la suscripción?', message: 'Mercado Pago deja de cobrarle. Lo ya pagado sigue hasta su fecha.', confirmText: 'Cancelar suscripción', cancelText: 'Volver', variant: 'danger' })
  if (!ok) return
  guardando.value = true
  try { actual.value = (await cancelarSuscripcionClub(props.clubId)).data; toast.success('Suscripción cancelada') }
  catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo cancelar') }
  finally { guardando.value = false }
}
async function copiar() {
  try { await navigator.clipboard.writeText(actual.value.link); copiado.value = true; setTimeout(() => { copiado.value = false }, 2000) }
  catch { toast.error('No se pudo copiar: seleccionalo y copialo a mano') }
}
onMounted(cargar)
</script>

<style scoped>
.scm { display: flex; flex-direction: column; gap: .75rem; padding: 1.25rem; }
.scm__hd { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.scm__t { margin: 0; font-size: 1rem; font-weight: 700; color: var(--c-ink-900); }
.scm__estado { font-size: .75rem; font-weight: 700; padding: 3px 10px; border-radius: 999px; background: var(--c-slate-100); color: var(--c-slate-600); }
.scm__estado--activa { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.scm__estado--pendiente { background: var(--c-amber-100); color: var(--c-gold-500); }
.scm__estado--cancelada, .scm__estado--pausada { background: var(--c-rust-100); color: var(--c-rust-600); }
.scm__mut { margin: 0; font-size: .82rem; color: var(--c-slate-500); }
.scm__aviso { margin: 0; font-size: .82rem; color: var(--c-gold-500); background: var(--c-amber-100); border-radius: 9px; padding: .55rem .75rem; }
.scm__actual { display: flex; flex-direction: column; gap: .35rem; }
.scm__fila { display: flex; justify-content: space-between; gap: 1rem; font-size: .86rem; color: var(--c-slate-600); }
.scm__fila strong { color: var(--c-ink-900); }
.scm__link { display: flex; gap: .5rem; align-items: center; margin-top: .25rem; }
.scm__input { width: 100%; min-width: 0; box-sizing: border-box; border: 1px solid var(--c-slate-300); border-radius: 9px; padding: .5rem .7rem; font-size: .85rem; }
.scm__form { display: flex; flex-wrap: wrap; gap: .75rem; align-items: flex-end; padding: .75rem; border: 1px solid var(--c-slate-200); border-radius: 12px; background: var(--c-slate-50); }
.scm__campo { display: flex; flex-direction: column; gap: .3rem; font-size: .78rem; font-weight: 600; color: var(--c-slate-600); flex: 0 0 180px; }
.scm__campo--grow { flex: 1 1 240px; }
.scm__form .scm__aviso { flex-basis: 100%; }
.scm__acc { display: flex; justify-content: flex-end; gap: .5rem; flex-basis: 100%; }
.scm__cobros { border-top: 1px solid var(--c-slate-200); padding-top: .6rem; }
.scm__sub { font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-500); margin-bottom: .35rem; }
.scm__cobro { display: grid; grid-template-columns: 1fr auto 1.4fr; gap: .75rem; font-size: .84rem; padding: .3rem 0; }
.scm__ok { color: var(--c-leaf-800); font-weight: 600; text-align: right; }
.scm__mal { color: var(--c-rust-600); font-weight: 600; text-align: right; }
@media (max-width: 520px) { .scm__campo { flex: 1 1 100%; } }
</style>
