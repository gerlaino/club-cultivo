import { describe, it, expect, vi, beforeEach } from 'vitest'

// Las descargas de informes usan responseType 'blob', así que el CUERPO DEL ERROR también
// llega como blob. Sin leerlo, un rechazo con motivo —faltan variedades por declarar ante el
// INASE— se mostraba como "no se pudo generar, reintentá", y reintentar no lo resuelve nunca.
const toastError = vi.fn()

vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ error: toastError, success: vi.fn(), info: vi.fn() }),
}))

const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))

// Un blob como el que devuelve axios cuando el server responde JSON con responseType blob.
const blobDe = (obj) => ({ text: () => Promise.resolve(JSON.stringify(obj)) })

describe('Descarga de informes — el motivo del rechazo llega al usuario', () => {
  let useInformePdf

  beforeEach(async () => {
    vi.clearAllMocks()
    ;({ useInformePdf } = await import('../composables/useInformePdf.js'))
    global.URL.createObjectURL = vi.fn(() => 'blob:x')
    global.URL.revokeObjectURL = vi.fn()
  })

  it('muestra el motivo y qué genéticas faltan declarar', async () => {
    apiGet.mockRejectedValue({
      response: {
        status: 422,
        data: blobDe({
          error: 'No se puede descargar el informe: hay variedades sin acreditar.',
          geneticas_sin_declarar: ['Critical Kush', 'Lemon'],
          requiere_declaracion_inase: true,
        }),
      },
    })

    const { exportarPdf } = useInformePdf('informe_inase')
    await exportarPdf()

    const mensaje = toastError.mock.calls[0][0]
    expect(mensaje).toContain('variedades sin acreditar')
    expect(mensaje).toContain('Critical Kush')
    expect(mensaje).toContain('Lemon')
  })

  it('ante un error sin cuerpo cae al mensaje genérico', async () => {
    apiGet.mockRejectedValue(new Error('network'))

    const { exportarPdf } = useInformePdf('informe_inase')
    await exportarPdf()

    expect(toastError.mock.calls[0][0]).toMatch(/No se pudo generar el archivo/)
  })

  it('cuando sale bien no molesta con ningún error', async () => {
    apiGet.mockResolvedValue({ data: new Blob(['pdf']) })

    const { exportarPdf } = useInformePdf('informe_inase')
    await exportarPdf()

    expect(toastError).not.toHaveBeenCalled()
  })
})
