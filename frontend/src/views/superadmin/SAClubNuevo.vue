<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { formatARS } from '../../lib/formatters.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useRouter } from 'vue-router'
import { Building2, Gauge, Zap, Users, ChevronRight, ChevronLeft, Check, ArrowLeft,
         AlertTriangle, Lock, Copy, Info } from 'lucide-vue-next'
import { createSuperAdminClub, getSuperAdminCatalogo } from '../../lib/api.js'

const router = useRouter()

// Los MÓDULOS van antes que el PLAN, y no es sólo prolijidad: el plan es una consecuencia.
// Con el orden viejo, el paso del plan mostraba "3 salas · 450 plantas · 50 pacientes" a una
// organización que capaz sólo compró Producción y dispensa — la mitad de esos topes no aplican
// y desde ahí no había forma de saber cuáles. Y "N usuarios" recién significa algo cuando ya se
// sabe qué roles va a tener.
// Cada paso tiene una clave: el template pregunta por la clave, no por el número, porque el
// uso personal tiene otros pasos (ver `pasos`).
const PASOS_ORG = [
  { clave: 'identidad', label: 'Identidad' },
  { clave: 'modulos',   label: 'Módulos' },
  { clave: 'plan',      label: 'Plan' },
  { clave: 'acceso',    label: 'Acceso' },
  { clave: 'resumen',   label: 'Resumen' },
]
// Uso personal: la persona va primero (es la cuenta), lo que tiene se elige con tres
// interruptores, y el plan —que es uno solo— se funde con la vigencia y la contraseña.
const PASOS_PERSONAL = [
  { clave: 'identidad', label: 'Quién cultiva' },
  { clave: 'modulos',   label: 'Qué tiene' },
  { clave: 'acceso',    label: 'Vigencia y acceso' },
  { clave: 'resumen',   label: 'Resumen' },
]

const paso    = ref(1)
const saving  = ref(false)
const error   = ref(null)
const creado  = ref(null)

// ── Catálogo ──────────────────────────────────────────────────────────
// Qué se puede vender lo dice el backend. Antes esta pantalla repetía la lista a mano y ya
// decía cosas distintas que `Club::ADDONS`: un módulo nuevo obligaba a acordarse de cuatro
// lugares y el que se olvidaba quedaba invisible.
const catalogo  = ref(null)
const cargando  = ref(true)

const planes         = computed(() => catalogo.value?.planes || [])
const suites         = computed(() => catalogo.value?.suites || [])
const addons         = computed(() => catalogo.value?.addons || [])
const incluidos      = computed(() => catalogo.value?.incluidos || [])
const enConstruccion = computed(() => catalogo.value?.en_construccion || [])
const rolesAlta      = computed(() => catalogo.value?.roles_alta || [])

// ── Qué se da de alta: una organización o un uso personal ─────────────────
//
// El cultivador de casa (sep-2026). No es una organización chica: es UNA persona, sin equipo
// y sin pacientes, y en la app entra a otro envoltorio. Acá la decisión es un solo interruptor
// al principio, y el resto del alta se acomoda: los módulos quedan fijos (Cultivo y Ambiente
// vienen adentro, se puede sumar la IA), el plan es uno solo y el acceso es sólo la persona.
// Lo que manda al backend es el plan `personal`: no hay otra bandera.
const tipo       = ref('organizacion')
const esPersonal = computed(() => tipo.value === 'personal')
const pasos      = computed(() => (esPersonal.value ? PASOS_PERSONAL : PASOS_ORG))
const pasoClave  = computed(() => pasos.value[paso.value - 1]?.clave)

function elegirTipo(nuevo) {
  if (tipo.value === nuevo) return
  tipo.value = nuevo
  const data = catalogo.value || {}
  const todas = [...(data.suites || []), ...(data.addons || [])]
  if (nuevo === 'personal') {
    const encendidos = data.features_personal || {}
    form.value.features = Object.fromEntries(todas.map(m => [m.clave, encendidos[m.clave] === true]))
    form.value.plan = 'personal'
    rolesSeleccionados.value = ['admin']
  } else {
    const encendidos = data.features_por_defecto || {}
    form.value.features = Object.fromEntries(todas.map(m => [m.clave, encendidos[m.clave] === true]))
    form.value.plan = 'basico'
  }
}

// Los adicionales que un uso personal puede sumar por fuera de lo que ya trae: el ambiente,
// la IA y su chatbot, uno por uno (19-sep-2026: nacían los tres prendidos y no había nada que
// decidir).
const addonsPersonal = computed(() => {
  const permitidos = catalogo.value?.modulos_personal || []
  const incluidos  = catalogo.value?.features_personal || {}
  return addons.value.filter(a => permitidos.includes(a.clave) && !incluidos[a.clave])
})
// El chatbot sin el Asistente IA no contesta nada: el backend lo apaga solo
// (`Club.acotar_a_personal`) y acá no se ofrece prenderlo.
function bloqueoPersonal(addon) {
  if (addon.clave === 'chatbot' && form.value.features.ia !== true) return 'Necesita el Asistente IA.'
  return null
}
function togglePersonal(addon) {
  if (bloqueoPersonal(addon)) return
  const prender = form.value.features[addon.clave] !== true
  form.value.features[addon.clave] = prender
  if (addon.clave === 'ia' && !prender) form.value.features.chatbot = false
}
// Lo que viene adentro del plan personal, para decirlo.
const incluidosPersonal = computed(() => {
  const incluidos = catalogo.value?.features_personal || {}
  return [...suites.value, ...addons.value].filter(m => incluidos[m.clave] === true)
})
// Los planes que se ofrecen: el personal sólo en uso personal, y en uso personal sólo ése.
const planesOfrecidos = computed(() => planes.value.filter(p => !!p.personal === esPersonal.value))

// ── Form ──────────────────────────────────────────────────────────────
const form = ref({
  name:              '',
  legal_name:        '',
  email:             '',
  phone:             '',
  city:              '',
  state:             '',
  country:           'Argentina',
  timezone:          'America/Argentina/Buenos_Aires',
  plan:              'basico',
  plan_trial:        true,
  plan_activo_hasta: '',
  // Se pisa con `features_por_defecto` del catálogo apenas carga. Esta copia local decía
  // `{cultivo, produccion_dispensa, bar}` mientras el backend mergeaba la suya —que además trae
  // Delivery y Correo—, así que el wizard los mostraba apagados y la organización nacía con los
  // dos prendidos: la pantalla decía una cosa y pasaba otra.
  features:          {},
})

const haySuite = computed(() => esPersonal.value || suites.value.some(s => form.value.features[s.clave] === true))

// Un módulo incluido sólo entra si el club se lleva la suite que lo contiene.
function incluidoActivo(inc) { return form.value.features[inc.incluido_en] === true }

// ── Los adicionales, agrupados por la suite que extienden ──────────────────
//
// Eran una grilla plana de diez tarjetas: "Buffet" al lado de "Ambiente / IoT" no dice para qué
// es cada uno ni qué hay que tener contratado para que sirva. El `pack` lo manda el backend
// (`Club::ADDONS`), no se decide acá — es la misma agrupación que ya usa la ficha del club.
const addonsAgrupados = computed(() => {
  const grupos = suites.value
    .map(s => ({
      clave:     s.clave,
      titulo:    `Adicionales de ${s.label}`,
      packLabel: s.label,
      // Sin la suite, el grupo entero se muestra apagado con el motivo. Ocultarlo haría creer
      // que el módulo no existe, y prenderlo dejaría un módulo contratado que no hace nada.
      sinPack:   form.value.features[s.clave] !== true,
      incluidos: incluidos.value.filter(i => i.incluido_en === s.clave),
      items:     addons.value.filter(a => a.pack === s.clave),
    }))
    .filter(g => g.items.length || g.incluidos.length)

  const transversales = addons.value.filter(a => !a.pack)
  if (transversales.length) {
    grupos.push({ clave: 'transversal', titulo: 'Sirven a las dos suites',
                  sinPack: false, incluidos: [], items: transversales })
  }
  return grupos
})

// Por qué NO se puede prender este adicional, o null si se puede.
function bloqueoDe(addon) {
  if (addon.bloqueado) return addon.motivo_bloqueo || 'Todavía no se puede activar.'
  const pack = addon.pack
  if (pack && form.value.features[pack] !== true) {
    const label = suites.value.find(s => s.clave === pack)?.label || pack
    return `Necesita la suite ${label}.`
  }
  return null
}

