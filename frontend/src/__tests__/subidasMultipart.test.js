import { describe, it, expect, vi, beforeEach } from 'vitest'

// LOS ARCHIVOS VIAJAN COMO FORMULARIO (27-oct-2026). La instancia de axios manda
// `Content-Type: application/json` por defecto: un FormData con ese encabezado llegaba al backend
// como `{ "constancia": {} }` y la constancia del REPROCANN (y el adjunto del chat) se perdía. Toda
// subida tiene que decir `multipart/form-data`.

const post = vi.hoisted(() => vi.fn(() => Promise.resolve({ data: { data: {} } })))
vi.mock('../lib/api', async (original) => ({ ...(await original()), default: { post, get: vi.fn() } }))

const archivo = new File(['%PDF'], 'c.pdf', { type: 'application/pdf' })
const multipart = (llamada) => llamada[2]?.headers?.['Content-Type'] === 'multipart/form-data' && llamada[1] instanceof FormData

beforeEach(() => post.mockClear())

describe('Subidas del portal', () => {
  it('la constancia del REPROCANN', async () => {
    const { subirRenovacionReprocann } = await import('../lib/portalApi')
    await subirRenovacionReprocann(archivo)
    expect(multipart(post.mock.calls[0])).toBe(true)
  })

  it('el adjunto del chat del paciente', async () => {
    const { enviarPortalMensaje } = await import('../lib/portalApi')
    await enviarPortalMensaje({ texto: 'hola', archivo })
    expect(multipart(post.mock.calls[0])).toBe(true)
  })
})
