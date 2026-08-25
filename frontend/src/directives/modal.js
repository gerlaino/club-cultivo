import { useConfirm } from '../composables/useConfirm.js'

// Directiva `v-modal`: lo que todo modal tiene que hacer y ninguno hacía igual.
//
// Va en el OVERLAY (la capa que tapa la pantalla) y recibe cómo se cierra ese modal:
//
//   <div class="mnd__overlay" v-modal="cerrar" @click.self="cerrar">
//   <div class="x__overlay"   v-modal="{ cerrar, sucio: () => items.length > 0 }">
//
// Hace cuatro cosas:
//   · pone el cursor en el primer campo, para poder tipear sin agarrar el mouse
//   · ESC cierra
//   · el Tab no se escapa del modal mientras está abierto
//   · al cerrarse devuelve el foco a donde estaba
//
// Antes esto vivía en ~20 modales, cada uno a su manera, y en los otros 55 no existía.

// Los modales abiertos, en orden de apertura. ESC actúa sobre el ÚLTIMO: con un modal encima de
// otro —la confirmación arriba de la dispensa— tiene que cerrarse el de arriba, no el de abajo.
const pila = []
let escuchando = false

const FOCUSABLES = [
  'input:not([type="hidden"]):not([disabled]):not([readonly])',
  'textarea:not([disabled]):not([readonly])',
  'select:not([disabled])',
  'button:not([disabled])',
  '[href]', '[tabindex]:not([tabindex="-1"])',
].join(',')

// Los que sirven para escribir. El foco va acá, no al primer <button>, que suele ser el de cerrar.
const ESCRIBIBLES = [
  'input:not([type="hidden"]):not([type="checkbox"]):not([type="radio"]):not([disabled]):not([readonly])',
  'textarea:not([disabled]):not([readonly])',
  'select:not([disabled])',
].join(',')

// Sin medir layout a propósito: `getClientRects()` depende de que el navegador haya pintado, y
// acá sólo hace falta saber si el modal está en pantalla. Casi todos usan `v-if`, así que
// `isConnected` alcanza; el `display` cubre a los que se ocultan con `v-show`.
function visible(el) {
  if (!el.isConnected) return false
  const cs = typeof getComputedStyle === 'function' ? getComputedStyle(el) : null
  return !cs || (cs.display !== 'none' && cs.visibility !== 'hidden')
}

// Sólo donde hay mouse. En un teléfono, enfocar un campo levanta el teclado y tapa medio modal.
const conMouse = () => typeof window !== 'undefined' &&
  window.matchMedia?.('(pointer: fine)')?.matches === true

function opciones(binding) {
  const v = binding.value
  if (typeof v === 'function') return { cerrar: v, sucio: null }
  return { cerrar: v?.cerrar || v?.close || null, sucio: v?.sucio || null }
}

// ¿Hay trabajo a medio hacer? Dos fuentes, y las dos hacen falta:
//   · que el usuario haya TIPEADO algo (lo marca el listener de abajo). No alcanza con mirar si
//     los campos tienen valor: un modal de edición nace lleno y preguntaría siempre.
//   · lo que el modal sepa de sí mismo y no esté en un input — el carrito de la dispensa son
//     divs, no campos, y se pierde igual.
function estaSucio(entrada) {
  return entrada.tecleado || entrada.opts.sucio?.() === true
}

async function intentarCerrar(entrada) {
  const { confirm } = useConfirm()

  if (estaSucio(entrada)) {
    const ok = await confirm({
      title:       '¿Cerrar sin guardar?',
      message:     'Hay datos cargados en este formulario que se van a perder.',
      variant:     'danger',
      confirmText: 'Cerrar sin guardar',
      cancelText:  'Seguir editando',
    })
    if (!ok) return
  }

  entrada.opts.cerrar?.()
}

function onKeydown(e) {
  const { state } = useConfirm()

  if (e.key === 'Tab') {
    const arriba = [...pila].reverse().find((x) => visible(x.el))
    if (!arriba) return
    const campos = [...arriba.el.querySelectorAll(FOCUSABLES)].filter(visible)
    if (!campos.length) return

    const primero = campos[0]
    const ultimo  = campos[campos.length - 1]
    // Sin esto el Tab se va a la página de atrás, que está tapada: el foco desaparece de la vista.
    if (e.shiftKey && document.activeElement === primero) { e.preventDefault(); ultimo.focus() }
    else if (!e.shiftKey && document.activeElement === ultimo) { e.preventDefault(); primero.focus() }
    return
  }

  if (e.key !== 'Escape') return
  // La confirmación es un modal aparte y se cierra sola con ESC: si además cerráramos el de abajo,
  // una tecla cerraría los dos.
  if (state.open) return

  const arriba = [...pila].reverse().find((x) => visible(x.el) && x.opts.cerrar)
  if (!arriba) return

  e.preventDefault()
  e.stopPropagation()
  intentarCerrar(arriba)
}

function escuchar() {
  if (escuchando) return
  document.addEventListener('keydown', onKeydown, true)
  escuchando = true
}

function dejarDeEscuchar() {
  if (!escuchando || pila.length) return
  document.removeEventListener('keydown', onKeydown, true)
  escuchando = false
}

export const vModal = {
  mounted(el, binding) {
    const entrada = {
      el,
      opts: opciones(binding),
      tecleado: false,
      previo: document.activeElement,
      marcar: () => { entrada.tecleado = true },
    }
    el.__modal = entrada
    pila.push(entrada)
    escuchar()

    // `input`/`change` en captura: sólo se disparan cuando la persona escribe. Vue asignando un
    // valor por código no los emite, así que un modal de edición precargado NO cuenta como sucio.
    el.addEventListener('input', entrada.marcar, true)
    el.addEventListener('change', entrada.marcar, true)

    if (!conMouse()) return
    // Un frame de espera: varios modales pintan sus campos recién después del primer render.
    requestAnimationFrame(() => {
      if (!el.isConnected) return
      // Si algo de adentro ya se enfocó solo (un autofocus propio), no se lo pisa.
      if (el.contains(document.activeElement) && document.activeElement !== document.body) return
      const campo = el.querySelector(ESCRIBIBLES)
      campo?.focus()
      campo?.select?.()
    })
  },

  updated(el, binding) {
    if (el.__modal) el.__modal.opts = opciones(binding)
  },

  unmounted(el) {
    const entrada = el.__modal
    if (!entrada) return

    el.removeEventListener('input', entrada.marcar, true)
    el.removeEventListener('change', entrada.marcar, true)

    const i = pila.indexOf(entrada)
    if (i !== -1) pila.splice(i, 1)
    delete el.__modal
    dejarDeEscuchar()

    // Devolver el foco a donde estaba: si no, queda en el <body> y el siguiente Tab arranca
    // desde el principio de la página.
    if (entrada.previo?.isConnected) entrada.previo.focus?.()
  },
}

export default vModal
