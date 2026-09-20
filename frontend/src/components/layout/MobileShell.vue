<template>
  <div class="msh" :class="`msh--${role}`">

    <!-- Top bar -->
    <header class="msh__top">
      <div class="msh__brand">
        <button v-if="isDetalle" class="msh__icon-btn" @click="router.back()" aria-label="Volver">
          <i class="bi bi-chevron-left"></i>
        </button>
        <template v-else>
          <img v-if="club.data?.logo_url" :src="club.data.logo_url" class="msh__logo" alt="" />
          <span v-else class="msh__logo-text">{{ clubInitials }}</span>
          <div class="msh__brand-txt">
            <span class="msh__club-name">{{ club.data?.name || 'Cultivo' }}</span>
            <span class="msh__role">{{ roleLabel }}</span>
          </div>
        </template>
      </div>
      <button class="msh__icon-btn" aria-label="Cuenta" @click="menuOpen = !menuOpen">
        <i class="bi bi-person-circle"></i>
      </button>

      <!-- El ícono suelto de salir no se encontraba: ahora hay un menú con el nombre del usuario y
           la acción escrita. -->
      <Transition name="msh-menu">
        <div v-if="menuOpen" class="msh__menu" @click.self="menuOpen = false">
          <div class="msh__menu-card">
            <div class="msh__menu-user">
              <strong>{{ auth.displayName || auth.user?.email }}</strong>
              <span>{{ roleLabel }}</span>
            </div>
            <button class="msh__menu-item" @click="irPerfil">
              <i class="bi bi-person"></i> Mi perfil
            </button>
            <!-- El mismo interruptor que el escritorio. Sin esto el teléfono sólo tenía el pedido
                 automático de los 4 segundos: si el alta fallaba no había cómo reintentar ni
                 forma de enterarse de por qué (19-sep-2026). -->
            <button v-if="pushDisponible || iosSinInstalar" class="msh__menu-item" :class="{ 'msh__menu-item--blocked': pushDenied }" :disabled="pushLoading" @click="togglePush">
              <i class="bi" :class="pushSubscribed ? 'bi-bell-fill' : 'bi-bell-slash'"></i>
              {{ pushDenied ? 'Notificaciones bloqueadas' : (pushSubscribed ? 'Notificaciones activas' : 'Activar notificaciones') }}
            </button>
            <button class="msh__menu-item msh__menu-item--danger" @click="doLogout">
              <i class="bi bi-box-arrow-right"></i> Cerrar sesión
            </button>

            <!-- QUÉ VERSIÓN ESTÁ CORRIENDO ESTE TELÉFONO. El dato ya existía pero sólo se veía en
                 el login, y en la PWA instalada la sesión dura meses: nadie vuelve a pasar por
                 ahí. Sin esto, un "esto no anda" puede ser un bug o una versión de hace una
                 semana servida por el service worker, y se pierde el viaje averiguándolo. -->
            <div class="msh__menu-ver" :title="`Build ${BUILD} · ${BUILD_AT}`">
              Versión {{ BUILD }} · {{ BUILD_AT }}
            </div>
          </div>
        </div>
      </Transition>
    </header>

    <!-- Contenido -->
    <main class="msh__main">
      <RouterView v-slot="{ Component }">
        <Transition name="msh-page" mode="out-in">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>

    <!-- Bottom nav -->
    <nav class="msh__nav" :class="{ 'msh__nav--fab': showFab }">
      <template v-if="showFab">
        <RouterLink
          v-for="item in navLeft" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span v-if="conPunto(item)" class="msh__tab-punto" aria-hidden="true"></span>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>

        <button class="msh__fab" @click="fabOpen = true" aria-label="Acciones rápidas">
          <i class="bi bi-plus-lg"></i>
        </button>

        <RouterLink
          v-for="item in navRight" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span v-if="conPunto(item)" class="msh__tab-punto" aria-hidden="true"></span>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>
      </template>

      <template v-else>
        <RouterLink
          v-for="item in navVisibles" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span v-if="conPunto(item)" class="msh__tab-punto" aria-hidden="true"></span>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>
      </template>

      <!-- Lo que no entra en la barra. No se pierde: se llega en dos toques. -->
      <button v-if="navOverflow.length" class="msh__tab" :class="{ 'msh__tab--active': masActivo }"
              @click="masOpen = true">
        <i class="bi msh__tab-icon bi-three-dots"></i>
        <span class="msh__tab-label">Más</span>
      </button>
    </nav>

    <MobileSheet v-model="masOpen" title="Más secciones">
      <div class="msh__mas">
        <button v-for="item in navOverflow" :key="item.to" class="msh__mas-item" @click="irA(item)">
          <i class="bi" :class="item.icon"></i>
          <span>{{ item.label }}</span>
          <i class="bi bi-chevron-right msh__mas-arr"></i>
        </button>
      </div>
    </MobileSheet>

    <!-- FAB → hoja de acciones rápidas. En uso personal se llama «Hoy»: lo primero que ofrece
         es lo que se hace todos los días (regar, ambiente, foto), no crear cosas. -->
    <MobileSheet v-model="fabOpen" :title="ofreceHoy ? 'Hoy' : 'Crear'">
      <MobileActionGrid :actions="fabActions" />
    </MobileSheet>

    <!-- Con más de un lote (o espacio) hay que decir cuál. Con uno solo, este paso no existe. -->
    <MobileSheet v-model="eleccionOpen" :title="eleccion?.titulo || '¿Dónde?'">
      <div class="msh__mas">
        <button v-for="op in eleccion?.opciones || []" :key="op.id" class="msh__mas-item" @click="elegir(op)">
          <i class="bi" :class="op.icon"></i>
          <span>{{ op.label }}<small v-if="op.sub" class="msh__mas-sub">{{ op.sub }}</small></span>
          <i class="bi bi-chevron-right msh__mas-arr"></i>
        </button>
      </div>
    </MobileSheet>
    <!-- La cámara se abre desde el toque (el navegador no deja abrirla «sola» después de navegar),
         así que la foto se sube desde acá y recién después se va al lote. -->
    <input ref="inputFoto" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFotoRapida" />

    <!-- Modales de creación reutilizados del desktop -->
    <NuevoLoteModal :show="showNuevoLote" :salas="salas" @close="showNuevoLote = false" @created="onCreado" />
    <ModalCrearSala v-if="showNuevaSala" @close="showNuevaSala = false" @created="onCreado" />
    <ModalTarea v-if="esPersonal" :show="showNuevaTarea" :tarea-inicial="tareaInicial" :salas="salas" :lotes="lotesActivos"
                @guardada="onTareaCreada" @cerrar="showNuevaTarea = false" />
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, provide, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useClubStore }  from '../../stores/club'
import { useCajaDeliveryStore } from '../../stores/cajaDelivery.js'
import { usePushNotifications, MOTIVOS } from '../../composables/usePushNotifications.js'
import { useToast } from '../../composables/useToast.js'
import { listSalas, uploadFotoLote } from '../../lib/api.js'
import { useLotesStore } from '../../stores/lotes.js'
import { useTareasStore } from '../../stores/tareas.js'
import { hoyISO } from '../../utils/dates.js'
import { achicarImagen } from '../../lib/imagenes.js'
import MobileSheet from '../mobile/MobileSheet.vue'
import MobileActionGrid from '../mobile/MobileActionGrid.vue'
import NuevoLoteModal from '../lotes/NuevoLoteModal.vue'
import ModalCrearSala from '../salas/ModalCrearSala.vue'
import ModalTarea from '../ModalTarea.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()
const toast  = useToast()

