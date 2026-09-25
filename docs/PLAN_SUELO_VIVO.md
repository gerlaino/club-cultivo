# Plan: suelo vivo (camas de cultivo)

> **HECHO el 25-sep-2026** (bloques 1 a 6 juntos; CHANGELOG (dg)). Desvíos del plan, a propósito:
> - **Lo que se le pone a la cama mientras descansa queda en la cama** (como el armado), no se le
>   carga al próximo ciclo: el próximo ciclo puede tener lotes que entran después y no hay cómo
>   repartir sin inventar. La ficha muestra «puesto en la cama ÷ gramos cosechados».
> - **Metales pesados en el análisis de suelo, sí** (plomo, cadmio, arsénico, mercurio). El
>   microbiológico y metales de la FLOR siguen pendientes (D9, bloque aparte).
> - **Búsqueda por insumo (D13)**: no hay pantalla; los datos quedan (`insumo_consumos.cama_id`,
>   `cama_registro_id`).

> Escrito el 22-sep-2026; **dudas contestadas el 25-sep** («ok a todo»: van las recomendaciones, ver §8).
> Sin código todavía. Lo marcado con **❓** era una duda; la respuesta está en §8.

## 1. Qué decidió Germán

- Vale para **uso personal y para organizaciones**.
- Se cultiva en **camas**, no en macetas.
- Una cama puede **descansar**. El patrón típico: dos camas que se alternan (se cosecha en A, se
  planta en B y A descansa).
- Plantar en una cama que descansa **avisa, no bloquea**.
- **Puede haber más de un lote por cama**, porque el lote agrupa por genética, no por lugar.
- **Hay tantas camas como entren en el espacio**: los m² de las camas tienen que ser coherentes
  con los m² de la sala.
- Que no queden huecos: en suelo vivo **no hay trasplantes** y **se alimenta el suelo, no el
  riego**. Cada modal de alta, edición y registro tiene que respetar eso.

## 2. Cómo lo vive el usuario

Lo que tiene que sentir el que cultiva en suelo vivo:

1. **La app habla su idioma.** No le pide pH de entrada, EC ni runoff en cada riego, no le
   ofrece «Trasplante» y no le pregunta «¿se fertilizó?». Le pregunta lo que él hace:
   - «¿Le diste té?»
   - «Alimentar la cama» (top dress)
   - «Sembraste cobertura»
   - «Pusiste mulch»
2. **La cama es protagonista.** Tiene nombre («Cama A»), edad («14 meses, 4 ciclos»), estado
   (cocinando / lista / en uso / descansando) y su «qué viene»:
   - «Lista el 12-oct»
   - «Van 4 semanas del último top dress»
   - «Descansa hasta el 15-nov»
3. **La rotación sale sola.** Al cosechar lo último de la cama A, la app dice: «La cama A queda
   descansando. ¿Hasta cuándo? · La cama B está lista».
4. **Lo que gana con los registros:**
   - g/m² **ciclo por ciclo de la misma cama** (¿mi suelo mejora?);
   - la comparación cama contra cama;
   - suelo vivo contra lo que cultivaba antes;
   - el costo por gramo que baja ciclo a ciclo («tu cama ya se pagó»).
5. **Trazabilidad «qué comió esta flor».** Desde un lote o un frasco se ve:
   - la cama;
   - la mezcla con la que se armó;
   - todo lo que se le puso al suelo, con el insumo y la compra de la que salió;
   - los tés y los análisis de suelo.

   Si una harina viene contaminada, se sabe qué flores tocó.

Lo que **no** tiene que sentir: más formularios. Casi todo se hace desde el mismo «+» y los mismos
modales de siempre, que cambian según dónde está el lote.

## 3. El modelo

### 3.1 `Cama` (tabla `camas`) — nueva

