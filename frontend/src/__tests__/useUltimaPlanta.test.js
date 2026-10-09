import { describe, it, expect, vi } from 'vitest'
import { useUltimaPlanta } from '../composables/useUltimaPlanta.js'
import { useConfirm } from '../composables/useConfirm.js'

// AC (9-oct-2026): descartar o eliminar la última planta viva cierra el lote, con un aviso antes
// para confirmar. El backend contesta 409 `ultima_planta`; sin confirmar no pasa nada.
const conflicto = () => Object.assign(new Error('409'), {
  response: { status: 409, data: { codigo: 'ultima_planta', error: 'Es la última planta viva del lote L-26-001' } },
})

describe('useUltimaPlanta', () => {
  it('sin aviso, el pedido va una sola vez y sin cerrar', async () => {
    const pedir = vi.fn().mockResolvedValue({ data: 'ok' })
    expect(await useUltimaPlanta()(pedir)).toEqual({ data: 'ok' })
    expect(pedir.mock.calls).toEqual([[false]])
  })

  it('con la última planta muestra el aviso del backend y, confirmado, repite cerrando', async () => {
    const pedir = vi.fn().mockRejectedValueOnce(conflicto()).mockResolvedValueOnce({ data: 'ok' })
    const { state, accept } = useConfirm()
    const p = useUltimaPlanta()(pedir)
    await vi.waitFor(() => expect(state.open).toBe(true))
    expect(state.message).toContain('L-26-001')
    accept()
    expect(await p).toEqual({ data: 'ok' })
    expect(pedir.mock.calls).toEqual([[false], [true]])
  })

  it('si se arrepiente, no repite y devuelve null', async () => {
    const pedir = vi.fn().mockRejectedValueOnce(conflicto())
    const { state, cancel } = useConfirm()
    const p = useUltimaPlanta()(pedir)
    await vi.waitFor(() => expect(state.open).toBe(true))
    cancel()
    expect(await p).toBeNull()
    expect(pedir).toHaveBeenCalledTimes(1)
  })

  it('otro error sigue de largo', async () => {
    const e = Object.assign(new Error('422'), { response: { status: 422, data: { error: 'Indicá el motivo' } } })
    await expect(useUltimaPlanta()(vi.fn().mockRejectedValue(e))).rejects.toBe(e)
  })
})