const role = computed(() => auth.user?.role || '')
const esPersonal = computed(() => club.data?.personal === true)
// Quién tiene «lo de todos los días» en el «+»: el cultivador de casa y el cultivador de una
// organización. Los dos riegan; el admin de una organización no está en el pasillo.
const ofreceHoy  = computed(() => esPersonal.value || role.value === 'cultivador')

// Qué build está corriendo en ESTE dispositivo. Lo inyecta vite.config desde el commit.
const BUILD    = __APP_BUILD__
const BUILD_AT = __APP_BUILD_AT__

const ROLE_LABELS = {
  admin: 'Administración', supervisor: 'Supervisión', cultivador: 'Cultivo',
  manicura: 'Manicura', delivery: 'Delivery', dispensador: 'Dispensa',
}
const roleLabel = computed(() => (club.data?.personal && role.value === 'admin' ? 'Mi cultivo' : ROLE_LABELS[role.value] || ''))

const isDetalle = computed(() =>
  /\/m\/(sede|sala-m|lote-m|planta|mnc\/lotes)\//.test(route.path)
)

const clubInitials = computed(() => {
  const n = club.data?.name || 'CE'
  return n.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
})

// UN PUNTO EN LA SOLAPA CUANDO LLEVA PLATA ENCIMA.
//
// Es lo único que le queda recordándole que tiene que rendir: la tarjeta de la caja salió del
// inicio a propósito —esa pantalla es a dónde va ahora— pero si nada se lo dice, se va a su casa
// con la recaudación. Un punto, no un número: acá no se cuenta plata, se avisa que hay.
const cajaDelivery = useCajaDeliveryStore()
const conPunto = (item) => item.punto === 'caja_delivery' && cajaDelivery.llevaEfectivo