| Campo | Qué es |
|---|---|
| `club_id`, `sala_id` (obligatoria) | Dónde está. La cama no se muda: se edita la sala sólo con la cama vacía. |
| `nombre` | «Cama A». Único por sala. |
| `largo_m`, `ancho_m`, `profundidad_cm` | Lo que el usuario sabe medir. Los **m²** y los **litros de suelo** se calculan (no se guardan dos veces). ❓D3 |
| `armada_el` | Fecha de armado. |
| `cocina_hasta` | Fecha en que la mezcla queda lista (armado + semanas de cocción). |
| `dias_descanso` | **Los días que descansa ESTA cama, los pone el usuario.** Sin valor por defecto nuestro (decisión de Germán, 25-sep: cada cultivador prueba lo suyo). Vacío = descansa hasta que diga «terminar descanso». |
| `semanas_coccion` | Ídem: las pone el usuario al armar; `cocina_hasta` se calcula. Vacío = lista cuando él diga. |
| `frecuencia_top_dress_dias` | Ídem, opcional (D11): sin número, no hay recordatorio. |
| `descansa_desde`, `descansa_hasta` | El descanso actual (nil si no descansa). `descansa_hasta` = desde + los días que se confirmaron ESA vez. |
| `mezcla` (jsonb) | **Copia** de la receta de armado, igual que la `nutricion` del riego: editar la receta después no cambia la historia. |
| `retirada_el` | La cama se desarmó. Queda con toda su historia para la trazabilidad. |
| `notas`, `deleted_at`, auditoría | Como el resto. `include Transmite` + `transmite_como 'camas'`, `acts_as_tenant`, `Auditable`. |

**El estado se calcula, no se guarda** (si una regla vive en dos lados, ya está mal). Se evalúa en
este orden y gana la primera que se cumple:

1. **retirada:** hay `retirada_el`.
2. **en uso:** tiene lotes en cultivo.
3. **cocinando:** `cocina_hasta` > hoy.
4. **descansando:** `descansa_hasta` > hoy.
5. **lista:** cualquier otro caso.

Viaja en el serializer y en `/me` junto con las demás reglas de cultivo.

### 3.2 `CamaCiclo` (tabla `cama_ciclos`) — nueva

Un ciclo de la cama va desde que se planta el primer lote hasta que sale el último. Tiene `cama_id`,
`numero` (1, 2, 3…), `desde` y `hasta`.

- Es lo que permite decir «ciclo 3 de la cama A: 480 g/m², ciclo 2: 410».
- El lote guarda `cama_ciclo_id`. Varios lotes del mismo ciclo comparten número.
- **Se abre** al plantar en una cama que no está en uso.
- **Se cierra** cuando la cama queda sin lotes en cultivo (cosecha, descarte o corrección). En ese
  momento arranca el descanso (§4.6).

### 3.3 Lote: `cama_id` + `cama_ciclo_id` — columnas nuevas

- **Si el lote tiene cama, la sala del lote es la de la cama.** Una sola fuente: no se puede
  editar la sala de un lote que está en una cama.
- **Al cosechar**, el lote suelta la sala (como hoy) pero **conserva `cama_id` y `cama_ciclo_id`**.
  Es historia, igual que los m² que se congelan al cosechar.
- **El tipo de cultivo sale de la cama.** Un lote en cama es «suelo vivo» y el selector «Tipo de
  cultivo» / «Sustrato» no aparece. Sin cama, todo sigue como hoy.
- `tamanio_maceta` queda **como historia** (la maceta que tuvo antes de ir a la cama), pero no se
  ofrece mientras está en la cama.

### 3.4 `CamaRegistro` (tabla `cama_registros`) — nueva

Todo lo que se le hace **al suelo**, haya o no lotes adentro:

| `tipo` | Qué guarda |
|---|---|
| `armado` | Mezcla base: receta de mezcla, litros de suelo, insumos descontados. |
| `top_dress` | Enmiendas en la superficie: receta o productos sueltos, dosis por m². |
| `te` | Té de compost o fermentado aplicado **al suelo sin riego** (el té con riego va en el riego, §4.3). |
| `cobertura` | Qué se sembró (trébol, alfalfa, mostaza…), fecha y, cuando se corta, «chop and drop». |
| `mulch` | Qué y cuánto. |
| `inoculacion` | Micorrizas, lombrices, colémbolos, IMO… |
| `recarga` | La recarga entre ciclos (el top dress grande del descanso). Puede ser un `top_dress` con marca; ❓D8. |
| `riego` | **Sólo cuando la cama no tiene lotes** (descanso con cobertura). Con lotes, el riego es del lote (§4.3). |
| `medicion` | Humedad y temperatura del suelo, a mano. |
| `nota` | Texto libre. |

