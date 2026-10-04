// Las tipografías de las páginas públicas (dirección «Herbario»: Fraunces para títulos, Public Sans
// para texto, JetBrains Mono para datos). Se cargan SÓLO cuando se abre una página pública: la app
// de adentro sigue con las suyas y no paga la descarga.
const HREF = 'https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600;9..144,700&family=Public+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap'

export function cargarFuentesHerbario () {
  if (typeof document === 'undefined' || document.querySelector(`link[href="${HREF}"]`)) return
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = HREF
  document.head.appendChild(link)
}