// ── Navegación por rol ──────────────────────────────────────────
const NAV = {
  // El cultivador es el que MÁS escanea —es lo primero que hace al entrar a una sala—, pero el
  // botón vivía solo en el FAB de admin y en el detalle de un lote: no tenía cómo llegar.
  cultivador: { fab: true, items: [
    { to: '/m/cultivador/sedes',  icon: 'bi-diagram-3',     label: 'Cultivo', feature: 'cultivo' },
    { to: '/m/scan',              icon: 'bi-qr-code-scan',  label: 'Escanear' },
    { to: '/m/cultivador/tareas', icon: 'bi-check2-square', label: 'Tareas' },
    // A la planta suelta se llega escaneando su QR o desde su lote, que es como se trabaja en la
    // sala; una lista de todas las plantas en el teléfono no se usa. Genéticas es material de
    // consulta de escritorio. Queda "Mis horas", que sí se marca de pie.
    { to: '/m/horas',             icon: 'bi-clock-history', label: 'Mis horas' },
  ] },
  // El admin en el celular NO administra: mira cómo va el día y desbloquea lo que traba a otros.
  // Lo de escritorio —contabilidad, informes, configuración— no se bloquea (si lo necesita abre
  // Chrome y tiene la app entera), simplemente no ocupa la barra.
  // `feature`: de qué suite depende cada destino. Sin esto, una organización de sólo cultivo veía
  // Dispensas y Pacientes en la barra, entraba, y el backend le devolvía 403: un menú que
  // no lleva a ningún lado.
  admin: { fab: true, items: [
    { to: '/m/admin/home',    icon: 'bi-grid-1x2',      label: 'Inicio'  },
    { to: '/m/admin/sedes',   icon: 'bi-diagram-3',     label: 'Cultivo',   feature: 'cultivo' },
    { to: '/m/admin/aprobar', icon: 'bi-patch-check',   label: 'Aprobar',   feature: 'cultivo' },
    { to: '/m/admin/tareas',  icon: 'bi-check2-square', label: 'Tareas'  },
    { to: '/m/historial',     icon: 'bi-clock-history', label: 'Dispensas', feature: 'produccion_dispensa' },
    { to: '/m/pacientes',     icon: 'bi-people',        label: 'Pacientes', feature: 'produccion_dispensa' },
    // Sin "Plantas": el mismo criterio que en el cultivador, que es quien las trabaja —a una
    // planta se llega escaneando su QR o desde su lote, no de una lista de todas. Para el admin
    // en el celular tiene todavía menos sentido: no registra plantas, mira cómo va el día.
  ] },
  manicura: { items: [
    { to: '/m/manicura/pesar',      icon: 'bi-scissors',        label: 'Por pesar',  feature: 'cultivo' },
    { to: '/m/manicura/pesajes',    icon: 'bi-journal-check',   label: 'Pesajes',    feature: 'cultivo' },
    { to: '/m/manicura/aprobacion', icon: 'bi-hourglass-split', label: 'Aprobación', feature: 'cultivo' },
    { to: '/m/horas',               icon: 'bi-clock-history',   label: 'Horas'      },
    { to: '/m/manicura/tareas',     icon: 'bi-check2-square',   label: 'Tareas'     },
  ] },
  delivery: { items: [
    { to: '/m/delivery/despachos', icon: 'bi-truck',         label: 'Despachos' },
    // La plata tiene su propia solapa: el inicio es a dónde va ahora, y la caja se mira dos o
    // tres veces por día. Antes era una tarjeta arriba de todo en la pantalla que más abre.
    { to: '/m/delivery/caja',      icon: 'bi-cash-coin',     label: 'Caja', punto: 'caja_delivery' },
    { to: '/m/delivery/historial', icon: 'bi-clock-history', label: 'Historial' },
  ] },
  // El dispensador trabaja de pie con alguien enfrente: la primera pantalla es buscar y dispensar,
  // no un dashboard. El Salón aparece solo si la organización tiene el módulo activo — es el mismo puesto
  // físico, así que no tiene sentido mandarlo al escritorio para cobrar un café.
  // NO hay tab "Pacientes": la lista completa ya está en Dispensar, con buscador y escaneo del
  // carnet. Tenerla dos veces obligaba a decidir por cuál entrar para hacer lo mismo.
  dispensador: { items: [
    { to: '/m/dispensar', icon: 'bi-bag-plus',       label: 'Dispensar', feature: 'produccion_dispensa' },
    // La MESA: recibirla, reponer, contar y cerrar. Es la mitad de su día y sólo estaba en el
    // escritorio, así que atendiendo con el celular no podía ni arrancar el turno.
    { to: '/m/mostrador', icon: 'bi-shop',           label: 'Mostrador', feature: 'produccion_dispensa' },
    { to: '/m/reservas',  icon: 'bi-bookmark-check', label: 'Reservas',  feature: 'produccion_dispensa' },
    // HISTORIAL antes que STOCK: lo que consulta a diario es qué le entregó a alguien, no el
    // inventario. Y desde que el depósito no es asunto suyo, su pantalla de Stock muestra lo que
    // está sobre la mesa — que ya tiene, entera y con buscador, en Mostrador. Sigue accesible
    // desde "Más": correrla un toque no es esconderla.
    { to: '/m/historial', icon: 'bi-clock-history',  label: 'Historial', feature: 'produccion_dispensa' },
    { to: '/m/stock',     icon: 'bi-boxes',          label: 'Stock' },
    { to: '/m/tareas',    icon: 'bi-check2-square',  label: 'Tareas' },
    { to: '/m/horas',     icon: 'bi-stopwatch',      label: 'Mis horas' },
  ] },
}
NAV.supervisor = NAV.admin

