import { describe, it, expect, vi, beforeEach } from 'vitest'

// AC (Germán, 12-oct-2026): super admin puede dar de alta por encima del cupo del plan (se cobra
// aparte), pero no sin enterarse: el backend responde 409 y la pantalla pregunta antes de reenviar.
const createSuperAdminUser = vi.fn()
vi.mock('../lib/api.js', () => ({ createSuperAdminUser: (...a) => createSuperAdminUser(...a) }))
const { altaConCupo } = await import('../lib/altaEquipo.js')

const conflicto = { response: { status: 409, data: { excede_cupo: true, mensaje: 'Pasa el cupo del plan: ya tiene 2 de 2 (Cultivador).' } } }

describe('Alta de equipo con cupo', () => {
  beforeEach(() => createSuperAdminUser.mockReset())

  it('dentro del cupo da de alta sin preguntar', async () => {
    createSuperAdminUser.mockResolvedValue({ data: { id: 1 } })
    const confirm = vi.fn()
    expect(await altaConCupo({ role: 'cultivador' }, confirm)).toEqual({ id: 1 })
    expect(confirm).not.toHaveBeenCalled()
  })

  it('pasando el cupo pregunta y, confirmado, reenvía con exceder_cupo', async () => {
    createSuperAdminUser.mockRejectedValueOnce(conflicto).mockResolvedValueOnce({ data: { id: 2, excede_cupo: true } })
    const confirm = vi.fn().mockResolvedValue(true)
    const r = await altaConCupo({ role: 'cultivador' }, confirm)
    expect(confirm.mock.calls[0][0].message).toContain('2 de 2')
    expect(createSuperAdminUser).toHaveBeenLastCalledWith({ role: 'cultivador', exceder_cupo: true })
    expect(r.excede_cupo).toBe(true)
  })

  it('si no confirma, no da de alta a nadie', async () => {
    createSuperAdminUser.mockRejectedValueOnce(conflicto)
    expect(await altaConCupo({ role: 'cultivador' }, vi.fn().mockResolvedValue(false))).toBeNull()
    expect(createSuperAdminUser).toHaveBeenCalledTimes(1)
  })

  it('otro error se propaga tal cual', async () => {
    createSuperAdminUser.mockRejectedValueOnce({ response: { status: 422, data: { errors: ['x'] } } })
    await expect(altaConCupo({}, vi.fn())).rejects.toBeTruthy()
  })
})
