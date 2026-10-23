// CUÁNTAS CONSULTAS NADIE ATENDIÓ (22-oct-2026). Llegaban pedidos por el formulario y nada lo
// avisaba: había que entrar a Consultas a ver. Un solo número compartido entre la barra lateral, la
// bandeja y el Inicio, así contestar una lo baja en todos lados sin recargar.
import { ref } from 'vue'
import { getConsultasPendientes } from '../lib/api.js'

const pendientes = ref(0)

async function refrescar () {
  try {
    const { data } = await getConsultasPendientes()
    pendientes.value = Number(data?.pendientes) || 0
  } catch { /* sin número: no es una alarma */ }
}

export function useConsultasPendientes () {
  return { pendientes, refrescar }
}