// USO PERSONAL: el admin ES el cultivador, y su barra es la de quien hace todo — hoy, el
// cultivo, los frascos y los gastos. Es otra PRESENTACIÓN del mismo estado (mismos stores,
// mismas pantallas de sala/lote/planta): lo que no tiene es lo de una organización, porque no
// hay equipo que aprobar ni pacientes que atender. Cuatro destinos y el FAB: sin «Más».
NAV.personal = { fab: true, items: [
  { to: '/m/personal/hoy',     icon: 'bi-sun',           label: 'Hoy' },
  // Entra directo a sus salas (una sola sede, la casa); se resalta también dentro de una sala,
  // un lote o una planta, que es donde vive el recorrido.
  { to: '/m/personal/cultivo', icon: 'bi-diagram-3',     label: 'Cultivo', match: ['/m/sede/', '/m/sala-m/', '/m/lote-m/', '/m/planta/', '/m/mnc/'] },
  { to: '/m/personal/stock',   icon: 'bi-archive',       label: 'Stock' },
  { to: '/m/personal/gastos',  icon: 'bi-receipt',       label: 'Gastos' },
] }

// Qué barra corresponde: el rol, salvo en uso personal, donde el admin lleva la suya.
const navKey = computed(() => (role.value === 'admin' && club.data?.personal ? 'personal' : role.value))

// Un destino se ofrece sólo si la organización tiene lo que ese destino necesita. Misma regla que el
// menú de escritorio (useNavContext), para que las dos superficies no se desincronicen.
function tieneFeature(item) {
  return !item.feature || club.data?.features?.[item.feature] === true
}

const navItems = computed(() => {
  const base = (NAV[navKey.value]?.items || []).filter(tieneFeature)
  if (role.value === 'dispensador' && club.data?.features?.bar) {
    return [...base, { to: '/bar', icon: 'bi-cup-hot', label: 'Buffet' }]
  }
  return base
})

// La barra inferior aguanta 4 destinos legibles; con más, las etiquetas se cortan y se pierde el
// pulgar. Los primeros van a la barra y el resto a un sheet "Más" — accesible, fuera del camino.
// Es el mismo mecanismo para todos los roles: no hay una lista aparte que se desincronice.
const MAX_TABS = 4
const navVisibles = computed(() => {
  const items = navItems.value
  const tope  = showFab.value ? MAX_TABS : MAX_TABS + 1
  return items.length > tope ? items.slice(0, tope - 1) : items
})
const navOverflow = computed(() => {
  const items = navItems.value
  const tope  = showFab.value ? MAX_TABS : MAX_TABS + 1
  return items.length > tope ? items.slice(tope - 1) : []
})
const masOpen = ref(false)
const masActivo = computed(() => navOverflow.value.some(i => isActive(i)))
function irA(item) { masOpen.value = false; router.push(item.to) }
const showFab  = computed(() => !!NAV[navKey.value]?.fab)
// Con FAB, repartimos las tabs a cada lado del botón central.
const navLeft  = computed(() => navVisibles.value.slice(0, 2))
const navRight = computed(() => navVisibles.value.slice(2))

watch(() => route.path, () => { menuOpen.value = false })

function isActive(item) {
  if (route.path === item.to || route.path.startsWith(item.to + '/')) return true
  return (item.match || []).some(p => route.path.startsWith(p))
}

// ── FAB: acciones de creación ───────────────────────────────────
const menuOpen = ref(false)
function irPerfil() { menuOpen.value = false; router.push('/m/perfil') }

const fabOpen      = ref(false)
const showNuevoLote = ref(false)
const showNuevaSala = ref(false)
const salas        = ref([])

