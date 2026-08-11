// Qué tipos de sede puede crear una organización, según las suites que contrató.
//
// Espeja `Sede::SUITES_POR_TIPO` del backend, que es el candado real. Vive acá y no copiado en
// cada pantalla porque hay DOS puertas —el onboarding y el alta de sedes— y con una lista en
// cada una terminaban ofreciendo cosas distintas; la que quedaba desactualizada mandaba al
// usuario a un 422 que no podía resolver.
export const SUITES_POR_TIPO_SEDE = {
  produccion: ['cultivo'],                          // salas, lotes y plantas
  social:     ['produccion_dispensa'],              // pacientes y dispensaciones
  mixta:      ['cultivo', 'produccion_dispensa'],   // las dos cosas en el mismo espacio
}

export function tiposDeSedeDisponibles(features = {}) {
  const f = features || {}
  return Object.entries(SUITES_POR_TIPO_SEDE)
    .filter(([, suites]) => suites.every(s => f[s] === true))
    .map(([tipo]) => tipo)
}