Llevan `cama_ciclo_id` si ocurrieron durante un ciclo (nil en descanso o cocción). Los que usan
insumos descuentan igual que el riego: se reusa `Nutricion::Aplicar` generalizado, con copia de lo
aplicado y **nunca bloquea por stock**. `insumo_consumos` suma `cama_id` y `cama_registro_id`.

### 3.5 `AnalisisSuelo` (tabla `analisis_suelo`) — nueva

`analisis_laboratorio` es de la flor (`lote_id` obligatorio, THC/CBD/terpenos) y no sirve para el
suelo. Una tabla propia, con columnas para poder graficar la evolución:

- pH, CE, materia orgánica %, N, P, K, Ca, Mg, CIC, relación C/N;
- laboratorio, fecha y el PDF adjunto.

❓D9 (¿metales pesados en el suelo?).

### 3.6 Receta: para qué sirve y en qué unidad

Hoy `RecetaItem::UNIDADES = %w[ml_l g_l]` (por litro de agua). Se agregan:

- `Receta#uso`: `riego` (lo de hoy, incluye los tés con riego) · `top_dress` · `mezcla`.
- Unidades nuevas de `RecetaItem`:
  - `g_m2` y `ml_m2` para top dress;
  - `g_l_suelo` y `l_l_suelo` para la mezcla. Ejemplo: 3 g de kelp por litro de suelo, o 0,33 L
    de humus por litro de suelo, que es cómo se arma la «receta de 1/3».
- Cada uso admite sólo sus unidades. `Receta#calcular` recibe la base que corresponde: litros de
  agua, m² de la cama o litros de suelo.

Hoy la receta sólo tiene EC y pH objetivo, que no aplican a top dress ni a mezcla: se esconden según el uso.

## 4. Reglas nuevas

### 4.1 Coherencia de m² (lo que pidió Germán)

La cama tiene que entrar en la sala y el lote tiene que entrar en la cama.

- **Sala con m²:** la suma de los m² de sus camas **más** los m² de los lotes de esa sala que no
  están en cama tiene que dar ≤ m² de la sala.
  - Hoy `Sala#m2_ocupados_por_lotes` suma sólo lotes. Pasa a sumar camas + lotes sin cama.
  - Es la misma regla, extendida; **no** es una segunda regla.
- **Cama:** la suma de `m2_ocupados` de sus lotes en cultivo tiene que dar ≤ m² de la cama.
- **Cuándo bloquea:** igual que hoy con los m² de los lotes. Si la sala no tiene m² cargados, no
  bloquea nada y sólo se avisa que faltan. Cuando hay números, **la suma no puede pasar**: se
  bloquea con un mensaje claro («Las camas suman 3,2 m² y la carpa mide 2,88 m²»). ❓D2
- **Bajar los m² de una sala** por debajo de lo que suman sus camas: bloquea, con el mismo mensaje.
- **`m2_efectivos` del lote**, en este orden:
  1. los m² del lote, si se cargaron;
  2. si no, los de la **cama**, cuando es el único lote de la cama;
  3. si no, lo de hoy (los de la sala, cuando es el único lote de la sala).

  En uso personal nunca se cargan m² por lote, así que con una genética por cama el g/m² sale
  directo de la cama.

### 4.2 No hay trasplantes

- **«Plantar en la cama» reemplaza a «poner en maceta».** Hoy prender = ir a maceta
  (`Lote#maceta_al_prender`, `prender_al_ponerlo_en_maceta`). Pasa a ser **maceta O cama**:
  - un lote que enraíza en bandeja y se planta en la cama **prende**: pasa a vegetativo, arranca
    el reloj del ciclo y queda el evento «Prendió: se plantó en la cama A»;
  - **siembra directa en la cama** (muy común en suelo vivo): el lote nace con cama y en
    enraizado/germinación, sin maceta. Al avanzar a vegetativo **no pide maceta**.