// Crear una SALA es decisión de infraestructura, no del que está en el pasillo: el cultivador crea
// lotes, no cuartos.
// "Registrar" se leía como "anotar algo de un lote que ya existe", cuando en realidad ABRE EL ALTA.
// Y escanear no va acá para el cultivador: ya tiene su propia tab, repetirlo en el botón de crear
// mezcla dos cosas distintas (crear vs. buscar).
const fabActions = computed(() => {
  const esCultivador = role.value === 'cultivador'
  const acciones = [
    { key: 'lote', label: 'Crear lote', icon: 'bi-box-seam',
      tint: 'var(--c-leaf-100)', color: 'var(--c-leaf-700)', onClick: abrirNuevoLote },
  ]
  // Primero lo de todos los días. Anotar un riego eran cuatro toques (Cultivo → espacio →
  // lote → Registrar → Riego); ahora son dos, y con un solo lote no pregunta cuál. Para el
  // cultivador de una organización igual (20-sep): el backend ya le devuelve sólo los lotes y
  // salas suyas. «Tarea» sólo en personal: en una organización las crea administración.
  if (ofreceHoy.value) {
    acciones.unshift(
      { key: 'riego',    label: 'Regar',              icon: 'bi-droplet-fill',     tint: '#dbeafe', color: '#1d4ed8', onClick: () => conLote('riego') },
      { key: 'ambiente', label: 'Registrar ambiente', icon: 'bi-thermometer-half', tint: '#fef3c7', color: '#b45309', onClick: () => conSala('ambiental') },
      { key: 'foto',     label: 'Foto',               icon: 'bi-camera-fill',      tint: '#fce7f3', color: '#be185d', onClick: () => conLote('foto') },
    )
    if (esPersonal.value) {
      acciones.splice(3, 0, { key: 'tarea', label: 'Tarea', icon: 'bi-check2-square', tint: '#ede9fe', color: '#7c3aed', onClick: abrirNuevaTarea })
    }
  }
  // Crear una SALA es decisión de infraestructura, no del que está en el pasillo.
  if (!esCultivador) {
    acciones.push({ key: 'sala', label: club.data?.personal ? 'Crear espacio' : 'Crear sala', icon: 'bi-grid-3x3-gap',
                    tint: 'var(--c-sky-100)', color: 'var(--c-sky-600)', onClick: abrirNuevaSala })
    acciones.push({ key: 'scan', label: 'Escanear QR', icon: 'bi-qr-code-scan',
                    tint: '#ede9fe', color: '#7c3aed', onClick: irEscanear })
  }
  return acciones
})

function irEscanear() {
  fabOpen.value = false
  router.push('/m/scan')
}

// ── Acciones del día (uso personal) ─────────────────────────────
// Los lotes y espacios se traen al abrir el «+», no al tocar la acción: la cámara sólo se abre
// dentro del toque, y un `await` en el medio lo pierde.
const lotesStore  = useLotesStore()
const tareasStore = useTareasStore()
const EN_PIE = ['enraizado', 'vegetativo', 'floracion']
const lotesActivos = computed(() => (lotesStore.items || []).filter(l => l.estado !== 'finalizado'))
const lotesEnPie   = computed(() => lotesActivos.value.filter(l => EN_PIE.includes(l.estado)))
watch(fabOpen, async (abierto) => {
  if (!abierto || !ofreceHoy.value) return
  const pedidos = []
  if (!lotesStore.items?.length) pedidos.push(lotesStore.fetch({ silencioso: true }))
  if (!salas.value.length) pedidos.push(listSalas().then(({ data }) => { salas.value = data || [] }).catch(() => {}))
  await Promise.allSettled(pedidos)
})

const eleccionOpen = ref(false)
const eleccion     = ref(null)   // { titulo, opciones: [{ id, label, sub, icon, ir }] }
const inputFoto    = ref(null)
const fotoLoteId   = ref(null)

// En casa se conoce el lote por su genética («la Ananda»); en una organización, por el código.
function nombreLote(l) { return esPersonal.value ? (l.genetica?.nombre || l.strain || l.codigo) : l.codigo }
function subLote(l) {
  const plantas = `${l.plants_count || 0} plantas`
  return esPersonal.value ? `${l.codigo} · ${plantas}` : [l.genetica?.nombre || l.strain, l.sala?.nombre, plantas].filter(Boolean).join(' · ')
}

// Regar y foto son de UN lote: si hay uno solo en pie se va derecho; si hay varios se pregunta.
function conLote(accion) {
  fabOpen.value = false
  const candidatos = accion === 'foto' ? lotesActivos.value : lotesEnPie.value
  if (!candidatos.length) {
    toast.info(accion === 'foto' ? 'No hay ningún lote al que sacarle una foto.' : 'No hay ningún lote en pie para regar.')
    return
  }
  const ir = (l) => {
    if (accion === 'foto') { fotoLoteId.value = l.id; inputFoto.value?.click(); return }
    router.push({ path: `/m/lote-m/${l.id}`, query: { accion } })
  }
  if (candidatos.length === 1) return ir(candidatos[0])
  eleccion.value = {
    titulo: accion === 'foto' ? '¿Foto de qué lote?' : '¿Qué lote regaste?',
    opciones: candidatos.map(l => ({ id: l.id, label: nombreLote(l), sub: subLote(l), icon: 'bi-box-seam', ir: () => ir(l) })),
  }
  eleccionOpen.value = true
}