function toggleAddon(addon) {
  if (bloqueoDe(addon)) return
  form.value.features[addon.clave] = !form.value.features[addon.clave]
}

// Al apagar una suite se caen sus adicionales: si quedaran prendidos, el backend los descarta
// igual (`sin_addons_huerfanos`) y la pantalla mostraría contratado algo que no se guardó.
function toggleSuite(suite) {
  const prender = form.value.features[suite.clave] !== true
  form.value.features[suite.clave] = prender
  if (!prender) {
    addons.value.filter(a => a.pack === suite.clave)
                .forEach(a => { form.value.features[a.clave] = false })
  }
}

// ── El plan: sólo los topes que aplican a lo que acaba de contratar ────────
//
// `suite: null` = le importa a cualquiera (sedes). El resto se muestra sólo si compró la suite
// a la que ese tope le pertenece.
function topesDe(plan) {
  return (plan.recursos || []).filter(r => !r.suite || form.value.features[r.suite] === true)
                              // «usuarios sin límite» es mentira en uso personal: es una sola persona,
                              // y eso lo dice el renglón de equipo, no una cifra.
                              .filter(r => !(plan.equipo === false && r.clave === 'usuarios'))
}

// ── Los usuarios: sólo los roles que van a poder entrar ────────────────────
//
// Un cultivador en una organización sin Cultivo loguea a una app sin una sola pantalla, y el
// que lo descubre es el cliente. El módulo del que depende cada rol lo dice el backend.
const rolesDisponibles = computed(() => {
  // Uso personal: la cuenta es la persona. No hay roles que ofrecer.
  if (esPersonal.value) return rolesAlta.value.filter(r => r.clave === 'admin')
  return rolesAlta.value.filter(r => !r.requiere_modulo || form.value.features[r.requiere_modulo] === true)
})

// Lo que REALMENTE se va a crear. Si se tilda Cultivador y después se vuelve atrás y se saca la
// suite de Cultivo, el rol queda tildado en una tarjeta que ya no se muestra: el backend lo
// descarta igual y el resumen prometería un usuario que nunca se crea.
const rolesACrear = computed(() => {
  const ok = rolesDisponibles.value.map(r => r.clave)
  return rolesSeleccionados.value.filter(r => ok.includes(r))
})

// El plan Básico incluye uno de cada rol; el admin queda fuera del cupo.
const planElegido = computed(() => planes.value.find(p => p.clave === form.value.plan))

// Cuánto va a pagar por mes: plan + suites + adicionales, con los precios del catálogo. Es
// la misma cuenta que hace `Precios.de` en el backend; acá sólo se muestra antes de crear.
const precioMensual = computed(() => {
  const plan = planElegido.value?.precio_mensual || 0
  // Uso personal: un solo número. Cuánto vale cada adicional en personal está PENDIENTE
  // (los precios de organización no sirven: la IA sola vale más que el plan), así que hasta
  // que se decida prenderlos no cambia el número — igual que `Precios.de` en el backend.
  if (esPersonal.value) return plan
  const s = suites.value.filter(x => form.value.features[x.clave] === true).reduce((t, x) => t + (x.precio_mensual || 0), 0)
  const a = addons.value.filter(x => form.value.features[x.clave] === true).reduce((t, x) => t + (x.precio_mensual || 0), 0)
  return plan + s + a
})

// ── El resumen final ───────────────────────────────────────────────────────
//
// El paso que faltaba: se creaba a ciegas. Nunca se veía junto qué contrató, contra qué topes y
// con qué usuarios — que es lo único que hay que revisar antes de apretar el botón.
const contratado = computed(() => {
  const nombre = (clave) =>
    suites.value.find(x => x.clave === clave)?.label ||
    addons.value.find(x => x.clave === clave)?.label || clave
  if (esPersonal.value) {
    // Lo que viene adentro del plan no es un «adicional»: se dice como incluido.
    const dentro = catalogo.value?.features_personal || {}
    return {
      suites:    suites.value.filter(x => form.value.features[x.clave] === true).map(x => x.label),
      addons:    addons.value.filter(x => form.value.features[x.clave] === true && !dentro[x.clave]).map(x => nombre(x.clave)),
      incluidos: addons.value.filter(x => dentro[x.clave] === true).map(x => x.label),
    }
  }
  return {
    suites: suites.value.filter(x => form.value.features[x.clave] === true).map(x => x.label),
    addons: addons.value.filter(x => form.value.features[x.clave] === true).map(x => nombre(x.clave)),
    incluidos: incluidos.value.filter(incluidoActivo).map(i => i.label),
  }
})

const PAISES    = ['Argentina', 'Uruguay', 'Colombia', 'España', 'Alemania', 'Canadá', 'Estados Unidos', 'México', 'Chile', 'Brasil', 'Otro']
const TIMEZONES = ['America/Argentina/Buenos_Aires', 'America/Montevideo', 'America/Bogota', 'America/Santiago', 'Europe/Berlin', 'America/Toronto', 'America/New_York']

// ── Usuarios ──────────────────────────────────────────────────────────
const rolesSeleccionados = ref(['admin'])
// La PERSONA detrás del admin. El usuario de ingreso es `admin@slug.com` —un identificador—,
// pero hasta sep-2026 la persona real no quedaba en ningún lado: el mail de contacto iba a la
// organización y el usuario nacía como "Admin <club>" sin mail personal, así que «olvidé mi
// contraseña» no tenía a dónde escribirle. El mail se precarga con el de contacto del paso 1:
// es la misma persona en casi todas las altas, y se puede cambiar.
// En uso personal la persona ES la cuenta y va en el paso 1: entra con `email_personal`, sin
// identificador inventado, y de ella sale el nombre del cultivo («Cultivo de Juan»).
const adminPersona = ref({ first_name: '', last_name: '', email_personal: '' })
const nombrePersona = computed(() => [adminPersona.value.first_name, adminPersona.value.last_name].filter(Boolean).join(' '))
const nombreCultivo = computed(() => `Cultivo de ${adminPersona.value.first_name || nombrePersona.value || '…'}`)
const passwordInicial    = ref('')
const passwordCopiada    = ref(false)

function toggleRol(rol) {
  if (rol === 'admin') return          // el admin siempre se crea: sin él nadie entra al club
  const idx = rolesSeleccionados.value.indexOf(rol)
  if (idx >= 0) rolesSeleccionados.value.splice(idx, 1)
  else rolesSeleccionados.value.push(rol)
}

async function copiarPassword(valor) {
  try {
    await navigator.clipboard.writeText(valor)
    passwordCopiada.value = true
    setTimeout(() => { passwordCopiada.value = false }, 1800)
  } catch { /* sin portapapeles: queda visible igual, que es lo que importa */ }
}

onMounted(async () => {
  try {
    const { data } = await getSuperAdminCatalogo()
    catalogo.value = data
    // Los módulos que trae de fábrica los decide el backend, no esta pantalla. Se completan
    // TODAS las claves (las apagadas también) para que lo que se manda sea exactamente lo que
    // se ve: si una clave viaja ausente, el backend le aplica su default y aparece prendida.
    const encendidos = data.features_por_defecto || {}
    const todas = [...(data.suites || []), ...(data.addons || [])]
    form.value.features = Object.fromEntries(todas.map(m => [m.clave, encendidos[m.clave] === true]))
    // La contraseña arranca VACÍA a propósito: el backend genera una dictable y la devuelve al
    // crear. Acá venía `data.password_default`, que era la credencial fija de toda la
    // plataforma y ya no existe — dejaba el campo mudo y el texto de abajo mintiendo.
  } catch {
    error.value = 'No se pudo cargar el catálogo de planes y módulos.'
  } finally {
    cargando.value = false
  }
})

// ── Slug preview ──────────────────────────────────────────────────────
const slugPreview = computed(() =>
  (esPersonal.value ? nombreCultivo.value : form.value.name).toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'slug'
)

function emailRol(rol) { return `${rol}@${slugPreview.value}.com` }

// ── Validación ────────────────────────────────────────────────────────
const errores = ref({})

