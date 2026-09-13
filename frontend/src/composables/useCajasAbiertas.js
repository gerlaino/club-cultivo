// DE QUÉ CAJA SALE EL EFECTIVO, O A CUÁL ENTRA.
//
// La misma pregunta la hacen tres pantallas de Contabilidad —registrar el pago de un gasto
// pendiente, cargar un movimiento nuevo y cargar un ingreso excepcional— y ya la hacía el carrito
// cuando administración dispensa del depósito. Una sola lista, del mismo endpoint que la pantalla
// del mostrador (`GET /mostradores`): las cajas ABIERTAS de los mostradores de la organización,
// cada una con su sede, desde cuándo y con quién. Sin caja abierta no hay nada que preguntar.
//
// Elegir no es obligatorio: sin caja, el asiento se escribe igual y no entra a ningún arqueo (la
// plata no pasó por el cajón). El backend valida que la elegida esté abierta y sea de la organización.
import { ref } from 'vue'
import { listMostradores } from '../lib/api.js'

export const SIN_CAJA = null

export function useCajasAbiertas() {
  const cajas    = ref([])
  const cargando = ref(false)

  async function cargar() {
    cargando.value = true
    try {
      const { data } = await listMostradores()
      cajas.value = (data?.mostradores || [])
        .filter(m => m.turno?.caja_turno_id)
        .map(m => ({
          id:      m.turno.caja_turno_id,
          sede_id: m.sede_id,
          sede:    m.sede,
          desde:   m.turno.desde,
          quien:   m.turno.quien,
        }))
    } catch {
      // Sin la lista no se traba nada: el movimiento se guarda sin caja, que es un estado válido.
      cajas.value = []
    } finally {
      cargando.value = false
    }
  }

  // La caja de la sede del movimiento, si está abierta: es la que casi siempre corresponde.
  const cajaDeSede = (sedeId) =>
    cajas.value.find(c => sedeId != null && String(c.sede_id) === String(sedeId))?.id ?? SIN_CAJA

  const etiqueta = (c) => {
    const hora = c.desde
      ? new Date(c.desde).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hour12: false })
      : ''
    return `Caja de ${c.sede}${hora ? ` · abierta ${hora}` : ''}${c.quien ? ` con ${c.quien}` : ''}`
  }

  return { cajas, cargando, cargar, cajaDeSede, etiqueta }
}
