#!/usr/bin/env node
/**
 * Compila los manuales de usuario: una tarea se escribe UNA vez y aparece en el manual de cada
 * rol que la declara. Ver docs/manuales/README.md para el porqué.
 *
 *   node scripts/manuales.cjs           → todos los roles
 *   node scripts/manuales.cjs admin     → uno solo
 *
 * Markdown → HTML (plantilla propia) → PDF con wkhtmltopdf. No usa pandoc: no está instalado.
 */
const fs   = require('fs')
const path = require('path')
const { execFileSync } = require('child_process')

const RAIZ    = path.join(__dirname, '..')
const TAREAS  = path.join(RAIZ, 'docs/manuales/tareas')
const SALIDA  = path.join(RAIZ, 'docs/manuales/dist')

// El orden en que se entregan y cómo se presenta cada uno. `super_admin` no está: es el equipo
// de la plataforma, no un cliente.
const ROLES = {
  admin:       { titulo: 'Administrador',  bajada: 'Todo lo que pasa dentro de la organización.' },
  cultivador:  { titulo: 'Cultivador',     bajada: 'El cuarto de cultivo: salas, lotes y plantas.' },
  manicura:    { titulo: 'Manicura',       bajada: 'Post-cosecha: pesar lo que se cosechó.' },
  dispensador: { titulo: 'Dispensador',    bajada: 'El mostrador: dispensar, cobrar y stock.' },
  medico:      { titulo: 'Médico',         bajada: 'Pacientes, indicaciones y turnos.' },
  supervisor:  { titulo: 'Supervisor',     bajada: 'Seguimiento del cultivo y del mostrador.' },
  delivery:    { titulo: 'Delivery',       bajada: 'Los paquetes asignados y su entrega.' },
  auditor:     { titulo: 'Auditor',        bajada: 'Consulta e informes, sólo lectura.' },
  abogado:     { titulo: 'Abogado',        bajada: 'Cumplimiento e informes legales.' },
  paciente:    { titulo: 'Paciente',       bajada: 'Tu perfil, tus retiros y tu carnet.' },
}

// El orden en que se leen los módulos dentro de un manual. Alfabético no sirve: dejaba
// "Configuración" antes que "Primeros pasos". Un módulo que no esté acá va al final, para que
// agregar uno nuevo no rompa la generación — sólo quede último hasta que se lo ubique.
const ORDEN_MODULOS = [
  'Primeros pasos',
  'Pacientes',
  'Dispensaciones',
  'Cultivo',
  'Post-cosecha',
  'Stock',
  'Módulo médico',
  'Configuración',
]
const pesoModulo = m => {
  const i = ORDEN_MODULOS.indexOf(m)
  return i === -1 ? ORDEN_MODULOS.length : i
}

// ── Frontmatter: sólo lo que necesitamos. Un parser YAML completo sería una dependencia nueva
// para leer cuatro claves planas.
function leerTarea(archivo) {
  const crudo = fs.readFileSync(archivo, 'utf8')
  const m = crudo.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/)
  if (!m) throw new Error(`${path.basename(archivo)}: falta el frontmatter (--- ... ---)`)

  const meta = {}
  for (const linea of m[1].split(/\r?\n/)) {
    const mm = linea.match(/^(\w+):\s*(.*)$/)
    if (!mm) continue
    const [, k, v] = mm
    meta[k] = v.startsWith('[')
      ? v.replace(/[[\]]/g, '').split(',').map(s => s.trim()).filter(Boolean)
      : v.trim()
  }

  const falta = ['titulo', 'roles', 'modulo'].filter(k => !meta[k] || !meta[k].length)
  if (falta.length) throw new Error(`${path.basename(archivo)}: falta ${falta.join(', ')}`)

  return { ...meta, orden: Number(meta.orden || 999), cuerpo: m[2].trim(), archivo }
}