- **Plantines en vasito que después van a la cama:** mientras están en vasito, el lote vive como
  hoy (con maceta). La acción «Plantar en la cama» es **el último trasplante**. Queda como evento
  `trasplante` con `destino: cama A`, para que la cronología no tenga un hueco.
- **Lote en cama, desde ahí en adelante:**
  - «Trasplante» desaparece del registro del lote (`RegistroLoteModal`), del de la planta
    (`RegistroPlantaModal`, `QuickActivity`) y del menú de acciones;
  - el backend lo rechaza (`Lotes::RegistrarTrasplante` y `plant_activities#create` con `transplant`);
  - en la tarea «Trasplante» de un plan de trabajo, ver §4.7.
- **Mover un lote de una cama a otra:** una planta en cama no se muda (tiene las raíces ahí). No se
  ofrece como «mover». Para corregir un error de carga se edita la cama en el lote, con
  auditoría. ❓D5
- **Desprender** (`Lotes::Desprender`): hoy separa por maceta. Con camas, sirve para que **una
  genética en dos camas** quede como dos lotes, uno por cama. El modal pide «cama» en vez de
  «maceta» cuando el origen está en una cama o va a una. ❓D4

### 4.3 Se alimenta el suelo, no el riego

Riego de un lote en cama (`RiegoForm`, que es el mismo en `RegistroLoteModal` y en `RegistroSalaModal`):

- Se ven: **volumen**, **agua** (declorada / de lluvia / de red) ❓D7 y **observaciones**.
- **pH entrada, pH runoff y EC se esconden.** No se borran de la tabla: un lote sin cama los
  sigue teniendo.
- «¿Se fertilizó?» pasa a ser **«¿Le diste té?»**, y el selector de receta muestra sólo las de uso
  `riego`. El descuento, el costo y la copia en el registro funcionan igual que hoy.
- «Método de aplicación» se esconde: con té al riego es suelo, y el foliar es su propio registro (abajo).
- **Foliar** (té foliar, aminoácidos, un fitosanitario biológico): sigue siendo del lote. Va por
  el registro de plagas/fitosanitario, que ya tiene producto, motivo y días de carencia. No
  cambia, y es lo más sensible del informe medicinal.

**Top dress, mulch, cobertura, inoculación, recarga y té al suelo sin riego** son de la **cama**
(`CamaRegistro`), no del lote:

- se ofrecen desde la cama, desde el lote («Alimentar la cama», que registra sobre la cama del
  lote) y desde el «+» del Hoy;
- **el costo** se reparte entre los lotes en cultivo de la cama en ese momento: por m² si los
  tienen, en partes iguales si no. Hoy `Insumo#registrar_consumo_repartido!` reparte sólo en
  partes iguales; se extiende sin cambiar lo de hoy.

**Regar la sala** (`RegistroSalaModal`): si la sala tiene camas, el formulario es el de suelo
vivo para los lotes en cama y el de siempre para los que no. ❓D6

### 4.4 La fase la cambia el espacio, no el lote

Un lote en cama no cambia de sala. Hoy `Lote#avanzar_fase!` **muda el lote** a la sala de
floración si hay una sola, y eso en una cama es físicamente imposible. Entonces:

- **Lote en cama, de vegetativo a floración:**
  - si la sala es `mixta`, el lote avanza solo, sin moverse, como la automática hoy;
  - si la sala es de vegetativo, el botón «Avanzar» del lote **lleva a «Cambiar la fase del
    espacio»** (`Salas::CambiarFase`), que ya pide confirmación con la lista de todos los lotes
    adentro. Es lo que pasa en la realidad: la luz es de la carpa, no del lote;
  - `avanzar_fase!` **nunca** auto-detecta otra sala para un lote en cama. El backend lo rechaza
    con un mensaje, aunque la pantalla no lo ofrezca.
- **Floración → vegetativo con lotes adentro** sigue siendo DESHACER, igual que hoy.
- **Enraizado en la cama** (siembra directa): la sala tiene que admitir enraizado (vegetativo o
  mixta). Es la regla de hoy y no cambia.
