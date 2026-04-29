import QRCode from 'qrcode'

const BASE_OPTS = {
  margin: 4,
  width: 512,
  color: { dark: '#000000', light: '#FFFFFF' },
}

export function useQRCode() {

  async function generatePNG(url, opts = {}) {
    return QRCode.toDataURL(url, { ...BASE_OPTS, width: Math.max(opts.width ?? 512, 256), ...opts })
  }

  async function generateSVG(url, opts = {}) {
    return QRCode.toString(url, {
      type: 'svg',
      ...BASE_OPTS,
      width: Math.max(opts.width ?? 512, 256),
      ...opts,
    })
  }

  function _trigger(href, filename) {
    const a = document.createElement('a')
    a.href = href
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
  }

  async function downloadPNG(url, filename = 'qr.png') {
    const dataUrl = await generatePNG(url)
    _trigger(dataUrl, filename)
  }

  async function downloadSVG(url, filename = 'qr.svg') {
    const svg = await generateSVG(url)
    const blob = new Blob([svg], { type: 'image/svg+xml' })
    const href = URL.createObjectURL(blob)
    _trigger(href, filename)
    URL.revokeObjectURL(href)
  }

  // Legacy aliases
  const generateQR = generatePNG
  const downloadQR = downloadPNG

  return { generatePNG, generateSVG, downloadPNG, downloadSVG, generateQR, downloadQR }
}