// ── Markdown mínimo: el que usamos en las tareas y nada más. Una librería entera para
// encabezados, listas, negrita y tablas sería una dependencia que hay que mantener.
function md(texto) {
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const inline = s => esc(s)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>')

  const out = []
  let lista = null, enTabla = false

  const cerrar = () => { if (lista) { out.push(`</${lista}>`); lista = null } }
  const cerrarTabla = () => { if (enTabla) { out.push('</tbody></table>'); enTabla = false } }

  for (const linea of texto.split(/\r?\n/)) {
    const l = linea.trimEnd()

    if (/^\|/.test(l)) {
      const celdas = l.split('|').slice(1, -1).map(c => c.trim())
      if (/^[\s|:-]+$/.test(l)) continue                       // separador de cabecera
      if (!enTabla) {
        cerrar()
        out.push('<table><thead><tr>' + celdas.map(c => `<th>${inline(c)}</th>`).join('') + '</tr></thead><tbody>')
        enTabla = true
      } else {
        out.push('<tr>' + celdas.map(c => `<td>${inline(c)}</td>`).join('') + '</tr>')
      }
      continue
    }
    cerrarTabla()

    if (!l.trim()) { cerrar(); continue }

    const h = l.match(/^(#{2,4})\s+(.*)$/)
    if (h) { cerrar(); out.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`); continue }

    const ol = l.match(/^\s*\d+\.\s+(.*)$/)
    if (ol) {
      if (lista !== 'ol') { cerrar(); out.push('<ol>'); lista = 'ol' }
      out.push(`<li>${inline(ol[1])}</li>`); continue
    }

    const ul = l.match(/^\s*[-*]\s+(.*)$/)
    if (ul) {
      if (lista !== 'ul') { cerrar(); out.push('<ul>'); lista = 'ul' }
      out.push(`<li>${inline(ul[1])}</li>`); continue
    }

    if (/^>\s?/.test(l)) { cerrar(); out.push(`<blockquote>${inline(l.replace(/^>\s?/, ''))}</blockquote>`); continue }

    cerrar()
    out.push(`<p>${inline(l)}</p>`)
  }
  cerrar(); cerrarTabla()
  return out.join('\n')
}

const CSS = `
  @page { margin: 20mm 16mm; }
  body { font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; color: #16211b;
         font-size: 10.5pt; line-height: 1.55; }
  .portada { page-break-after: always; padding-top: 55mm; }
  .portada h1 { font-size: 30pt; margin: 0 0 .2em; letter-spacing: -.02em; }
  .portada .rol { font-size: 15pt; color: #40684c; font-weight: 700; margin: 0 0 1.2em; }
  .portada .bajada { font-size: 11pt; color: #55605a; max-width: 105mm; }
  .portada .pie { margin-top: 22mm; font-size: 8.5pt; color: #8b9186; }
  h2 { font-size: 15pt; margin: 1.6em 0 .5em; padding-bottom: .25em;
       border-bottom: 2px solid #40684c; page-break-after: avoid; }
  h3 { font-size: 11.5pt; margin: 1.3em 0 .35em; color: #1d3327; page-break-after: avoid; }
  h4 { font-size: 10.5pt; margin: 1em 0 .3em; color: #40684c; page-break-after: avoid; }
  p, li { orphans: 3; widows: 3; }
  ul, ol { padding-left: 1.15em; }
  li { margin-bottom: .2em; }
  code { background: #eef1ee; padding: .1em .3em; border-radius: 3px; font-size: 9pt; }
  blockquote { margin: .7em 0; padding: .5em .8em; background: #f4f7f4;
               border-left: 3px solid #40684c; color: #3c4a41; }
  table { border-collapse: collapse; width: 100%; margin: .7em 0; font-size: 9.5pt;
          page-break-inside: avoid; }
  th, td { border: 1px solid #d7dcd8; padding: .35em .5em; text-align: left; vertical-align: top; }
  th { background: #f4f7f4; }
  .indice { page-break-after: always; }
  .indice li { margin-bottom: .3em; }
`

function compilar(rol, tareas, fecha) {
  const meta  = ROLES[rol]
  const mias  = tareas
    .filter(t => t.roles.includes(rol))
    .sort((a, b) => pesoModulo(a.modulo) - pesoModulo(b.modulo) ||
                    a.modulo.localeCompare(b.modulo) ||
                    a.orden - b.orden ||
                    a.titulo.localeCompare(b.titulo))

  if (!mias.length) return null

  const modulos = []
  for (const t of mias) {
    let m = modulos.find(x => x.nombre === t.modulo)
    if (!m) { m = { nombre: t.modulo, tareas: [] }; modulos.push(m) }
    m.tareas.push(t)
  }

  const cuerpo = modulos.map(m =>
    `<h2>${m.nombre}</h2>\n` + m.tareas.map(t => `<h3>${t.titulo}</h3>\n${md(t.cuerpo)}`).join('\n')
  ).join('\n')

  const indice = modulos.map(m =>
    `<li><strong>${m.nombre}</strong><ul>${m.tareas.map(t => `<li>${t.titulo}</li>`).join('')}</ul></li>`
  ).join('')

  return `<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>Manual de ${meta.titulo} — Cultivo Espacial</title><style>${CSS}</style></head><body>
<div class="portada">
  <h1>Cultivo Espacial</h1>
  <p class="rol">Manual de ${meta.titulo}</p>
  <p class="bajada">${meta.bajada}</p>
  <p class="pie">Actualizado el ${fecha}</p>
</div>
<div class="indice"><h2>Contenido</h2><ul>${indice}</ul></div>
${cuerpo}
</body></html>`
}

// ── Main
const pedidos = process.argv.slice(2).filter(a => !a.startsWith('-'))
const fecha   = new Date().toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })

if (!fs.existsSync(TAREAS)) { console.error(`No existe ${TAREAS}`); process.exit(1) }
fs.mkdirSync(SALIDA, { recursive: true })

const archivos = fs.readdirSync(TAREAS).filter(f => f.endsWith('.md')).map(f => path.join(TAREAS, f))
if (!archivos.length) { console.error('No hay tareas en docs/manuales/tareas/'); process.exit(1) }

let tareas
try {
  tareas = archivos.map(leerTarea)
} catch (e) {
  console.error(`✗ ${e.message}`); process.exit(1)
}

// Un rol mal escrito en el frontmatter haría que la tarea no aparezca en ningún manual, sin que
// nada lo diga. Mejor frenar.
const desconocidos = [...new Set(tareas.flatMap(t => t.roles))].filter(r => !ROLES[r])
if (desconocidos.length) {
  console.error(`✗ Roles que no existen: ${desconocidos.join(', ')}`)
  process.exit(1)
}

const objetivo = pedidos.length ? pedidos : Object.keys(ROLES)
let generados = 0

for (const rol of objetivo) {
  if (!ROLES[rol]) { console.error(`✗ Rol desconocido: ${rol}`); process.exit(1) }

  const html = compilar(rol, tareas, fecha)
  if (!html) { console.log(`· ${rol}: sin tareas todavía`); continue }

  const htmlPath = path.join(SALIDA, `manual-${rol}.html`)
  const pdfPath  = path.join(SALIDA, `manual-${rol}.pdf`)
  fs.writeFileSync(htmlPath, html)

  try {
    // Sin flags de encabezado/pie a propósito: el wkhtmltopdf del sistema (0.12.6 sin qt
    // parcheado) no los soporta y rechaza la invocación entera. La identidad va en la portada
    // y en los títulos de sección, que es suficiente para un manual.
    execFileSync('wkhtmltopdf', ['--enable-local-file-access', '--quiet', htmlPath, pdfPath],
                 { stdio: ['ignore', 'ignore', 'inherit'] })
    const kb = Math.round(fs.statSync(pdfPath).size / 1024)
    console.log(`✓ manual-${rol}.pdf (${kb} KB)`)
    generados++
  } catch {
    console.error(`✗ wkhtmltopdf falló en ${rol}. Queda el HTML: ${htmlPath}`)
  }
}

console.log(`\n${generados} manual${generados === 1 ? '' : 'es'} en docs/manuales/dist/`)