const MAIL_OK = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function validarPaso1() {
  const e = {}
  if (esPersonal.value) {
    // La persona es la cuenta: sin nombre no hay cómo llamarla, sin mail no hay con qué entrar.
    if (!adminPersona.value.first_name.trim()) e.first_name = 'El nombre es requerido'
    if (!adminPersona.value.last_name.trim())  e.last_name  = 'El apellido es requerido'
    if (!adminPersona.value.email_personal.trim()) e.email = 'El mail es requerido: es con lo que entra'
    else if (!MAIL_OK.test(adminPersona.value.email_personal)) e.email = 'Email inválido'
  } else {
    if (!form.value.name.trim())  e.name  = 'El nombre es requerido'
    if (!form.value.email.trim()) e.email = 'El email es requerido'
    else if (!MAIL_OK.test(form.value.email)) e.email = 'Email inválido'
  }
  errores.value = e
  return !Object.keys(e).length
}

function siguiente() {
  if (pasoClave.value === 'plan' && !adminPersona.value.email_personal) adminPersona.value.email_personal = form.value.email
  if (pasoClave.value === 'identidad' && !validarPaso1()) return
  // Sin ninguna suite la organización entra y no puede hacer nada: es el error más caro del
  // alta, porque se descubre recién cuando el cliente entra a trabajar.
  if (pasoClave.value === 'modulos' && !haySuite.value) return
  if (paso.value < pasos.value.length) paso.value++
}
function anterior() { if (paso.value > 1) paso.value-- }