// El ambiente es del ESPACIO (la carpa tiene un clima, no cada lote): va a la sala y su
// registro se aplica a todos los lotes que tiene adentro.
function conSala(accion) {
  fabOpen.value = false
  const candidatas = salas.value.filter(s => s.activa !== false)
  if (!candidatas.length) { toast.info(esPersonal.value ? 'Primero creá un espacio de cultivo.' : 'No tenés ninguna sala asignada.'); return }
  const ir = (s) => router.push({ path: `/m/sala-m/${s.id}`, query: { accion } })
  if (candidatas.length === 1) return ir(candidatas[0])
  eleccion.value = {
    titulo: esPersonal.value ? '¿De qué espacio?' : '¿De qué sala?',
    opciones: candidatas.map(s => ({ id: s.id, label: s.nombre, sub: null, icon: 'bi-grid-3x3-gap', ir: () => ir(s) })),
  }
  eleccionOpen.value = true
}
function elegir(op) { eleccionOpen.value = false; op.ir() }

// La foto rápida no pide fecha ni etiqueta: es de hoy y del lote elegido. Los detalles se
// editan después desde la galería, que es donde se ven.
async function subirFotoRapida(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  const loteId = fotoLoteId.value
  if (!file || !loteId) return
  const fd = new FormData()
  fd.append('imagen', await achicarImagen(file))
  fd.append('tomada_el', hoyISO())
  try {
    await uploadFotoLote(loteId, fd)
    toast.success('Foto guardada')
    router.push(`/m/lote-m/${loteId}`)
  } catch (err) {
    // El 402 del tope de fotos trae `mensaje` (qué plan, cuál es el tope, qué hacer).
    toast.error(err?.response?.data?.mensaje || err?.response?.data?.errors?.[0] || err?.response?.data?.error || 'No se pudo guardar la foto')
  }
}

// Una tarea nueva. Con un solo lote en pie nace ya apuntada a él y a su espacio.
const showNuevaTarea = ref(false)
const tareaInicial   = ref(null)
function abrirNuevaTarea() {
  fabOpen.value = false
  const unico = lotesEnPie.value.length === 1 ? lotesEnPie.value[0] : null
  tareaInicial.value = unico ? { lote_id: unico.id, sala_id: unico.sala_id || unico.sala?.id || '' } : null
  showNuevaTarea.value = true
}
function onTareaCreada() {
  showNuevaTarea.value = false
  toast.success('Tarea creada')
  tareasStore.fetchDashboard?.().catch?.(() => {})
}

async function abrirNuevoLote() {
  fabOpen.value = false
  try { const { data } = await listSalas(); salas.value = data || [] } catch { salas.value = [] }
  showNuevoLote.value = true
}
function abrirNuevaSala() {
  fabOpen.value = false
  showNuevaSala.value = true
}
// Lo que el shell sabe abrir, para quien viva adentro: la puesta en marcha del inicio abre el
// modal de espacio o de lote en vez de mandar a `/salas`, que en el teléfono no existe (el
// guard rebotaba al inicio y el paso parecía no hacer nada).
provide('accionesMobile', { abrirNuevaSala, abrirNuevoLote })

function onCreado() {
  showNuevoLote.value = false
  showNuevaSala.value = false
  toast.success('Creado ✓')
}

async function doLogout() {
  await auth.logOut?.()
  router.replace('/login')
}

// Una sola consulta, al entrar, y sólo para el repartidor: es lo que enciende el punto de la
// solapa Caja. Se refresca sola cuando él rinde o cuando abre la pantalla.
onMounted(() => { if (auth.user?.role === 'delivery') cajaDelivery.cargar() })

// ── Push (sin cambios de comportamiento) ────────────────────────
// Ya no se pide permiso solo a los 4 segundos: pedirlo sin contexto —y, en iPhone, fuera de
// un toque— fallaba en silencio y quemaba la única oportunidad de preguntar. Se activa desde
// el menú, con un toque y con un toast que dice qué pasó.
const { disponible: pushDisponible, iosSinInstalar, subscribed: pushSubscribed, loading: pushLoading, denied: pushDenied,
        subscribe: pushSubscribe, unsubscribe: pushUnsubscribe } = usePushNotifications()

