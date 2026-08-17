import { ref, computed } from 'vue'

// Dictado por voz, en un solo lugar.
//
// Estaba escrito dos veces dentro de AsistenteVoz (registro y consulta) y una tercera en
// VoiceInput, y las tres copias trataban distinto los mismos casos de borde. Es la misma
// historia de siempre: una regla en varios lados que dejan de coincidir.
//
// El navegador manda el audio a un servicio remoto (en Chrome, el de Google) y devuelve texto.
// Eso significa que necesita internet, que puede tardar en arrancar, y que en una PWA instalada
// a veces el servicio queda bloqueado aunque el micrófono tenga permiso. Los tres casos se
// distinguen y se explican distinto.

// Mensajes que dicen QUÉ HACER. "Error de micrófono: not-allowed" no le sirve a nadie.
export const MENSAJE_ERROR_VOZ = {
  'not-allowed':         'No hay permiso de micrófono. Habilitalo para este sitio en los ajustes del navegador.',
  'service-not-allowed': 'El navegador bloqueó el dictado. Escribilo abajo, o usá el micrófono del teclado del teléfono.',
  'audio-capture':       'No se detectó ningún micrófono.',
  'network':             'El dictado necesita internet y no pudo conectarse. Escribilo abajo.',
  'no-speech':           'No te escuché. Probá de nuevo, más cerca del micrófono.',
  'aborted':             'Se interrumpió la grabación.',
}

export const SOPORTA_VOZ = () =>
  typeof window !== 'undefined' &&
  !!(window.SpeechRecognition || window.webkitSpeechRecognition)

// Chrome Android corta la sesión sola en cada pausa: `continuous` no es confiable ahí.
const esMovil = () => /Android|iPhone|iPad|iPod/i.test(navigator.userAgent || '')

/**
 * @param {Object}   opts
 * @param {string}   opts.idioma
 * @param {Function} opts.alTerminar  (texto, porPedido) cuando la grabación cierra con algo
 */