- **Automáticas en cama:** no cambia nada. Ya no cambian de sala.

### 4.5 La cosecha cierra el ciclo de la cama

- Cosechar (total o por tandas, `ModalCosechaPartial`) funciona igual que hoy.
- Cuando **el último lote en cultivo** sale de la cama:
  1. se cierra el `CamaCiclo`;
  2. la cama pasa a **descansando**;
  3. aparece un aviso que pregunta **cuántos días descansa**, precargado con los `dias_descanso`
     de la cama y editable para esta vez (o una fecha, o «sin fecha»). **La app no sugiere
     números propios**: ni «2 semanas» ni «un ciclo». Si la cama no tiene días cargados, el campo
     viene vacío y se puede dejar así;
  4. si en la misma sala hay otra cama **lista**, lo dice: «La cama B está lista».
- La tarea automática de cosecha «Limpiar y preparar sala post-cosecha» (`TareasAutoService`)
  cambia para un lote en cama por **«Cortar al ras y dejar las raíces; tapar con mulch»**. En
  suelo vivo, «limpiar» es justo lo que no se hace.

### 4.6 Descanso

- **Arranca solo** al cerrarse el ciclo. También se puede poner **a mano** una cama lista.
- **Los días los decide el cultivador, siempre** (Germán, 25-sep). Viven en la cama
  (`dias_descanso`), se cambian cuando quiera y cada descanso puede ser distinto: se
  alarga o se acorta en el medio editando la fecha de fin. Mismo criterio para la cocción
  y la frecuencia de top dress: **ningún número de cultivo lo pone la app**.
- **Termina** cuando se cumple `descansa_hasta` o cuando se toca «Terminar descanso». No hay un
  estado «vuelve a lista» para escribir: lo resuelve el cálculo (§3.1).
- **Plantar en una cama que descansa o cocina:** avisa y no bloquea. Mensajes: «La cama A descansa
  hasta el 15-nov (faltan 12 días). ¿Plantás igual?» y «La mezcla termina de cocinarse el 12-oct:
  plantar antes puede quemar las raíces». Plantar corta el descanso.
- **Durante el descanso** se registra todo lo del §3.4. El riego del descanso (la cobertura
  necesita agua) va como `CamaRegistro` de tipo `riego`: **no hay lote a quien cargárselo**.

### 4.7 Tareas automáticas y plan de trabajo

- `TareasAutoService::SUGERENCIAS` para un lote en cama:
  - vegetativo: «Medir EC y pH del sustrato» se reemplaza por «Revisar humedad del suelo y el mulch»;
  - cosecha: lo del §4.5.
- **Plan de trabajo** (plantillas, IA, CSV) aplicado a un lote en cama:
  - las tareas de tipo **trasplante** se saltean y la pantalla dice cuántas («2 trasplantes no
    aplican: el lote está en cama»);
  - las de **fertilización**, en vez de saltearse, se proponen como top dress o té. ❓D10
- El «qué viene» de la cama lo calcula el backend (`Cama#proximo_paso`), como `Lote#proximo_paso`:
  - «Lista el 12-oct» (cocinando);
  - «Descansa hasta el 15-nov»;
  - «Van N semanas del último top dress», si se cargó una frecuencia. ❓D11

### 4.8 Notificaciones

Entran al `Notificaciones::Catalogo`, dentro de «Recordatorios» (opt-in, prendido en personal):

- «La cama A terminó de cocinarse»;
- «La cama A terminó el descanso»;
- «Toca top dress en la cama A» (si D11 va).

Cada disparador lleva su `tipo:`.

## 5. Pantallas y modales: puerta por puerta

La lista está sacada del código; ninguna puerta queda sin revisar.