// Igual que en `AdminTopBar`: nunca mudo. Si no se pudo, el toast dice por qué.
async function togglePush() {
  if (pushDenied.value) { toast.error(MOTIVOS.denegado, { timeout: 9000 }); menuOpen.value = false; return }
  if (pushSubscribed.value) {
    const r = await pushUnsubscribe()
    r === true ? toast.info('Notificaciones desactivadas en este dispositivo') : toast.error(MOTIVOS[r] || MOTIVOS.error)
  } else {
    const r = await pushSubscribe()
    r === true ? toast.success('Notificaciones activadas en este dispositivo') : toast.error(MOTIVOS[r] || MOTIVOS.error)
  }
  menuOpen.value = false
}
// La píldora «Sin conexión» (`OfflineIndicator`, hermana de este shell en `App.vue`) vive
// pegada al borde de abajo y acá abajo está la barra de solapas: se la sube mientras el shell
// esté montado. Va en `:root` porque no es descendiente.
onMounted(() => document.documentElement.style.setProperty('--oi-bottom', 'calc(72px + env(safe-area-inset-bottom))'))
onUnmounted(() => document.documentElement.style.removeProperty('--oi-bottom'))

// ── Precalentar las pantallas del rol ─────────────────────────────────
// El service worker ya no baja la app entera al instalar (ver `vite.config.js`): guarda lo que
// se usa. Para que lo offline de manicura y delivery siga andando sin haber pasado antes por
// cada pantalla, apenas entra —y con el teléfono desocupado— se piden los chunks de su menú.
// Es un `import()` que el navegador resuelve y el service worker cachea; si falla, no pasa nada.
onMounted(() => {
  const precalentar = () => {
    navItems.value.forEach(item => {
      try {
        router.resolve(item.to).matched.forEach(r => {
          Object.values(r.components || {}).forEach(c => { if (typeof c === 'function') c().catch(() => {}) })
        })
      } catch {}
    })
  }
  if ('requestIdleCallback' in window) requestIdleCallback(precalentar, { timeout: 8000 })
  else setTimeout(precalentar, 3000)
})
</script>

