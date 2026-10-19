import { describe, it, expect } from 'vitest'
import {
  formVacio, desdePaciente, aPayload, validarPersona, validarReprocann,
} from '../components/pacientes/formulario/pacienteForm.js'
import { FILTROS, datosChicos } from '../composables/useSituacionPaciente.js'

// AC (Germán, 18 y 19-oct-2026): el alta y la edición son el mismo formulario. Al vinculado se le
// pregunta cómo está su REPROCANN y el sistema calcula el estado; el adherente se carga como figura.
// «No indicado» / «Rechazado» no se tocan desde el formulario. «Faltó al turno» va como dato chico.
describe('el formulario del paciente', () => {
  it('vinculado que «todavía no tiene»: viaja sin_registro y sin número viejo', () => {
    const f = { ...formVacio(), opcion_reprocann: 'sin', reprocann_numero: 'VIEJO', reprocann_vencimiento: '2020-01-01' }
    const p = aPayload(f)
    expect(p).toMatchObject({ reprocann_vinculo: 'organizacion', reprocann_estado: 'sin_registro', reprocann_numero: '', reprocann_vencimiento: '' })
    expect(p).not.toHaveProperty('opcion_reprocann')
  })

  it('vinculado «lo tiene aprobado»: pide número y vencimiento', () => {
    const f = { ...formVacio(), opcion_reprocann: 'aprobado' }
    expect(Object.keys(validarReprocann(f))).toEqual(['reprocann_numero', 'reprocann_vencimiento'])
    f.reprocann_numero = 'R-1'; f.reprocann_vencimiento = '2029-01-01'
    expect(validarReprocann(f)).toEqual({})
    expect(aPayload(f)).toMatchObject({ reprocann_estado: 'activo', reprocann_numero: 'R-1' })
  })

  it('en trámite: pendiente, sin número', () => {
    expect(aPayload({ ...formVacio(), opcion_reprocann: 'tramite' })).toMatchObject({ reprocann_estado: 'pendiente', reprocann_numero: '' })
  })

  it('adherente: viaja el estado tal como figura, y vigente si no se eligió', () => {
    const f = { ...formVacio(), reprocann_vinculo: 'otra_organizacion', reprocann_estado: 'vencido', reprocann_numero: 'X' }
    expect(aPayload(f)).toMatchObject({ reprocann_vinculo: 'otra_organizacion', reprocann_estado: 'vencido', reprocann_numero: 'X' })
    expect(aPayload({ ...f, reprocann_estado: 'sin_registro' }).reprocann_estado).toBe('activo')
    expect(validarReprocann(f)).toEqual({}) // el número del adherente es opcional
  })

  it('un REPROCANN «No indicado» no se cambia desde el formulario', () => {
    const f = desdePaciente({ nombre: 'A', reprocann_estado: 'no_indicado', reprocann_vinculo: 'organizacion' })
    expect(aPayload(f)).not.toHaveProperty('reprocann_estado')
  })

  it('al médico sólo le viajan los campos de salud', () => {
    const f = desdePaciente({ nombre: 'Ana', dni: '1', reprocann_estado: 'activo', reprocann_numero: 'R', reprocann_vencimiento: '2030-01-01' })
    expect(Object.keys(aPayload(f, { campos: ['reprocann_numero', 'reprocann_vencimiento', 'reprocann_estado', 'reprocann_vinculo'] })).sort())
      .toEqual(['reprocann_estado', 'reprocann_numero', 'reprocann_vencimiento', 'reprocann_vinculo'])
  })

  it('desdePaciente reconoce cómo está para volver a mostrarlo igual', () => {
    expect(desdePaciente({ reprocann_estado: 'pendiente' }).opcion_reprocann).toBe('tramite')
    expect(desdePaciente({ reprocann_estado: 'vencido' }).opcion_reprocann).toBe('vencido')
    expect(desdePaciente({ reprocann_estado: 'activo', reprocann_numero: 'R' }).opcion_reprocann).toBe('aprobado')
    expect(desdePaciente({ reprocann_estado: 'sin_registro' }).opcion_reprocann).toBe('sin')
  })

  it('la persona pide nombre, apellido, DNI de 7 a 9 dígitos y nacimiento pasado', () => {
    expect(Object.keys(validarPersona(formVacio())).sort()).toEqual(['apellido', 'dni', 'fecha_nacimiento', 'nombre'])
    const ok = { ...formVacio(), nombre: 'A', apellido: 'B', dni: '30.111.222', fecha_nacimiento: '1990-05-05' }
    expect(validarPersona(ok)).toEqual({})
    expect(validarPersona({ ...ok, dni: '123' })).toHaveProperty('dni')
    expect(validarPersona({ ...ok, email: 'no-es-mail' })).toHaveProperty('email')
  })
})

describe('los filtros de la lista leen la situación del backend', () => {
  const fila = (situacion) => ({ situacion })
  const vencido = fila({ reprocann: 'vencido', pendiente_entrevista: true, vinculo: 'vinculado' })
  const vigente = fila({ reprocann: 'activo', pendiente_entrevista: false, vinculo: 'vinculado' })
  const adherenteVencido = fila({ reprocann: 'vencido', pendiente_entrevista: false, vinculo: 'adherente' })

  it('«pendientes de entrevista» incluye al vencido vinculado y no al adherente vencido', () => {
    expect([vencido, vigente, adherenteVencido].filter(FILTROS.entrevista)).toEqual([vencido])
    expect([vencido, vigente, adherenteVencido].filter(FILTROS.vencidos)).toEqual([vencido, adherenteVencido])
  })

  it('sólo uno faltó al turno: sólo ese aparece', () => {
    const falto = fila({ reprocann: 'activo', falto_turno_el: '2026-10-12' })
    expect([falto, vigente].filter(FILTROS.falto)).toEqual([falto])
  })

  it('«faltó al turno» se muestra como dato chico con la fecha', () => {
    const textos = datosChicos({ reprocann: 'activo', falto_turno_el: '2026-10-12' }).map(d => d.texto)
    expect(textos).toEqual(['Faltó al turno del 12/10'])
  })

  it('vencido muestra los dos: el estado y «pendiente de entrevista» al lado', () => {
    expect(datosChicos(vencido.situacion).map(d => d.texto)).toContain('Pendiente de entrevista')
  })
})
