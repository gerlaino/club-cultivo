# Validación de direcciones de entrega (decisión pendiente)

> Planteado el 2026-06-23. **No implementado** — esperando decisión.

## Problema
La dirección de entrega viaja como **texto** ("Av. San Martín 1234") y Google la
geocodifica al vuelo al armar la ruta. Ese texto puede ser **ambiguo** (misma calle/altura
en varias ciudades o barrios) → el repartidor puede terminar en el lugar equivocado.

## La idea de fondo
Validar la dirección **una sola vez, al cargarla** (no por entrega), guardar **lat/lng**, y
armar la ruta de Maps con **coordenadas** (`destination=lat,lng`) → punto exacto, sin
ambigüedad. Bonus: las coordenadas son un activo de datos (densidad de entregas,
optimización de rutas a futuro).

## Opciones
- **A — Geocodificar + confirmar al guardar (recomendada).** Al guardar la dirección del
  paciente: geocodificar (Google Geocoding), mostrar mini-mapa, el operador confirma
  ("¿Es acá?"), guardar lat/lng. La ruta usa coordenadas.
  - Pros: resuelve la ambigüedad de raíz; el operador elige la correcta; queda el dato.
  - Contras: API key de Google + billing; migración `lat`/`lng` (paciente y/o snapshot en dispensación).
- **B — Autocomplete de Google Places.** El operador elige la dirección de una lista real al
  escribir; se guarda lat/lng.
  - Pros: mejor UX, validación en el ingreso.
  - Contras: cambia el form (estructurado → autocomplete); key de Google; costo por sesión.
- **C — Mapa gratis + pin manual.** Leaflet + OpenStreetMap; el operador arrastra el pin.
  - Pros: sin costo ni key.
  - Contras: Nominatim es menos preciso en Argentina → más ajuste manual.

## Costo (clave de la decisión)
Como se geocodifica **al cargar/editar** una dirección (no por entrega), el volumen es bajo
(≈ pacientes nuevos + ediciones por mes). A ~US$5/1.000 (Geocoding), un club de 50–300
direcciones/mes paga **~US$0,25–1,50/mes**, y normalmente cae dentro del tramo gratis
mensual de Google → **~$0**. La fricción real de Google no es el costo, es que **exige
billing con tarjeta** aunque uses el tramo gratis. (Pricing de Google cambió en 2025;
verificar el vigente al activar — el orden de magnitud se mantiene.)

## Recomendación
**Opción A con Google** si no molesta tener billing: mejor precisión en Argentina, costo
marginal, y deja coordenadas para el futuro. Si se prefiere evitar Google: **Opción C**
(gratis) asumiendo más trabajo manual y menos precisión automática.

## Impacto técnico (cuando se haga)
- Migración: `pacientes.lat`, `pacientes.lng` (y posiblemente `envio_lat/lng`); opcional
  snapshot `lat/lng` en `dispensaciones` al generar el despacho.
- Frontend: paso de confirmación con mini-mapa en el form de dirección (A) o autocomplete (B).
- Maps: `abrirEnMaps` usa `lat,lng` cuando existan; si no, cae al texto actual.