export function useReconocimientoVoz({ idioma = 'es-AR', alTerminar = null } = {}) {
  const escuchando = ref(false)
  const texto      = ref('')   // lo que quedó confirmado
  const interim    = ref('')   // lo que el servicio todavía está corrigiendo
  const error      = ref(null)

  const soportado = computed(() => SOPORTA_VOZ())

  let rec           = null
  let arranco       = false  // el servicio llegó a escuchar de verdad
  let cortePedido   = false  // el usuario apretó "parar"
  let errorDelMotor = null   // el código que tiró el navegador, si tiró alguno
  let reinicios     = 0
  let arrancando    = false  // hay un `iniciar()` a mitad de camino

  // Cuántas veces se vuelve a levantar la sesión sola. Con tope: si el servicio cortara al
  // instante una y otra vez, sin esto quedaría un bucle de arranques girando en el teléfono.
  const MAX_REINICIOS = 8

  // El permiso se pide APARTE, con getUserMedia, antes de arrancar el dictado.
  //
  // En una PWA instalada, SpeechRecognition no siempre dispara el cartel de permiso: falla en
  // silencio y no hay forma de saber si fue eso o el servicio. Pidiéndolo primero, "no diste
  // permiso" se distingue de "el navegador no deja dictar", que se arreglan distinto.
  //
  // La pista se suelta EN EL ACTO: con el micrófono tomado, el servicio de dictado no lo
  // consigue en varios Android y la grabación sale vacía.
  async function asegurarPermiso() {
    if (!navigator.mediaDevices?.getUserMedia) return true  // navegador viejo: que lo intente igual
    try {
      const pista = await navigator.mediaDevices.getUserMedia({ audio: true })
      pista.getTracks().forEach(t => t.stop())
      return true
    } catch (e) {
      error.value = e?.name === 'NotFoundError'
        ? MENSAJE_ERROR_VOZ['audio-capture']
        : MENSAJE_ERROR_VOZ['not-allowed']
      return false
    }
  }

  // Un solo motor a la vez. `escuchando` recién se prende en `onstart`, que llega DESPUÉS del
  // cartel de permiso: entre el toque y el arranque el botón se deja apretar de nuevo, y así se
  // creaban dos instancias. La primera quedaba huérfana pero viva, y su `onend` disparaba
  // `alTerminar` con lo dictado antes, pisando la grabación en curso.
  async function iniciar() {
    if (arrancando || rec) return false
    arrancando = true
    try {
      return await arrancar()
    } finally {
      arrancando = false
    }
  }

  async function arrancar() {
    error.value = null; texto.value = ''; interim.value = ''
    errorDelMotor = null; arranco = false; cortePedido = false; reinicios = 0

    if (!soportado.value) {
      error.value = 'Este navegador no sabe dictar. Escribilo abajo, o abrí la app desde Chrome.'
      return false
    }
    if (!(await asegurarPermiso())) return false

    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    rec = new SR()
    rec.lang            = idioma
    rec.continuous      = !esMovil()
    rec.interimResults  = true
    rec.maxAlternatives = 1

    rec.onstart = () => { arranco = true; escuchando.value = true }

    rec.onresult = (e) => {
      let final = '', enCurso = ''
      for (let i = 0; i < e.results.length; i++) {
        if (e.results[i].isFinal) final += e.results[i][0].transcript
        else                      enCurso += e.results[i][0].transcript
      }
      // En el teléfono cada tramo llega como sesión nueva: se acumula en vez de pisarse, si no
      // sólo sobreviviría la última frase.
      if (final) {
        texto.value = rec.continuous ? final : [texto.value, final].filter(Boolean).join(' ').trim()
      }
      interim.value = enCurso
    }

    // No se muestra acá: se guarda. El cartel lo decide `cerrar()`, que es el único que sabe si
    // al final hubo texto o no.
    rec.onerror = (e) => { errorDelMotor = e.error }

    // Sin `continuous` (el teléfono) el servicio cierra la sesión en CADA pausa. Si no se la
    // vuelve a levantar, todo lo que se dice después de la primera coma se pierde: quedaba
    // registrada la primera frase y nada más, sin ningún aviso. Se relevanta mientras la
    // persona no haya pedido parar.
    rec.onend = () => {
      const cortoSolo = !cortePedido && arranco &&
                        (!errorDelMotor || errorDelMotor === 'no-speech')
      if (cortoSolo && reinicios < MAX_REINICIOS) {
        reinicios++
        errorDelMotor = null
        // Lo que estaba a medio corregir se da por dicho antes de reiniciar: la sesión nueva
        // arranca con el contador de resultados en cero y ese tramo no vuelve.
        if (interim.value) {
          texto.value = [texto.value, interim.value].filter(Boolean).join(' ').trim()
          interim.value = ''
        }
        try { rec.start(); return } catch { /* no pudo: cierra normal */ }
      }
      cerrar()
    }

    try {
      rec.start()
    } catch {
      // start() sobre una instancia ya arrancada tira InvalidStateError. Se suelta la instancia:
      // dejarla colgada bloquearía todos los intentos siguientes, que miran `rec` para no
      // levantar dos motores.
      cancelar()
      return false
    }
    return true
  }

  function cerrar() {
    escuchando.value = false
    // La sesión terminó: la instancia no sirve más y tiene que quedar en null, que es lo que
    // `iniciar()` mira para saber si ya hay un motor dando vueltas.
    rec = null

    // Lo que el servicio todavía estaba corrigiendo también es lo que dijo la persona. Tirarlo
    // era la causa de "no escuché nada" con el texto a la vista en pantalla: en frases cortas el
    // último tramo nunca llega a confirmarse antes de que se corte la sesión.
    const dicho = [texto.value, interim.value].filter(Boolean).join(' ').trim()
    interim.value = ''
    texto.value   = dicho

    // `porPedido` distingue "la persona dijo que terminó" de "el servicio cortó solo". No es lo
    // mismo: cortar solo después de una pausa no significa que la frase esté completa, y quien
    // llama puede querer esperar en ese caso.
    if (dicho) { error.value = null; alTerminar?.(dicho, cortePedido); return }

    // Sin texto hay que decir POR QUÉ, y el motivo verdadero lo tiene el motor. Escribir siempre
    // "no escuché nada" tapaba el permiso denegado y el servicio bloqueado, que son las dos
    // causas reales en la PWA instalada, y dejaba a la persona repitiendo la misma frase.
    if (errorDelMotor) {
      error.value = MENSAJE_ERROR_VOZ[errorDelMotor] || `No se pudo dictar (${errorDelMotor}).`
    } else if (!arranco) {
      // Soltó antes de que el servicio llegara a escuchar. Es un toque en falso, no un error:
      // avisarle de algo sería culparlo por apurarse.
      error.value = null
    } else if (cortePedido) {
      error.value = MENSAJE_ERROR_VOZ['no-speech']
    }
  }

  function detener() {
    if (!rec) return
    cortePedido = true
    // Si nunca arrancó, `stop()` puede no disparar `onend`: se corta de raíz.
    if (arranco) rec.stop()
    else { rec.abort(); cerrar() }
  }

  function cancelar() {
    if (rec) { rec.onend = null; rec.abort(); rec = null }
    escuchando.value = false; interim.value = ''
  }

  function limpiar() { texto.value = ''; interim.value = ''; error.value = null }

  return { escuchando, texto, interim, error, soportado, iniciar, detener, cancelar, limpiar }
}