<style scoped>
/* Acento por rol */
.msh--cultivador  { --msh-accent: #16a34a; --msh-top-bg: #0F2A1E; }
.msh--admin       { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }
.msh--supervisor  { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }
.msh--manicura    { --msh-accent: #8b5cf6; --msh-top-bg: #1c1028; }
.msh--delivery    { --msh-accent: #ea580c; --msh-top-bg: #1c0a00; }
/* El dispensador es VERDE, como en el escritorio: su sidebar usa `--c-role-dispensador`
   (#1A3D2E, la misma base leaf que admin) y su tablero el mismo token. Acá era celeste, así que
   el mismo rol tenía dos identidades según el dispositivo — y el teléfono es donde más trabaja. */
.msh--dispensador { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }

/* Discreto: es un dato de diagnóstico, no algo que la persona necesite todos los días. */
.msh__menu-ver {
  padding: 10px 14px 2px; font-size: 11px; color: var(--c-ink-500, #6b7280);
  font-family: var(--font-mono, monospace); text-align: center;
}
/* Red de seguridad: un rol sin acento propio dejaba el header SIN FONDO, y el botón de cerrar
   sesión —blanco— quedaba invisible sobre claro. Le pasó al dispensador al sumarlo al shell. */
.msh { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }

.msh {
  display: flex; flex-direction: column;
  min-height: 100dvh;
  background: var(--c-paper, #f4f8f5);
  font-family: var(--font-ui, system-ui, sans-serif);
}

/* ── Top bar ── */
.msh__top {
  position: sticky; top: 0; z-index: 50;
  background: var(--msh-top-bg);
  display: flex; align-items: center; justify-content: space-between;
  gap: .5rem;
  padding: .65rem .9rem;
  padding-top: calc(.65rem + env(safe-area-inset-top));
  box-shadow: 0 1px 0 rgba(255,255,255,.04), 0 6px 20px rgba(15,42,30,.18);
}
.msh__brand { display: flex; align-items: center; gap: .6rem; min-width: 0; }
.msh__logo { width: 36px; height: 36px; border-radius: 10px; object-fit: cover; flex-shrink: 0; }
.msh__logo-text {
  width: 36px; height: 36px; border-radius: 10px;
  background: var(--msh-accent); color: #fff;
  font-size: .85rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.msh__brand-txt { display: flex; flex-direction: column; min-width: 0; line-height: 1.15; }
.msh__club-name {
  font-family: var(--font-display, sans-serif);
  font-size: .95rem; font-weight: 700; color: #fff;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.msh__role { font-size: .66rem; font-weight: 600; color: rgba(255,255,255,.55); letter-spacing: .03em; }
.msh__mas { display: flex; flex-direction: column; }
.msh__mas-item {
  display: flex; align-items: center; gap: .7rem; width: 100%;
  background: none; border: none; border-bottom: 1px solid var(--c-slate-100);
  padding: .85rem .25rem; cursor: pointer; font: inherit; font-size: .9rem;
  color: var(--c-slate-700); text-align: left;
}
.msh__mas-item:last-child { border-bottom: none; }
.msh__mas-item > span { flex: 1; }
.msh__mas-arr { color: var(--c-slate-300); }

.msh__menu {
  position: fixed; inset: 0; z-index: 60; background: rgba(15,23,42,.35);
  display: flex; justify-content: flex-end; align-items: flex-start;
  padding: calc(3.4rem + env(safe-area-inset-top)) .75rem 0;
}
.msh__menu-card {
  background: #fff; border-radius: 14px; min-width: 210px; overflow: hidden;
  box-shadow: 0 12px 32px rgba(15,23,42,.24);
}
.msh__menu-user {
  display: flex; flex-direction: column; gap: .1rem;
  padding: .75rem .9rem; border-bottom: 1px solid var(--c-slate-100);
}
.msh__menu-user strong { font-size: .88rem; color: #1e293b; }
.msh__menu-user span   { font-size: .72rem; color: var(--c-slate-400); }
.msh__menu-item {
  display: flex; align-items: center; gap: .55rem; width: 100%;
  background: none; border: none; padding: .7rem .9rem; cursor: pointer;
  font: inherit; font-size: .85rem; color: var(--c-slate-600); text-align: left;
}
.msh__menu-item:active { background: var(--c-slate-50); }
.msh__menu-item--danger { color: #dc2626; border-top: 1px solid var(--c-slate-100); }
.msh__menu-item--blocked { color: #b91c1c; }
.msh-menu-enter-active, .msh-menu-leave-active { transition: opacity .15s; }
.msh-menu-enter-from, .msh-menu-leave-to { opacity: 0; }

.msh__icon-btn {
  flex-shrink: 0;
  width: 38px; height: 38px; border-radius: 11px;
  background: rgba(255,255,255,.1); border: none; color: rgba(255,255,255,.85);
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition: background .15s, color .15s;
}
.msh__icon-btn:hover { background: rgba(255,255,255,.2); color: #fff; }
.msh__icon-btn:active { transform: scale(.94); }

/* ── Main ── */
.msh__main {
  flex: 1;
  overflow-y: auto;
  padding-bottom: calc(72px + env(safe-area-inset-bottom));
}

/* Transición de página */
.msh-page-enter-active, .msh-page-leave-active { transition: opacity .18s ease, transform .18s ease; }
.msh-page-enter-from { opacity: 0; transform: translateY(6px); }
.msh-page-leave-to   { opacity: 0; transform: translateY(-4px); }

/* ── Bottom nav ── */
.msh__nav {
  position: fixed; bottom: 0; left: 0; right: 0; z-index: 50;
  background: rgba(255,255,255,.92);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-top: 1px solid var(--c-leaf-100, #e8eae8);
  display: flex; align-items: stretch;
  padding-bottom: env(safe-area-inset-bottom);
  box-shadow: 0 -2px 16px rgba(15,42,30,.08);
}
.msh__tab {
  flex: 1;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .15rem; padding: .5rem .25rem .45rem;
  text-decoration: none; color: #9aa39c;
  transition: color .15s; position: relative;
  -webkit-tap-highlight-color: transparent;
}
.msh__tab-icon { font-size: 1.28rem; line-height: 1; }
.msh__tab-punto {
  position: absolute; top: 6px; left: 50%; margin-left: 6px;
  width: 7px; height: 7px; border-radius: 50%; background: var(--msh-accent, #ea580c);
}
.msh__tab-label { font-size: .62rem; font-weight: 600; letter-spacing: .01em; }
.msh__tab--active { color: var(--msh-accent); }
.msh__tab--active::before {
  content: ''; position: absolute; top: 0; left: 28%; right: 28%;
  height: 3px; background: var(--msh-accent); border-radius: 0 0 4px 4px;
}

/* ── FAB central ── */
.msh__mas-sub { display: block; font-size: .72rem; font-weight: 400; color: var(--c-ink-500, #6b7280); }

.msh__fab {
  flex-shrink: 0;
  width: 60px; height: 60px;
  margin: -22px .55rem 0;
  align-self: flex-start;
  border-radius: 50%; border: 4px solid var(--c-paper, #f4f8f5);
  background: var(--msh-accent); color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem; cursor: pointer;
  box-shadow: 0 6px 18px rgba(45,125,70,.45);
  -webkit-tap-highlight-color: transparent;
  transition: transform .15s ease, box-shadow .15s ease;
}
.msh__fab:active { transform: scale(.92); }
.msh__fab:hover { box-shadow: 0 8px 22px rgba(45,125,70,.55); }
</style>