| Puerta | Hoy | Con suelo vivo |
|---|---|---|
| `ModalCrearSala` (escritorio y PWA) | Nombre, fase, m², sede | Sin cambios. Las camas se agregan desde la sala. |
| **Nuevo: modal de cama** (alta / edición) | — | Nombre, largo × ancho × profundidad (muestra m² y litros), fecha de armado, semanas de cocción, días de descanso, cada cuántos días top dress (los tres vacíos por defecto, los pone el usuario), **mezcla** (receta de mezcla: descuenta del depósito y queda la copia) o «ya estaba armada» (sin descuento, para la que viene de antes). Valida los m² contra la sala en vivo. |
| `SalaDetailView` / `MSalaMobileDetail` | Lotes y layout | **Sección «Camas»**: tarjeta por cama con estado, ciclo N, «qué viene», lotes adentro, m² libres; acciones: alimentar, té, cobertura, mulch, análisis, descansar/terminar descanso. |
| `NuevoLoteModal` | Sala, tipo de cultivo, maceta, m², luz | Con camas en la sala: **«¿En qué cama?»** (o «todavía no, en vasito»). Con cama elegida: sin «Tipo de cultivo» ni «Maceta», los m² se precargan con lo libre de la cama y se muestran los avisos de descanso/cocción. |
| `LoteEditarModal` | Tipo, maceta, m², luz… | Lote en cama: se ve la cama (editable sólo como corrección, D5), sin tipo ni maceta; la sala no se edita (es la de la cama). |
| `ModalCargarLote` / `ModalCrearLoteCosecha` | Cargar lote a sala / heredado | Mismo criterio que `NuevoLoteModal`. |
| Avanzar fase (`useLoteTransiciones`, `LoteDetailView`, `MLoteMobileDetail`) | Pide maceta al prender; muda de sala | Al prender pide **maceta o cama**; lote en cama no pide maceta. En cama con sala de vege, lleva a «Cambiar la fase del espacio» (§4.4). |
| `RegistroLoteModal` | Riego, poda, plagas, ambiental, luz, limpieza, trasplante | Lote en cama: **sin trasplante**, riego en versión suelo vivo, **+ «Alimentar la cama»** (abre el registro de cama). Ambiental suma humedad y temperatura del suelo (`temperatura_sustrato` ya existe). |
| `RegistroSalaModal` | Lo mismo por sala | Igual, según D6. |
| `RegistroPlantaModal`, `QuickActivity` | Trasplante por planta | Sin trasplante si la planta es de un lote en cama. |
| `DesprenderLoteModal` | Maceta del hijo | «Cama del hijo» si aplica (D4). |
| `TrasplanteForm` | — | No se muestra para lotes en cama; el backend rechaza. |
| `NutricionForm.vue` | **No lo importa nadie** (código muerto) | Borrarlo en el mismo bloque. |
| Recetas (escritorio y personal «Mis nutrientes») | Por litro, fase, pH/EC | **Para qué es**: riego · top dress · mezcla; unidades según eso; pH/EC sólo en riego. |
| «+» del Hoy (PWA) | Regar / Ambiente / Foto / Tarea | **+ «Alimentar la cama»** si el usuario tiene camas. Pide la cama si hay más de una, y la precarga si hay una sola en uso. Es acción del día: **tiene que estar en el teléfono**. |
| `LoteDetailView` / `MLoteMobileDetail` | Maceta, sustrato | Chip «Cama A · ciclo 3», link a la cama; «Alimentar la cama» en acciones. |
| **Nuevo: ficha de cama** | — | Edad, ciclos (tabla: fechas, lotes, genéticas, g/m²), cronología del suelo (todos los `CamaRegistro`), análisis de suelo (evolución), costo acumulado vs gramos acumulados. |
| `ResumenCiclo` («Cómo salió») | Del lote | + «Cama A · ciclo 3: 480 g/m² (ciclo 2: 410)». |
| Asistente IA (`asistente_controller`) y plan IA | Contexto con maceta | Contexto: «Suelo vivo en cama A, ciclo 3, último top dress hace 20 días. No corregir el pH del agua ni recomendar sales». |

Lo nuevo en el teléfono tiene que funcionar **sin señal**, como el registro del espacio (encolar
top dress y té). Dispensar sigue sin encolarse.

## 6. Trazabilidad e informes

- **`Lotes::Trazabilidad`** suma una sección **«Suelo»**:
  - la cama y el ciclo;
  - la mezcla de armado (copia);
  - todo lo aplicado al suelo, con el insumo y la compra;
  - los análisis de suelo.

  ¿Desde cuándo cuenta? Recomiendo **toda la historia de la cama hasta la cosecha del lote**,
  resaltando lo del ciclo. En no-till lo de hace dos ciclos sigue en el suelo. ❓D12
