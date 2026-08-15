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
    const eslint = new ESLint({ cwd: process.cwd() })
    const resultados = await eslint.lintFiles(['src'])

    const errores = resultados.flatMap(r =>
      r.messages
        .filter(m => m.ruleId === 'no-undef')
        .map(m => `${r.filePath.replace(process.cwd() + '/', '')}:${m.line} — ${m.message}`)
    )

    expect(errores, errores.join('\n')).toEqual([])
  }, 120_000)
})
