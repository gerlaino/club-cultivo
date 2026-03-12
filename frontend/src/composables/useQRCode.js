import QRCode from 'qrcode'

export function useQRCode() {
  const generateQR = async (text, options = {}) => {
    try {
      const defaultOptions = {
        width: 512,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        },
        ...options
      }

      return await QRCode.toDataURL(text, defaultOptions)
    } catch (error) {
      console.error('Error generando QR:', error)
      throw error
    }
  }

  const downloadQR = async (text, filename = 'qr-code.png') => {
    try {
      const dataUrl = await generateQR(text)

      // Crear link temporal y descargar
      const link = document.createElement('a')
      link.href = dataUrl
      link.download = filename
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
    } catch (error) {
      console.error('Error descargando QR:', error)
      throw error
    }
  }

  return {
    generateQR,
    downloadQR
  }
}