- **`Lotes::ResumenAplicaciones`**:
  - suma los `CamaRegistro` del ciclo del lote en «lo que se le puso»;
  - mantiene los fitosanitarios separados, como hoy.
- **Frasco → lote → cama:** la cadena ya existe hasta el lote, así que la cama llega sola.
- **«¿Qué flores tocó este insumo?»**, al revés: desde una compra de insumo, las camas y los lotes
  que la recibieron. Es la pregunta del recall. ❓D13 (pantalla nueva o sólo en el informe).
- **Analítica** (`Analitica::DondeYComo`):
  - «Método» suma **suelo vivo**, sale de la cama y no se tipea;
  - corte nuevo **«Cama»**, en g/m² además de g/planta;
  - en la ficha de cama, la serie **g/m² por ciclo**.
- **Costos:** el lote carga lo aplicado durante su ciclo más la recarga del descanso anterior. El
  **armado no se le carga a ningún lote**: queda como inversión de la cama. La ficha muestra
  «invertido total ÷ gramos cosechados en la cama», un número que baja ciclo a ciclo y no inventa
  una vida útil. ❓D1
- **Informes regulatorios** (REPROCANN, INASE, semestral): no cambian. Suelo vivo es cómo se
  cultiva, no qué se declara. En personal no hay nada regulatorio.

## 7. Bloques, en orden

Cada bloque cierra con rspec + vitest verdes en lo tocado y **Playwright sobre la pantalla**. Cada
modelo nuevo lleva `Transmite` y un test de aislamiento de tenant. Las pantallas llevan `useRecargaEnCambios`.

1. **Camas y m².** Modelo `Cama` (sin registros todavía), la regla de m² extendida, el modal de
   cama, la sección «Camas» en la sala (escritorio + PWA) y los datos de prueba en `casa_german`
   (dos camas, A y B). *Migración.*
2. **Lote en cama.** `cama_id`/`cama_ciclo_id`, `CamaCiclo`, plantar en la cama (prender), siembra
   directa, `NuevoLoteModal`/`LoteEditarModal`/`ModalCargarLote`, fuera trasplante (UI + backend),
   avanzar fase (§4.4), desprender (D4). *Migración.* Specs de integración de fases de lote.
3. **Recetas por uso + registros de cama.** `Receta#uso`, unidades nuevas, `CamaRegistro`,
   `Nutricion::Aplicar` generalizado, reparto por m², el riego en versión suelo vivo, «Alimentar
   la cama» en el «+» y en el lote, y borrar `NutricionForm.vue`. *Migración.*
4. **Descanso y rotación.** Cierre de ciclo al cosechar, el aviso de «hasta cuándo», el aviso al
   plantar, `Cama#proximo_paso`, tareas automáticas (§4.7), plan de trabajo y notificaciones del
   catálogo.
5. **Trazabilidad, analítica y costos.** Sección «Suelo», `ResumenAplicaciones`, corte «Cama»,
   g/m² por ciclo, `ResumenCiclo`, costo de la cama y análisis de suelo (tabla + carga + gráfico).
   *Migración.*
6. **IA y repaso por rol.** Contexto del asistente y del plan IA, y un repaso completo en personal
   y en una organización con cultivador (Playwright de punta a punta: armar la cama, plantar,
   alimentar, florar el espacio, cosechar, descansar, plantar en la otra).

Los bloques 1 y 2 juntos ya dan valor (camas visibles, g/m² por cama, sin trasplante). Con el 3,
la precisión de lo que se aplica. Con el 4, la rotación. Con el 5, lo que se vende.

## 8. Dudas para Germán — CONTESTADAS 25-sep: van todas las recomendaciones

> Además: los días de descanso los pone el usuario por cama, sin número nuestro (§4.6).

- **D1 · Costo del armado.** ¿Queda como inversión de la cama, sin cargarse a lotes, con el
  «costo por gramo acumulado» en la ficha? *Recomiendo que sí.* La alternativa es repartirlo en N
  ciclos estimados, pero ese N sería un número inventado.
