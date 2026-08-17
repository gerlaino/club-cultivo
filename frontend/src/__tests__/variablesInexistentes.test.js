import { describe, it, expect } from 'vitest'
import { ESLint } from 'eslint'

// AC: una variable que no existe no puede llegar a producción.
//
// Germán, probando: "ReferenceError: socio is not defined" al abrir la ficha de un paciente.
// Es la TERCERA vez que pasa lo mismo (antes fue `usePWA` sin importar, que dejaba en blanco la
// pantalla del QR de planta). El patrón es siempre igual: Vite no sabe si un identificador suelto
// es un global del navegador o un olvido, así que COMPILA FELIZ y la pantalla explota al abrirse.
//
// La red ya existía —ESLint lo marca con `no-undef`— pero nadie la corría. Este test la ata a la
// suite: si aparece una variable inexistente, falla acá y no en el navegador de un cliente.
//
// Sólo mira `no-undef`. El resto de las reglas (no-unused-vars, no-empty…) tienen deuda vieja y
// meterlas de golpe volvería el test un muro rojo que nadie lee. Esta es la que rompe pantallas.
describe('ninguna variable usada existe sólo en la imaginación', () => {
  it('no hay identificadores sin declarar (no-undef)', async () => {
    // Con caché: la pasada completa sobre `src` es cara y este archivo corre en paralelo con el
    // resto de la suite. Sin caché saturaba la máquina y los OTROS tests se caían por timeout,
    // uno distinto en cada corrida — un suite que falla al azar deja de leerse.
    const eslint = new ESLint({
      cwd: process.cwd(),
      cache: true,
      cacheLocation: 'node_modules/.cache/eslint-no-undef',
    })
    const resultados = await eslint.lintFiles(['src'])

    const errores = resultados.flatMap(r =>
      r.messages
        .filter(m => m.ruleId === 'no-undef')
        .map(m => `${r.filePath.replace(process.cwd() + '/', '')}:${m.line} — ${m.message}`)
    )

    expect(errores, errores.join('\n')).toEqual([])
    // Timeout largo a propósito: en frío esto lintea `src` entero mientras el resto de la suite
    // corre en paralelo, y tarda bastante más que solo. Cortarlo antes lo volvía un test que
    // fallaba por lento, no por encontrar algo — el peor tipo de rojo.
  }, 600_000)
})
