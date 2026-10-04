// QUIÉN ES EL TITULAR DE CULTIVO ESPACIAL, para los Términos y la Política de privacidad.
//
// La Ley 24.240 (art. 4) y la 25.326 piden que quien presta el servicio y quien es responsable de
// los datos estén identificados. Lo que todavía no está definido queda en `null` y la página lo
// muestra marcado «a completar» — nunca se inventa un CUIT o un domicilio.
//
// Cuando cambie algo que afecte a lo que la gente aceptó, también cambia `Legal::TERMINOS_VERSION`
// en el backend (es la versión que queda guardada con cada registro).
export const TITULAR = {
  nombre:        null, // razón social o nombre del titular
  cuit:          null,
  domicilio:     null,
  jurisdiccion:  null, // tribunales para organizaciones (para consumidores rige su domicilio)
  mail:          'cultivoespacial.arg@gmail.com',
}

export const VIGENCIA = '4 de octubre de 2026'