- **D2 · ¿Los m² bloquean?** Hoy la suma de lotes no puede pasar la sala. Con camas, ¿se mantiene
  el bloqueo cuando hay números? *Recomiendo que sí.* Sin m² cargados no bloquea nada.
- **D3 · Medidas de la cama.** ¿Largo × ancho × profundidad (y los m² y litros se calculan), o m²
  y litros directo? *Recomiendo las medidas*: es lo que el usuario sabe, y los litros de suelo
  hacen falta para la receta de mezcla.
- **D4 · Una genética en dos camas.** ¿Dos lotes (desprender) o un lote con plantas en dos camas?
  *Recomiendo dos lotes*: la cama es del lote y la trazabilidad queda limpia. El costo es que
  «Plantar en la cama» tiene que dejar repartir un lote enraizando entre camas (desprende solo).
- **D5 · Corregir la cama de un lote.** ¿Se permite editarla como corrección, con auditoría? *Sí,
  sólo mientras está en cultivo y sin registros de cama en su ciclo*; si ya los tiene, pasarían al
  otro lado mal atribuidos.
- **D6 · Regar el espacio entero con camas y macetas mezcladas.** ¿Un solo formulario que se
  adapta por lote, o se riega por cama? *Recomiendo por cama* cuando la sala tiene camas («Regar
  la cama A»), porque es el gesto real.
- **D7 · Tipo de agua.** ¿Vale la pena registrar el agua (de red, declorada, de lluvia,
  ósmosis)? En suelo vivo importa (el cloro mata la vida). *Recomiendo un campo opcional* que
  recuerde la última elección.
- **D8 · Recarga.** ¿Es su propio tipo o un top dress con marca «recarga»? *Recomiendo top dress +
  marca*: es el mismo gesto, y la marca sirve para el costo del próximo ciclo.
- **D9 · Análisis de suelo con metales pesados.** ¿Se incluyen? Y en la flor, hoy
  `analisis_laboratorio` sólo tiene cannabinoides: ¿agregar **microbiológico y metales pesados**?
  Con suelo vivo es el riesgo real para uso medicinal. *Recomiendo el de la flor como bloque
  aparte*, no dentro de este.
- **D10 · Plan de trabajo con fertilización.** Cuando se aplica a un lote en cama, ¿se proponen
  como top dress o se saltean? *Recomiendo saltear con aviso* y que el usuario arme su plan de suelo vivo.
- **D11 · Frecuencia de top dress.** ¿Se carga por cama para el recordatorio («cada 4 semanas»)?
  *Recomiendo que sí, opcional*: sin frecuencia no hay recordatorio.
- **D12 · Alcance de «qué comió esta flor».** ¿Toda la historia de la cama o sólo el ciclo?
  *Recomiendo toda la historia, con lo del ciclo resaltado.*
- **D13 · Recall por insumo.** ¿Pantalla propia («esta compra de harina, ¿dónde terminó?») o sólo
  en el informe? *Recomiendo dejarla para después del bloque 5*: los datos ya van a estar.
- **D14 · ¿Toda cama es suelo vivo?** ¿Puede haber camas de tierra común con sales? *Recomiendo
  que por ahora cama = suelo vivo.* Si aparece el otro caso, se agrega un «manejo» a la cama sin
  romper nada.
- **D15 · Comercial.** ¿Entra en la suite Cultivo para todos, o es un add-on? *Recomiendo que
  entre en Cultivo*: es una forma de cultivar, no un módulo.
- **D16 · Vocabulario en pantalla.** ¿«Top dress» o «Alimentar la cama»? *Recomiendo «Alimentar la
  cama (top dress)»* en el botón y «top dress» en el historial, que es cómo se dice acá.

## 9. Lo que NO cambia

- Lotes sin cama: todo igual (macetas, trasplantes, pH/EC, fertilización en el riego).
- Stock, dispensación, informes regulatorios, manicura, curado.
- Las reglas de fases (sala ⇔ estado, deshacer floración, automáticas), que se reusan tal cual.
