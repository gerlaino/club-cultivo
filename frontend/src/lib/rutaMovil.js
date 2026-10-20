// La versión de teléfono de una ruta de escritorio. Lo que el backend devuelve como ruta (el
// buscador, las últimas acciones) es la de escritorio; adentro del shell del teléfono las fichas
// viven bajo /m, y saltar a la de escritorio saca a la persona de la app.
const RUTAS_MOVIL = [
  [/^\/plantas\/(\d+)/, '/m/planta/$1'],
  [/^\/salas\/(\d+)/, '/m/sala-m/$1'],
  [/^\/lotes\/(\d+)/, '/m/lote-m/$1'],
  [/^\/camas\/(\d+)/, '/m/cama-m/$1'],
  [/^\/geneticas\/(\d+)/, '/m/geneticas/$1'],
  [/^\/pacientes\/(\d+)/, '/m/pacientes/$1'],
  [/^\/tareas/, '/m/tareas'],
]

export function rutaMovil (ruta) {
  if (!ruta) return ruta
  for (const [re, a] of RUTAS_MOVIL) if (re.test(ruta)) return ruta.replace(re, a)
  return ruta
}
