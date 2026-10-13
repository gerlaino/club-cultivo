import { createSuperAdminUser } from './api.js'

// El alta del equipo desde super admin (la única puerta desde el 12-oct-2026). Si pasa el cupo
// del plan, el backend responde 409 con el detalle: se pregunta y, confirmado, se reenvía con
// `exceder_cupo`. El excedente se cobra aparte y queda a la vista en la ficha de la organización.
export async function altaConCupo(payload, confirm) {
  try {
    return (await createSuperAdminUser(payload)).data
  } catch (e) {
    const d = e?.response?.data
    if (e?.response?.status !== 409 || !d?.excede_cupo) throw e
    const ok = await confirm({
      title: 'Pasa el cupo del plan',
      message: `${d.mensaje}\n\n¿Lo das de alta igual?`,
      confirmText: 'Dar de alta igual',
    })
    if (!ok) return null
    return (await createSuperAdminUser({ ...payload, exceder_cupo: true })).data
  }
}