// ── Submit ────────────────────────────────────────────────────────────
async function handleSubmit() {
  saving.value = true
  error.value  = null
  try {
    const club = { ...form.value }
    if (esPersonal.value) {
      // No hay organización que nombrar: el cultivo se llama como la persona y el contacto es
      // ella misma (se puede cambiar después desde la ficha).
      club.name  = nombreCultivo.value
      club.email = adminPersona.value.email_personal
    }
    Object.keys(club).forEach(k => { if (club[k] === '') delete club[k] })
    const { data } = await createSuperAdminClub({
      club,
      admin:            adminPersona.value,
      roles_a_crear:    rolesACrear.value,
      password_inicial: passwordInicial.value,
    })
    creado.value = data
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || (esPersonal.value ? 'Error al crear el uso personal' : 'Error al crear la organización')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="cnv">

    <!-- Back -->
    <RouterLink :to="{ name: 'sa-clubs' }" class="cnv__back">
      <ArrowLeft :size="14" :stroke-width="2" /> Organizaciones
    </RouterLink>

    <!-- ══ SUCCESS ══ -->
    <div v-if="creado" class="cnv__success">
      <div class="cnv__success-check"><Check :size="28" :stroke-width="2.5" /></div>
      <h2 class="cnv__success-title">{{ creado.club.personal ? 'Uso personal creado' : 'Organización creada' }}</h2>
      <p class="cnv__success-sub">
        <strong>{{ creado.club.name }}</strong> está listo.
        Se {{ creado.usuarios.length === 1 ? 'creó' : 'crearon' }}
        {{ creado.usuarios.length }} usuario{{ creado.usuarios.length !== 1 ? 's' : '' }}.
      </p>

      <!-- Lo que hay que pasarle al club. Es el único momento en que está todo junto, así que
           se muestra entero y se puede copiar de una. -->
      <div class="cnv__entrega">
        <div class="cnv__entrega-head">
          <span class="cnv__entrega-title">Datos de acceso</span>
          <button type="button" class="cnv__pass-copy" @click="copiarPassword(creado.password_inicial)">
            <Check v-if="passwordCopiada" :size="14" :stroke-width="2.5" />
            <Copy v-else :size="14" :stroke-width="2" />
            {{ passwordCopiada ? 'Copiada' : 'Copiar contraseña' }}
          </button>
        </div>
        <div class="cnv__entrega-pass">
          Contraseña temporal: <code>{{ creado.password_inicial }}</code>
        </div>
        <div class="cnv__usuarios-grid">
          <div v-for="u in creado.usuarios" :key="u.id" class="cnv__usuario-card">
            <div class="cnv__usuario-role">{{ u.role }}</div>
            <div class="cnv__usuario-email">{{ u.email }}</div>
          </div>
        </div>
      </div>

      <div class="cnv__success-actions">
        <RouterLink :to="{ name: 'sa-club-detail', params: { id: creado.club.id } }" class="cnv__btn-primary">
          Ver ficha
          <ChevronRight :size="16" :stroke-width="2" />
        </RouterLink>
        <button class="cnv__btn-ghost" @click="creado = null; paso = 1">Crear otro</button>
      </div>
    </div>

    <!-- ══ CARGANDO EL CATÁLOGO ══ -->
    <div v-else-if="cargando" class="cnv__cargando">
      <DsSpinner :size="22" />
      <span>Cargando planes y módulos…</span>
    </div>

    <!-- ══ WIZARD ══ -->
    <template v-else>

      <!-- Header + stepper -->
      <div class="cnv__header">
        <h1 class="cnv__title">{{ esPersonal ? 'Nuevo uso personal' : 'Nueva organización' }}</h1>
        <div class="cnv__stepper">
          <div
            v-for="(p, i) in pasos" :key="p.clave"
            class="cnv__step"
            :class="{ 'cnv__step--done': paso > i + 1, 'cnv__step--active': paso === i + 1 }"
          >
            <div class="cnv__step-dot">
              <Check v-if="paso > i + 1" :size="12" :stroke-width="3" />
              <span v-else>{{ i + 1 }}</span>
            </div>
            <span class="cnv__step-label">{{ p.label }}</span>
          </div>
          <div class="cnv__step-line" :style="{ width: `${((paso - 1) / (pasos.length - 1)) * 100}%` }"></div>
        </div>
      </div>

      <!-- ─── Paso 1: Identidad ─── -->
      <div v-if="pasoClave === 'identidad'" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico"><Building2 :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">{{ esPersonal ? 'Quién cultiva' : 'Identidad de la organización' }}</div>
            <div class="cnv__panel-sub">{{ esPersonal ? 'La persona es la cuenta: entra con su mail' : 'Datos de identificación y contacto' }}</div>
          </div>
        </div>
        <div class="cnv__panel-body">
          <div v-if="Object.keys(errores).length" class="cnv__alert">
            Corregí los campos marcados en rojo antes de continuar.
          </div>

          <!-- Qué se da de alta. Va PRIMERO porque cambia todo lo que sigue: módulos, plan,
               quién entra y qué envoltorio ve. -->
          <div class="cnv__section-label">Qué se da de alta</div>
          <div class="cnv__tipos">
            <button type="button" class="cnv__tipo" :class="{ 'cnv__tipo--on': !esPersonal }"
                    @click="elegirTipo('organizacion')">
              <span class="cnv__suite-check">{{ !esPersonal ? '✓' : '' }}</span>
              <span class="cnv__suite-txt">
                <span class="cnv__suite-name">Una organización</span>
                <span class="cnv__suite-desc">Club, productora o proyecto de investigación: equipo, pacientes, sedes.</span>
              </span>
            </button>
            <button type="button" class="cnv__tipo" :class="{ 'cnv__tipo--on': esPersonal }"
                    @click="elegirTipo('personal')">
              <span class="cnv__suite-check">{{ esPersonal ? '✓' : '' }}</span>
              <span class="cnv__suite-txt">
                <span class="cnv__suite-name">Uso personal</span>
                <span class="cnv__suite-desc">Una persona y su cultivo: sin equipo ni pacientes. Se le puede sumar ambiente, IA y chatbot.</span>
              </span>
            </button>
          </div>

          <div class="cnv__grid">
            <!-- Uso personal: no hay organización que nombrar. La persona va acá, con su mail
                 de verdad, que es con lo que entra. El cultivo se llama como ella. -->
            <template v-if="esPersonal">
              <div class="cnv__field">
                <label class="cnv__label">Nombre <span class="cnv__req">*</span></label>
                <input v-model.trim="adminPersona.first_name" class="cnv__input" :class="{ 'cnv__input--err': errores.first_name }"
                       placeholder="Juan" autocomplete="off" />
                <span v-if="errores.first_name" class="cnv__err">{{ errores.first_name }}</span>
              </div>
              <div class="cnv__field">
                <label class="cnv__label">Apellido <span class="cnv__req">*</span></label>
                <input v-model.trim="adminPersona.last_name" class="cnv__input" :class="{ 'cnv__input--err': errores.last_name }"
                       placeholder="Pérez" autocomplete="off" />
                <span v-if="errores.last_name" class="cnv__err">{{ errores.last_name }}</span>
              </div>
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Mail <span class="cnv__req">*</span></label>
                <input v-model.trim="adminPersona.email_personal" type="email" class="cnv__input" :class="{ 'cnv__input--err': errores.email }"
                       placeholder="juan@gmail.com" autocomplete="off" />
                <span v-if="errores.email" class="cnv__err">{{ errores.email }}</span>
                <span v-else class="cnv__hint">Entra con este mail; ahí le llega «olvidé mi contraseña». Su cultivo se va a llamar <strong>{{ nombreCultivo }}</strong> (se cambia desde la ficha).</span>
              </div>
            </template>
            <template v-else>
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Nombre de la organización <span class="cnv__req">*</span></label>
                <input v-model.trim="form.name" class="cnv__input" :class="{ 'cnv__input--err': errores.name }"
                       placeholder="Club Medicinal del Sur" />
                <span v-if="errores.name" class="cnv__err">{{ errores.name }}</span>
                <span v-else class="cnv__hint">Slug: <code>{{ slugPreview }}</code></span>
              </div>
              <div class="cnv__field cnv__field--full">
                <label class="cnv__label">Razón social</label>
                <input v-model.trim="form.legal_name" class="cnv__input"
                       placeholder="Asociación Civil Club Medicinal del Sur" />
              </div>
              <div class="cnv__field">
                <label class="cnv__label">Email de contacto <span class="cnv__req">*</span></label>
                <input v-model.trim="form.email" type="email" class="cnv__input" :class="{ 'cnv__input--err': errores.email }"
                       placeholder="contacto@clubmedicinal.org" />
                <span v-if="errores.email" class="cnv__err">{{ errores.email }}</span>
              </div>
            </template>
            <div class="cnv__field">
              <label class="cnv__label">Teléfono</label>
              <input v-model.trim="form.phone" class="cnv__input" placeholder="+54 9 11 1234-5678" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Ciudad</label>
              <input v-model.trim="form.city" class="cnv__input" placeholder="Buenos Aires" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Provincia</label>
              <input v-model.trim="form.state" class="cnv__input" placeholder="CABA" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">País</label>
              <select v-model="form.country" class="cnv__input">
                <option v-for="p in PAISES" :key="p" :value="p">{{ p }}</option>
              </select>
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Zona horaria</label>
              <select v-model="form.timezone" class="cnv__input">
                <option v-for="tz in TIMEZONES" :key="tz" :value="tz">{{ tz }}</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- ─── Paso 2: Módulos ───
           Va ANTES que el plan porque el plan es una consecuencia: recién sabiendo qué compró
           se puede mostrar contra qué topes mide y qué roles tiene sentido darle de alta. -->
      <div v-if="pasoClave === 'modulos'" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--purple"><Zap :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Qué puede hacer</div>
            <div class="cnv__panel-sub">{{ esPersonal ? 'Viene con Cultivo; el ambiente, la IA y el chatbot se le suman uno por uno' : 'Primero la suite; después lo que se le suma encima' }}</div>
          </div>
        </div>
        <div v-if="esPersonal" class="cnv__panel-body">
          <!-- Uso personal: no se eligen suites. Cultivo viene adentro del plan; lo que se
               decide es si suma el ambiente, la IA y el chatbot. -->
          <div class="cnv__section-label">Viene adentro</div>
          <div v-for="inc in incluidosPersonal" :key="inc.clave" class="cnv__incluido">
            <Check :size="14" :stroke-width="3" class="cnv__incluido-ico" />
            <div>
              <div class="cnv__incluido-name">{{ inc.label }}</div>
              <div class="cnv__incluido-desc">Incluido en el plan Personal — {{ inc.desc }}</div>
            </div>
          </div>

          <div class="cnv__section-label" style="margin-top:1.25rem">Se puede sumar</div>
          <div class="cnv__feat-grid">
            <div
              v-for="a in addonsPersonal" :key="a.clave"
              class="cnv__feat-toggle"
              :class="{ 'cnv__feat-toggle--on': form.features[a.clave], 'cnv__feat-toggle--warn': a.incompleto, 'cnv__feat-toggle--lock': !!bloqueoPersonal(a) }"
              @click="togglePersonal(a)"
            >
              <div class="cnv__feat-left">
                <div>
                  <!-- Sin precio a propósito: cuánto vale cada uno en personal está pendiente. -->
                  <div class="cnv__feat-name">{{ a.label }}</div>
                  <div class="cnv__feat-desc">{{ a.desc }}</div>
                  <div v-if="bloqueoPersonal(a)" class="cnv__feat-requiere">
                    <Lock :size="11" :stroke-width="2.5" /> {{ bloqueoPersonal(a) }}
                  </div>
                  <div v-else-if="a.requiere && form.features[a.clave]" class="cnv__feat-requiere">
                    <AlertTriangle :size="11" :stroke-width="2.5" /> {{ a.requiere }}
                  </div>
                </div>
              </div>
              <div class="cnv__toggle__track cnv__toggle__track--sm"
                   :class="{ 'cnv__toggle__track--checked': form.features[a.clave] }">
                <div class="cnv__toggle__thumb cnv__toggle__thumb--sm"></div>
              </div>
            </div>
          </div>
        </div>
        <div v-else class="cnv__panel-body">

          <!-- Suites: lo que realmente se vende. Un club puede tomar una, la otra o las dos. -->
          <div class="cnv__section-label">Suites</div>
          <div class="cnv__suites">
            <button
              v-for="s in suites" :key="s.clave"
              type="button"
              class="cnv__suite"
              :class="{ 'cnv__suite--on': form.features[s.clave] }"
              @click="toggleSuite(s)"
            >
              <span class="cnv__suite-check">{{ form.features[s.clave] ? '✓' : '' }}</span>
              <span class="cnv__suite-txt">
                <span class="cnv__suite-name">{{ s.label }} <span class="cnv__precio">{{ formatARS(s.precio_mensual) }}/mes</span></span>
                <span class="cnv__suite-desc">{{ s.desc }}</span>
              </span>
            </button>
          </div>
          <p v-if="!haySuite" class="cnv__warn">
            Sin ninguna suite, la organización entra pero no puede operar. Elegí al menos una.
          </p>

          <!-- Cada adicional DEBAJO de la suite que extiende, no en una grilla plana de diez.
               El módulo incluido va acá adentro, con candado: no es una categoría aparte, es
               una fila más de lo que ya se compró. -->
          <div v-for="g in addonsAgrupados" :key="g.clave" class="cnv__grupo">
            <div class="cnv__section-label">{{ g.titulo }}</div>
            <p v-if="g.sinPack" class="cnv__grupo-nota">
              {{ g.packLabel }} no está contratado: estos módulos no se pueden sumar.
            </p>

            <div v-for="inc in g.incluidos" :key="inc.clave"
                 class="cnv__incluido" :class="{ 'cnv__incluido--off': !incluidoActivo(inc) }">
              <Check v-if="incluidoActivo(inc)" :size="14" :stroke-width="3" class="cnv__incluido-ico" />
              <Lock v-else :size="13" :stroke-width="2" class="cnv__incluido-ico" />
              <div>
                <div class="cnv__incluido-name">{{ inc.label }}</div>
                <div class="cnv__incluido-desc">
                  <template v-if="incluidoActivo(inc)">Ya viene incluido — {{ inc.desc }}</template>
                  <template v-else>Necesita la suite {{ inc.incluido_en_label }}</template>
                </div>
              </div>
            </div>

            <div class="cnv__feat-grid">
              <div
                v-for="a in g.items" :key="a.clave"
                class="cnv__feat-toggle"
                :class="{
                  'cnv__feat-toggle--on':   form.features[a.clave],
                  'cnv__feat-toggle--warn': a.incompleto && !bloqueoDe(a),
                  'cnv__feat-toggle--lock': !!bloqueoDe(a),
                }"
                @click="toggleAddon(a)"
              >
                <div class="cnv__feat-left">
                  <div>
                    <div class="cnv__feat-name">
                      {{ a.label }}
                      <span v-if="a.precio_mensual" class="cnv__precio">{{ formatARS(a.precio_mensual) }}/mes</span>
                    </div>
                    <div class="cnv__feat-desc">{{ a.desc }}</div>
                    <!-- Por qué NO se puede prender. Antes esto vivía en letra chica que nadie
                         leía y el toggle se dejaba mover igual: quedaba un módulo contratado
                         que no hacía nada. -->
                    <div v-if="bloqueoDe(a)" class="cnv__feat-lock">
                      <Lock :size="11" :stroke-width="2.5" /> {{ bloqueoDe(a) }}
                    </div>
                    <!-- Lo que le va a faltar para andar aunque se prenda. -->
                    <div v-else-if="a.requiere && form.features[a.clave]" class="cnv__feat-requiere">
                      <AlertTriangle :size="11" :stroke-width="2.5" />
                      {{ a.requiere }}
                    </div>
                  </div>
                </div>
                <div class="cnv__toggle__track cnv__toggle__track--sm"
                     :class="{ 'cnv__toggle__track--checked': form.features[a.clave] }">
                  <div class="cnv__toggle__thumb cnv__toggle__thumb--sm"></div>
                </div>
              </div>
            </div>
          </div>

          <!-- En construcción: se listan para que nadie los prometa creyendo que están. -->
          <template v-if="enConstruccion.length">
            <div class="cnv__section-label" style="margin-top:1.5rem">Todavía no disponible</div>
            <div class="cnv__construccion">
              <div v-for="e in enConstruccion" :key="e.clave" class="cnv__constr-item">
                <Info :size="14" :stroke-width="2" class="cnv__constr-ico" />
                <div>
                  <div class="cnv__constr-name">{{ e.label }}</div>
                  <div class="cnv__constr-desc">{{ e.desc }}</div>
                </div>
                <span class="cnv__constr-badge">En construcción</span>
              </div>
            </div>
          </template>

        </div>
      </div>

      <!-- ─── Paso 3: Plan ───
           El plan dice CUÁNTO, y sólo se muestran los topes que le importan a lo que acaba de
           contratar: nombrarle salas y plantas a una organización sin Cultivo es media tarjeta
           en ruido, y desde ahí no hay forma de saber cuáles cuentan. -->
      <div v-if="pasoClave === 'plan'" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--purple"><Gauge :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Cuánto puede crecer</div>
            <div class="cnv__panel-sub">{{ esPersonal ? 'El uso personal tiene un solo plan: una persona, su casa, dos espacios' : 'Los topes de lo que ya eligió. Qué puede hacer se decidió en el paso anterior' }}</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <div class="cnv__planes">
            <button
              v-for="p in planesOfrecidos" :key="p.clave"
              type="button"
              class="cnv__plan"
              :class="{ 'cnv__plan--on': form.plan === p.clave }"
              @click="form.plan = p.clave"
            >
              <div class="cnv__plan-top">
                <span class="cnv__plan-check"><Check v-if="form.plan === p.clave" :size="12" :stroke-width="3" /></span>
                <span class="cnv__plan-name">{{ p.label }}</span>
                <span class="cnv__precio cnv__precio--plan">{{ formatARS(p.precio_mensual) }}/mes</span>
              </div>
              <ul class="cnv__plan-limites">
                <li v-for="r in topesDe(p)" :key="r.clave">{{ r.texto }}</li>
                <!-- El cupo de usuarios no es un número, así que no puede decirse como uno:
                     "5 usuarios" no se vende ni se explica. -->
                <li>
                  {{ p.equipo === false ? 'una sola persona, sin equipo'
                     : p.usuarios_por_rol === 1 ? 'un usuario de cada rol'
                     : (p.usuarios_por_rol ? `${p.usuarios_por_rol} usuarios por rol` : 'usuarios sin límite') }}
                </li>
              </ul>
            </button>
          </div>

          <div class="cnv__row-2" style="margin-top:1.5rem">
            <div class="cnv__field">
              <label class="cnv__label">Vigente hasta</label>
              <AppDatePicker v-model="form.plan_activo_hasta" />
              <span class="cnv__hint">Dejá vacío para sin vencimiento</span>
            </div>
            <label class="cnv__toggle">
              <input v-model="form.plan_trial" type="checkbox" class="cnv__toggle__input" />
              <div class="cnv__toggle__track"><div class="cnv__toggle__thumb"></div></div>
              <div>
                <div class="cnv__toggle__label">Período de prueba</div>
                <div class="cnv__hint">Muestra el cartel "Trial" en el panel de la organización</div>
              </div>
            </label>
          </div>

        </div>
      </div>

      <!-- ─── Paso 4: Acceso inicial ─── -->
      <div v-if="pasoClave === 'acceso'" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--blue"><Users :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">{{ esPersonal ? 'Vigencia y acceso' : 'Con qué entran' }}</div>
            <div class="cnv__panel-sub">{{ esPersonal ? 'Hasta cuándo, si es una prueba, y con qué contraseña entra' : 'Qué usuarios se crean y con qué contraseña' }}</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <!-- Uso personal: el plan es uno solo, así que no tiene paso propio. Acá queda lo que
               sí se decide de él: hasta cuándo y si es una prueba. -->
          <template v-if="esPersonal">
            <div class="cnv__section-label">Plan Personal</div>
            <p class="cnv__hint" style="margin:0 0 .75rem">
              {{ formatARS(planElegido?.precio_mensual || 0) }}/mes ·
              {{ [...topesDe(planElegido || {}).map(r => r.texto), 'una sola persona, sin equipo'].join(' · ') }}
            </p>
            <div class="cnv__row-2" style="margin-bottom:1.5rem">
              <div class="cnv__field">
                <label class="cnv__label">Vigente hasta</label>
                <AppDatePicker v-model="form.plan_activo_hasta" />
                <span class="cnv__hint">Dejá vacío para sin vencimiento</span>
              </div>
              <label class="cnv__toggle">
                <input v-model="form.plan_trial" type="checkbox" class="cnv__toggle__input" />
                <div class="cnv__toggle__track"><div class="cnv__toggle__thumb"></div></div>
                <div>
                  <div class="cnv__toggle__label">Período de prueba</div>
                  <div class="cnv__hint">Muestra el cartel "Trial" en su panel</div>
                </div>
              </label>
            </div>
          </template>

          <!-- En claro y a propósito: es temporal y hay que poder dictársela al club. Detrás
               de puntitos había que acordarse de lo que uno mismo acababa de tipear. -->
          <div class="cnv__field cnv__pass" style="margin-bottom:1.5rem">
            <label class="cnv__label">Contraseña temporal</label>
            <div class="cnv__pass-row">
              <input v-model="passwordInicial" type="text" autocomplete="off" spellcheck="false"
                     class="cnv__input cnv__input--mono" placeholder="ClaveDelClub1" />
              <button type="button" class="cnv__pass-copy" :disabled="!passwordInicial"
                      @click="copiarPassword(passwordInicial)">
                <Check v-if="passwordCopiada" :size="14" :stroke-width="2.5" />
                <Copy v-else :size="14" :stroke-width="2" />
                {{ passwordCopiada ? 'Copiada' : 'Copiar' }}
              </button>
            </div>
            <span class="cnv__hint">
              <strong>Dejalo vacío y se genera una sola.</strong> Es dictable por teléfono (sin
              ceros ni eles) y te la mostramos al crear{{ esPersonal ? 'lo' : ' la organización' }}.
              <template v-if="!esPersonal">La misma para todos los usuarios que se creen; cada uno la cambia al entrar.</template>
              <template v-else>La cambia al entrar.</template>
            </span>
          </div>

          <template v-if="esPersonal">
            <p class="cnv__hint">
              Entra con <code>{{ adminPersona.email_personal }}</code>. En uso personal la cuenta es la
              persona: se crea sólo su usuario y no se puede sumar a nadie más después. Si el cultivo
              crece y necesita equipo, se lo pasa a un plan de organización desde la ficha.
            </p>
          </template>
          <div v-else class="cnv__section-label">Quién es el admin</div>
          <p v-if="!esPersonal" class="cnv__hint" style="margin:0 0 .6rem">
            Entra con <code>{{ emailRol('admin') }}</code>, que es un usuario, no una casilla. Su mail
            de verdad es a donde le llega el link de «olvidé mi contraseña».
          </p>
          <div v-if="!esPersonal" class="cnv__grid-3" style="margin-bottom:1.5rem">
            <div class="cnv__field">
              <label class="cnv__label">Nombre</label>
              <input v-model.trim="adminPersona.first_name" type="text" class="cnv__input" placeholder="Juan" autocomplete="off" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Apellido</label>
              <input v-model.trim="adminPersona.last_name" type="text" class="cnv__input" placeholder="Pérez" autocomplete="off" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Mail personal</label>
              <input v-model.trim="adminPersona.email_personal" type="email" class="cnv__input" placeholder="juan@gmail.com" autocomplete="off" />
            </div>
          </div>

          <div v-if="!esPersonal" class="cnv__section-label">Usuarios a crear</div>
          <div v-if="!esPersonal" class="cnv__roles-grid">
            <div
              v-for="r in rolesDisponibles" :key="r.clave"
              class="cnv__role-card"
              :class="{
                'cnv__role-card--on':       rolesSeleccionados.includes(r.clave),
                'cnv__role-card--required': r.clave === 'admin',
              }"
              @click="toggleRol(r.clave)"
            >
              <div class="cnv__role-top">
                <div class="cnv__role-check">
                  <Check v-if="rolesSeleccionados.includes(r.clave)" :size="12" :stroke-width="3" />
                </div>
                <span class="cnv__role-label">{{ r.label }}</span>
                <span v-if="r.clave === 'admin'" class="cnv__role-req">siempre</span>
              </div>
              <div class="cnv__role-desc">{{ r.desc }}</div>
              <div class="cnv__role-email">{{ emailRol(r.clave) }}</div>
            </div>
          </div>
          <p v-if="!esPersonal" class="cnv__hint" style="margin-top:.75rem">
            Sólo aparecen los roles que le sirven a lo que contrató: un cultivador en una
            organización sin Cultivo entra a una app sin una sola pantalla. Los demás se crean
            después desde la ficha.
          </p>
          <p v-if="!esPersonal && planElegido?.usuarios_por_rol" class="cnv__hint">
            El plan {{ planElegido.label }} incluye uno de cada rol. El admin no cuenta: se pueden
            dar de alta los que hagan falta.
          </p>
        </div>
      </div>

      <!-- ─── Paso 5: Resumen ───
           El paso que faltaba. Se creaba a ciegas: nunca se veía junto qué contrató, contra qué
           topes y con qué usuarios, que es lo único que hay que revisar antes de apretar. -->
      <div v-if="pasoClave === 'resumen'" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico"><Check :size="18" :stroke-width="2" /></div>
          <div>
            <div class="cnv__panel-title">Revisá antes de crear</div>
            <div class="cnv__panel-sub">{{ esPersonal ? 'Esto es lo que va a tener' : 'Esto es lo que va a tener la organización' }}</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <div class="cnv__res">
            <div class="cnv__res-row">
              <span class="cnv__res-k">{{ esPersonal ? 'Quién cultiva' : 'Organización' }}</span>
              <span class="cnv__res-v">
                <strong>{{ esPersonal ? nombrePersona : form.name }}</strong>
                <span v-if="esPersonal" class="cnv__res-sub">{{ adminPersona.email_personal }} · su cultivo: <strong>{{ nombreCultivo }}</strong></span>
                <span v-else class="cnv__res-sub">{{ form.email }} · <code>{{ slugPreview }}</code></span>
              </span>
            </div>

            <div class="cnv__res-row">
              <span class="cnv__res-k">Qué puede hacer</span>
              <span class="cnv__res-v">
                <strong>{{ contratado.suites.join(' + ') || 'Ninguna suite' }}</strong>
                <span v-if="esPersonal" class="cnv__res-sub">Sin pacientes, sin dispensa, sin equipo.</span>
                <span v-if="contratado.incluidos.length" class="cnv__res-sub">
                  Incluye: {{ contratado.incluidos.join(', ') }}
                </span>
                <span class="cnv__res-sub">
                  {{ esPersonal ? 'Le sumó' : 'Adicionales' }}: {{ contratado.addons.join(', ') || (esPersonal ? 'nada' : 'ninguno') }}
                </span>
              </span>
            </div>

            <div class="cnv__res-row">
              <span class="cnv__res-k">Cuánto puede crecer</span>
              <span class="cnv__res-v">
                <strong>Plan {{ planElegido?.label }}{{ form.plan_trial ? ' · en prueba' : '' }}</strong>
                <span class="cnv__res-sub">
                  {{ [...topesDe(planElegido || {}).map(r => r.texto), ...(esPersonal ? ['una sola persona'] : [])].join(' · ') }}
                </span>
                <span class="cnv__res-sub">
                  Vigencia: {{ form.plan_activo_hasta || 'sin vencimiento' }}
                </span>
              </span>
            </div>

            <div class="cnv__res-row">
              <span class="cnv__res-k">Cuánto paga</span>
              <span class="cnv__res-v">
                <strong>{{ formatARS(precioMensual) }} por mes</strong>
                <span class="cnv__res-sub">
                  {{ form.plan_trial ? 'En prueba: no factura hasta que salga del trial.' : (esPersonal ? 'Plan Personal, un solo número con lo que le sumó adentro.' : 'Plan + suites + adicionales, a precio de lista.') }}
                </span>
              </span>
            </div>

            <div class="cnv__res-row">
              <span class="cnv__res-k">{{ esPersonal ? 'Con qué entra' : 'Con qué entran' }}</span>
              <span class="cnv__res-v">
                <strong v-if="esPersonal">{{ adminPersona.email_personal }}</strong>
                <strong v-else>{{ rolesACrear.length }} usuario{{ rolesACrear.length === 1 ? '' : 's' }}</strong>
                <span v-if="!esPersonal" class="cnv__res-sub">{{ rolesACrear.join(', ') }}</span>
                <span v-if="!esPersonal" class="cnv__res-sub">
                  Admin: {{ nombrePersona || 'sin nombre' }}
                  · {{ adminPersona.email_personal || 'sin mail personal' }}
                </span>
                <span class="cnv__res-sub">
                  Contraseña: {{ passwordInicial || 'se genera una y te la mostramos' }}
                </span>
              </span>
            </div>
          </div>

          <div v-if="error" class="cnv__alert" style="margin-top:1.25rem">{{ error }}</div>
        </div>
      </div>

      <!-- ── Navegación ── -->
      <div class="cnv__nav">
        <button v-if="paso > 1" class="cnv__btn-ghost" @click="anterior">
          <ChevronLeft :size="16" :stroke-width="2" /> Anterior
        </button>
        <div class="cnv__nav-spacer"></div>
        <button v-if="paso < pasos.length" class="cnv__btn-primary"
                :disabled="pasoClave === 'modulos' && !haySuite" @click="siguiente">
          Siguiente <ChevronRight :size="16" :stroke-width="2" />
        </button>
        <button v-else class="cnv__btn-primary" :disabled="saving" @click="handleSubmit">
          <DsSpinner v-if="saving" :size="15" />
          <Check v-else :size="16" :stroke-width="2.5" />
          {{ saving ? 'Creando…' : (esPersonal ? 'Crear uso personal' : 'Crear organización') }}
        </button>
      </div>

    </template>
  </div>
</template>

<style scoped>
.cnv {
  padding: 2rem 2.5rem 3rem;
}

.cnv__back {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .78rem; font-weight: 600; color: var(--c-slate-500);
  text-decoration: none; margin-bottom: 1.5rem;
  transition: color .15s;
}
.cnv__back:hover { color: var(--c-slate-900); }

/* Qué se da de alta: dos tarjetas, el mismo dibujo que las suites */
.cnv__tipos { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 1.5rem; }
.cnv__tipo {
  display: flex; align-items: center; gap: 12px; text-align: left; cursor: pointer;
  padding: 14px 16px; border-radius: 12px; border: 1.5px solid var(--c-slate-200); background: #fff;
  transition: all .15s;
}
.cnv__tipo--on { border-color: var(--c-leaf-500, #5A8A72); background: var(--c-leaf-50, #F4F8F5); }
.cnv__tipo--on .cnv__suite-check { background: var(--c-leaf-800, #1A3D2E); border-color: var(--c-leaf-800, #1A3D2E); }
@media (max-width: 640px) { .cnv__tipos { grid-template-columns: 1fr; } }

/* Header + stepper */
.cnv__header { margin-bottom: 2rem; }
.cnv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 1.5rem; letter-spacing: -.04em; }

.cnv__stepper {
  position: relative;
  display: flex; align-items: center; gap: 0;
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200);
  border-radius: 12px; padding: .875rem 1.25rem;
}
.cnv__step {
  display: flex; align-items: center; gap: .5rem;
  flex: 1; position: relative; z-index: 1;
}
.cnv__step:last-child { flex: 0; }
.cnv__step-dot {
  width: 26px; height: 26px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: .75rem; font-weight: 700; flex-shrink: 0;
  background: var(--c-slate-200); color: var(--c-slate-400);
  border: 2px solid var(--c-slate-200);
  transition: all .2s;
}
.cnv__step--active .cnv__step-dot {
  background: var(--c-slate-900); color: #fff; border-color: var(--c-slate-900);
}
.cnv__step--done .cnv__step-dot {
  background: #1b5e20; color: #fff; border-color: #1b5e20;
}
.cnv__step-label {
  font-size: .78rem; font-weight: 600; color: var(--c-slate-400);
  white-space: nowrap;
}
.cnv__step--active .cnv__step-label { color: var(--c-slate-900); }
.cnv__step--done .cnv__step-label   { color: #1b5e20; }

/* Connector line */
.cnv__step:not(:last-child)::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--c-slate-200);
  margin: 0 .75rem;
}
.cnv__step-line { display: none; } /* handled by ::after */

/* Panel */
.cnv__panel {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 16px; overflow: hidden;
  margin-bottom: 1.25rem;
}
.cnv__panel-header {
  display: flex; align-items: center; gap: .875rem;
  padding: 1.1rem 1.4rem; border-bottom: 1px solid var(--c-slate-100);
  background: #fafbfc;
}
.cnv__panel-ico {
  width: 38px; height: 38px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(27,94,32,.1); color: #1b5e20;
}
.cnv__panel-ico--purple { background: rgba(124,58,237,.1); color: #7c3aed; }
.cnv__panel-ico--blue   { background: rgba(3,105,161,.1);  color: #0369a1; }
.cnv__panel-title { font-size: .9rem; font-weight: 800; color: var(--c-slate-900); }
.cnv__panel-sub   { font-size: .75rem; color: var(--c-slate-400); margin-top: .1rem; }
.cnv__panel-body  { padding: 1.4rem; }

/* Form */
.cnv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.cnv__grid-3 { display: grid; grid-template-columns: 1fr 1fr 1.4fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__grid, .cnv__grid-3 { grid-template-columns: 1fr; } }
.cnv__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__row-2 { grid-template-columns: 1fr; } }

.cnv__field { display: flex; flex-direction: column; gap: .3rem; }
.cnv__field--full { grid-column: 1 / -1; }
.cnv__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.cnv__req   { color: #dc2626; }
.cnv__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  padding: .6rem .9rem; font-size: .875rem; color: var(--c-slate-900);
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.cnv__input:focus { outline: none; border-color: #1b5e20; background: #fff; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.cnv__input--err  { border-color: #dc2626; }
.cnv__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.cnv__hint { font-size: .72rem; color: var(--c-slate-400); }
.cnv__hint code { background: var(--c-slate-100); padding: .1em .4em; border-radius: 4px; font-size: .85em; }
.cnv__alert {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .75rem 1rem; border-radius: 9px; font-size: .82rem; margin-bottom: 1rem;
}
.cnv__section-label {
  font-size: .68rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .06em; color: var(--c-slate-400); margin-bottom: .6rem;
}

/* Planes */
.cnv__suites { display: flex; flex-direction: column; gap: 10px; }
.cnv__suite {
  display: flex; align-items: center; gap: 12px; text-align: left; cursor: pointer;
  padding: 14px 16px; border-radius: 12px; border: 1.5px solid var(--c-slate-200); background: #fff;
  transition: all .15s;
}
.cnv__suite--on { border-color: var(--c-leaf-500, #5A8A72); background: var(--c-leaf-50, #F4F8F5); }
.cnv__suite-check {
  width: 22px; height: 22px; border-radius: 6px; flex-shrink: 0;
  border: 1.5px solid var(--c-slate-300); display: grid; place-items: center;
  font-size: 13px; color: #fff; font-weight: 700;
}
.cnv__suite--on .cnv__suite-check { background: var(--c-leaf-800, #1A3D2E); border-color: var(--c-leaf-800, #1A3D2E); }
.cnv__suite-txt { display: flex; flex-direction: column; gap: 2px; }
.cnv__suite-name { font-size: 15px; font-weight: 700; color: var(--c-slate-900); }
.cnv__suite-desc { font-size: 12px; color: var(--c-slate-500); line-height: 1.4; }
.cnv__warn { margin: 10px 0 0; font-size: 12px; color: #b45309; }
.cnv__feat-toggle--warn { border-color: #fcd34d; }
/* Cargando el catálogo */
.cnv__cargando {
  display: flex; align-items: center; justify-content: center; gap: .75rem;
  padding: 4rem 0; color: var(--c-slate-500); font-size: .85rem;
}

/* Planes — dos tarjetas con sus topes a la vista */
.cnv__planes { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 700px) { .cnv__planes { grid-template-columns: 1fr; } }
.cnv__plan {
  padding: 1rem 1.125rem; border: 1.5px solid var(--c-slate-200); border-radius: 12px;
  background: var(--c-slate-50); text-align: left; cursor: pointer; transition: all .15s;
}
.cnv__plan:hover:not(.cnv__plan--on) { border-color: var(--c-slate-400); background: var(--c-slate-100); }
.cnv__plan--on { border-color: #1b5e20; background: #f0fdf4; }
.cnv__plan-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .625rem; }
.cnv__plan-check {
  width: 18px; height: 18px; border-radius: 5px; flex-shrink: 0;
  border: 1.5px solid var(--c-slate-300); background: #fff;
  display: flex; align-items: center; justify-content: center; color: #fff;
}
.cnv__plan--on .cnv__plan-check { background: #1b5e20; border-color: #1b5e20; }
.cnv__plan-name { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); }
.cnv__precio { font-size: .7rem; font-weight: 700; color: var(--c-slate-500); font-variant-numeric: tabular-nums; margin-left: .3rem; }
.cnv__precio--plan { margin-left: auto; }
.cnv__plan-limites { list-style: none; margin: 0; padding: 0; display: grid; gap: .25rem; }
.cnv__plan-limites li { font-size: .74rem; color: var(--c-slate-500); line-height: 1.35; }
.cnv__plan--on .cnv__plan-limites li { color: var(--c-slate-600); }

/* Incluidos en la suite — sin interruptor, porque no hay nada que decidir */
/* El incluido ya no vive en una grilla aparte: es una fila dentro del grupo de su suite. */
.cnv__incluido {
  margin-bottom: .4rem;
  display: flex; align-items: flex-start; gap: .55rem;
  padding: .7rem .85rem; border: 1px dashed var(--c-slate-300); border-radius: 10px;
  background: #f0fdf4;
}
.cnv__incluido--off { background: var(--c-slate-50); }
.cnv__incluido-ico { flex-shrink: 0; margin-top: .1rem; color: #1b5e20; }
.cnv__incluido--off .cnv__incluido-ico { color: var(--c-slate-400); }
.cnv__incluido-name { font-size: .8rem; font-weight: 700; color: var(--c-slate-900); }
.cnv__incluido--off .cnv__incluido-name { color: var(--c-slate-500); }
.cnv__incluido-desc { font-size: .69rem; color: var(--c-slate-500); line-height: 1.35; margin-top: .1rem; }

/* Qué le falta a un módulo prendido para andar de verdad */
.cnv__feat-requiere {
  display: flex; align-items: center; gap: .3rem; margin-top: .35rem;
  font-size: .66rem; font-weight: 600; color: #b45309; line-height: 1.3;
}

/* En construcción — se lista para que nadie lo prometa creyendo que está */
.cnv__construccion { display: grid; gap: .5rem; }
.cnv__constr-item {
  display: flex; align-items: center; gap: .6rem;
  padding: .7rem .85rem; border: 1px solid var(--c-slate-200); border-radius: 10px;
  background: var(--c-slate-50);
}
.cnv__constr-ico  { flex-shrink: 0; color: var(--c-slate-400); }
.cnv__constr-name { font-size: .8rem; font-weight: 700; color: var(--c-slate-500); }
.cnv__constr-desc { font-size: .69rem; color: var(--c-slate-400); line-height: 1.35; }
.cnv__constr-badge {
  margin-left: auto; flex-shrink: 0;
  font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em;
  color: var(--c-slate-500); background: var(--c-slate-200);
  padding: .2rem .45rem; border-radius: 5px;
}

/* Contraseña temporal — visible a propósito */
.cnv__pass { max-width: 420px; }
.cnv__pass-row { display: flex; gap: .5rem; align-items: stretch; }
.cnv__pass-row .cnv__input { flex: 1; }
.cnv__input--mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: .02em; }
.cnv__pass-copy {
  display: inline-flex; align-items: center; gap: .35rem; flex-shrink: 0;
  padding: 0 .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  background: #fff; color: var(--c-slate-600);
  font-size: .75rem; font-weight: 700; cursor: pointer; transition: all .15s;
}
.cnv__pass-copy:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.cnv__pass-copy:disabled { opacity: .5; cursor: not-allowed; }

/* Lo que hay que pasarle al club, todo junto */
.cnv__entrega {
  border: 1px solid var(--c-slate-200); border-radius: 12px;
  background: var(--c-slate-50); padding: 1rem 1.125rem; margin-bottom: 1.5rem; text-align: left;
}
.cnv__entrega-head { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: .625rem; }
.cnv__entrega-title {
  font-size: .7rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em;
  color: var(--c-slate-500);
}
.cnv__entrega-pass { font-size: .8rem; color: var(--c-slate-600); margin-bottom: .75rem; }
.cnv__entrega-pass code {
  font-size: .85rem; font-weight: 700; color: var(--c-slate-900);
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 6px; padding: .15rem .4rem;
}

/* Toggle */
.cnv__toggle {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: .75rem 1rem; background: var(--c-slate-50);
  border: 1.5px solid var(--c-slate-200); border-radius: 10px; cursor: pointer;
}
.cnv__toggle:hover { border-color: #1b5e20; }
.cnv__toggle__input { display: none; }
.cnv__toggle__track {
  width: 40px; height: 22px; background: var(--c-slate-300); border-radius: 999px;
  position: relative; transition: background .2s; flex-shrink: 0; margin-top: .15rem;
}
.cnv__toggle__input:checked + .cnv__toggle__track { background: #1b5e20; }
.cnv__toggle__thumb {
  position: absolute; width: 16px; height: 16px; background: #fff;
  border-radius: 50%; top: 3px; left: 3px;
  transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.cnv__toggle__input:checked + .cnv__toggle__track .cnv__toggle__thumb { left: 21px; }
.cnv__toggle__label { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }

/* Compact toggle for features */
.cnv__toggle__track--sm  { width: 32px; height: 18px; flex-shrink: 0; }
.cnv__toggle__thumb--sm  { width: 12px; height: 12px; top: 3px; left: 3px; }
.cnv__toggle__input:checked + .cnv__toggle__track--sm .cnv__toggle__thumb--sm { left: 17px; }
/* El adicional se prende clickeando la tarjeta entera, no un checkbox escondido: el área de
   click era el interruptor de 32px y el resto de la tarjeta no hacía nada. Sin `input`, el
   estado lo pinta la clase. */
.cnv__toggle__track--checked { background: #1b5e20; }
.cnv__toggle__track--checked .cnv__toggle__thumb--sm { left: 17px; }

/* Feature flags grid */
.cnv__feat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px,1fr)); gap: .4rem; }
.cnv__feat-toggle {
  display: flex; align-items: center; gap: .6rem;
  padding: .6rem .75rem; border-radius: 9px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  cursor: pointer; transition: border-color .15s, background .15s;
  user-select: none;
}
.cnv__feat-toggle--on { border-color: #bbf7d0; background: #f0fdf4; }
/* No se puede prender: le falta la suite, o está bloqueado de plataforma. Se muestra igual —
   ocultarlo haría creer que el módulo no existe. */
.cnv__feat-toggle--lock { opacity: .55; cursor: not-allowed; background: var(--c-slate-50); }
.cnv__feat-lock {
  display: flex; align-items: center; gap: .3rem; margin-top: .35rem;
  font-size: .68rem; font-weight: 600; color: var(--c-slate-500);
}

/* Un grupo de adicionales por suite. */
.cnv__grupo { margin-top: 1.5rem; }
.cnv__grupo-nota {
  margin: 0 0 .6rem; font-size: .72rem; color: #b45309;
  background: var(--c-amber-100); border-radius: 8px; padding: .45rem .7rem;
}

/* Resumen final: dos columnas, etiqueta y valor. */
.cnv__res { display: flex; flex-direction: column; gap: .1rem; }
.cnv__res-row {
  display: grid; grid-template-columns: 180px 1fr; gap: 1rem;
  padding: .85rem 0; border-bottom: 1px solid var(--c-slate-100);
}
.cnv__res-row:last-child { border-bottom: none; }
.cnv__res-k {
  font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em;
  color: var(--c-slate-400); padding-top: .1rem;
}
.cnv__res-v { display: flex; flex-direction: column; gap: .2rem; font-size: .875rem; color: var(--c-slate-900); }
.cnv__res-sub { font-size: .75rem; color: var(--c-slate-500); line-height: 1.45; }
.cnv__feat-left { display: flex; align-items: center; gap: .5rem; flex: 1; min-width: 0; }
.cnv__feat-name { font-size: .78rem; font-weight: 700; color: var(--c-slate-900); }
.cnv__feat-desc { font-size: .68rem; color: var(--c-slate-400); }

/* Roles */
.cnv__roles-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: .6rem; }
.cnv__role-card {
  padding: .875rem 1rem; border-radius: 10px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  cursor: pointer; transition: all .15s; user-select: none;
}
.cnv__role-card--on { border-color: #1b5e20; background: #f0fdf4; }
.cnv__role-card--required { cursor: default; }
.cnv__role-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .3rem; }
.cnv__role-check {
  width: 18px; height: 18px; border-radius: 5px; border: 1.5px solid var(--c-slate-200);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
  background: #fff; transition: all .15s;
}
.cnv__role-card--on .cnv__role-check { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.cnv__role-label { font-size: .82rem; font-weight: 800; color: var(--c-slate-900); flex: 1; }
.cnv__role-req   { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: var(--c-slate-100); color: var(--c-slate-400); padding: .15em .5em; border-radius: 5px; }
.cnv__role-desc  { font-size: .72rem; color: var(--c-slate-500); margin-bottom: .35rem; }
.cnv__role-email { font-size: .68rem; color: var(--c-slate-400); font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* Navigation bar */
.cnv__nav {
  display: flex; align-items: center; gap: .75rem;
  padding-top: .25rem;
}
.cnv__nav-spacer { flex: 1; }
.cnv__btn-primary {
  display: inline-flex; align-items: center; gap: .45rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .75rem 1.4rem; border-radius: 10px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s; white-space: nowrap;
}
.cnv__btn-primary:hover:not(:disabled) { background: #166534; }
.cnv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.cnv__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: var(--c-slate-500);
  border: 1.5px solid var(--c-slate-200); padding: .75rem 1.25rem;
  border-radius: 10px; font-size: .875rem; font-weight: 600;
  cursor: pointer; text-decoration: none; transition: all .15s;
}
.cnv__btn-ghost:hover { background: var(--c-slate-50); color: var(--c-slate-900); }

/* Success */
.cnv__success {
  background: #fff; border: 1px solid #bbf7d0; border-radius: 16px;
  padding: 3rem 2rem; text-align: center; max-width: 600px; margin: 0 auto;
}
.cnv__success-check {
  width: 56px; height: 56px; border-radius: 50%;
  background: #dcfce7; color: #15803d;
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 1rem;
}
.cnv__success-title { font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .5rem; }
.cnv__success-sub { font-size: .875rem; color: var(--c-slate-500); margin: 0 0 1.5rem; }
.cnv__usuarios-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(140px,1fr));
  gap: .6rem; margin-bottom: 2rem; text-align: left;
}
.cnv__usuario-card {
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200);
  border-radius: 10px; padding: .7rem .875rem;
}
.cnv__usuario-role  { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; color: #1b5e20; margin-bottom: .2rem; }
.cnv__usuario-email { font-size: .72rem; color: var(--c-slate-500); font-family: monospace; word-break: break-all; }
.cnv__success-actions { display: flex; justify-content: center; gap: .75rem; flex-wrap: wrap; }
</style>
