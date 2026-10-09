// LO QUE DICEN LAS PÁGINAS PÚBLICAS, por público (5-oct-2026: Germán y Javi pidieron que quien
// entra por «Autocultivo» o por «Organizaciones» vea lo suyo y no todo). Desde el 9-oct lo que
// hace cada página vive en sus filas (`Fortaleza`, `RecorridoFases`); acá quedan las preguntas y
// los packs.
//
// Regla para editar (vale también para esas filas): lo que se afirma tiene que existir HOY en la
// app. Lo que se vende aparte (`Club::ADDONS` con `tipo: 'extra'`, como Ambiente/IoT) no se
// muestra como incluido. Delivery, correo, módulo médico y la IA vienen INCLUIDOS desde el modelo
// comercial del 6-oct-2026. No se nombra lo que
// está simulado (ARICCAME), lo que está en prueba (el chatbot) ni lo que está en construcción (el
// portal del paciente, Germán 5-oct). Lo que depende de una persona y
// no de la app (importar datos al arrancar, exportarlos al irse, activar después de la prueba) se
// dice así: lo hacemos nosotros.

// ── AUTOCULTIVO ──────────────────────────────────────────────────────────────────────────────────
// Vocabulario de usuario final (como en el uso personal de la app): espacio, nutrientes, próximos
// pasos. Sin pacientes, sedes ni caja.
export const PREGUNTAS_AUTOCULTIVO = [
  { q: '¿Qué pasa cuando termina la prueba gratis?',
    r: 'No se cobra nada solo: no te pedimos tarjeta. Si querés seguir, nos escribís y la activamos. Si no, la cuenta queda en pausa y no se borra nada de lo que cargaste.' },
  { q: '¿Sirve para automáticas y para fotoperiódicas?',
    r: 'Sí. Marcás la genética como automática y la app la cuenta de semilla a cosecha, sin pedirte el cambio a floración. Las fotoperiódicas pasan por vegetativo y floración como siempre.' },
  { q: '¿Tengo que instalar algo?',
    r: 'No hace falta una tienda de apps: se instala desde el navegador del teléfono en unos segundos y queda como una app más. También la podés usar desde la compu.' },
  { q: '¿Anda sin señal?',
    r: 'La app abre igual. Los registros del espacio, las lecturas de ambiente y los pesajes se guardan en el teléfono y se mandan solos cuando vuelve la señal.' },
  { q: '¿Quién ve mis datos?',
    r: 'Sólo vos. No los vendemos ni los usamos para publicidad. Están en servidores en la nube (algunos fuera de la Argentina), con copias de seguridad.' },
  { q: '¿Me sirve para el REPROCANN?',
    r: 'Cultivo Espacial no tramita el REPROCANN ni autoriza a cultivar: eso lo dan la ley y el registro. Lo que te da es tu cultivo registrado y ordenado, planta por planta.' },
  { q: '¿Me puedo dar de baja?',
    r: 'Cuando quieras, sin explicar nada. Y si contrataste hace menos de 10 días, tenés el botón de arrepentimiento al pie de la página.' },
]

// ── ORGANIZACIONES ───────────────────────────────────────────────────────────────────────────
// Asociaciones, fundaciones, investigación y producción. En pantalla «organización» desde el
// 9-oct-2026 (antes «proyecto»); los identificadores siguen diciendo «proyectos». Una organización
// NO dice «frasco» (Germán, 5-oct): es stock, unidades. «Frasco» es vocabulario de casa.
export const PREGUNTAS_PROYECTOS = [
  { q: '¿Cuánto tarda arrancar?',
    r: 'Armamos la cuenta con ustedes: la organización, las sedes, quién hace qué y lo que contratan. Cuando está lista, cada persona entra con su usuario y ve lo suyo.' },
  { q: 'Tenemos todo en planillas, ¿hay que cargarlo de nuevo?',
    r: 'No. Nos pasan el padrón de pacientes, las genéticas o el stock como los tengan, y los importamos nosotros.' },
  { q: '¿Sirve si tenemos varias sedes? ¿Y si sólo dispensamos?',
    r: 'Sí a las dos. Cada sede tiene su stock y su caja. Se contrata por packs: Cultivo, Producción y dispensa, o los dos. El delivery, el correo, el módulo médico y el asistente IA vienen adentro.' },
  { q: '¿El consultorio y el turnero se pagan aparte?',
    r: 'No: el módulo médico viene con Producción y dispensa. Cada médico carga su horario, la administración da los turnos sobre esa agenda y la historia clínica vive en la misma ficha del paciente.' },
  { q: '¿Cada persona ve sólo lo suyo?',
    r: 'Sí. Hay una vista por oficio: cultivo, manicura, mostrador, médico, delivery y administración. Quien atiende el mostrador, por ejemplo, no ve la contabilidad.' },
  { q: '¿Qué informes salen?',
    r: 'REPROCANN, INASE, producción, inventario, pérdidas y dispensaciones, en PDF y CSV. Salen de lo que se carga operando: no hay que armar nada aparte el día que se los piden.' },
  { q: '¿Qué pasa si se corta internet en el mostrador?',
    r: 'Sin señal no se dispensa, a propósito: así el stock y la caja nunca quedan distintos entre dos teléfonos. La manicura y los registros de las salas sí siguen y se sincronizan al volver.' },
  { q: '¿Dónde están los datos y quién los ve?',
    r: 'En servidores en la nube, con copias de seguridad verificadas. Cada organización está aislada de las demás y sus datos no se venden ni se comparten.' },
  { q: 'Si un día nos vamos, ¿nos llevamos los datos?',
    r: 'Sí. Nos lo piden y les armamos la exportación completa de lo que cargaron.' },
  { q: '¿Cuánto sale?',
    r: 'Se paga por tamaño: un pack o los dos, según cuántos pacientes y plantas en floración tengan. Los precios están en esta misma página; si su caso no entra en ninguno, escribinos.' },
]

// ── PACKS CON PRECIO ─────────────────────────────────────────────────────────────────────────
// Los NÚMEROS salen del backend (`GET /public/registro` → `precios`, armado por `Precios` y
// `PlanEnforcer::PLANES`): acá sólo se escriben las palabras. Sin `precios` (el backend no
// contestó) devuelven [] y la sección no se muestra. Cada pack para `Packs.vue`:
// { nombre, precio, periodo, para, incluye: [], destacado, accion }
const plata = (n, moneda) => (moneda === 'USD' ? `US$ ${n}` : `$ ${n}`)
const INCLUIDO_ORG = 'Delivery, correo, módulo médico y asistente IA incluidos'

export function packsAutocultivo(precios) {
  if (!precios?.autocultivo) return []
  const a = precios.autocultivo
  return [{
    nombre: 'Autocultivo',
    precio: plata(a.precio, precios.moneda),
    periodo: 'por mes',
    incluye: [
      `Hasta ${a.plantas_floracion} plantas en floración; el vegetativo, libre`,
      `${a.espacios} espacios de cultivo: carpas, balcón o camas`,
      'Registro por voz con el asistente IA',
      'Riegos, nutrientes, fotos, cosecha y frascos',
      'Tus informes en PDF y Excel',
    ],
    destacado: true,
  }]
}

export function packsProyectos(precios) {
  if (!precios?.escalones?.length) return []
  const m = precios.moneda
  const usuarios = (e) => `${e.usuarios_por_rol} usuarios de cada rol${e.por_sede ? ' en cada sede' : ''}`
  const packs = precios.escalones.map((e, i) => ({
    nombre: e.label,
    precio: plata(e.dos_packs, m),
    periodo: 'por mes, los dos packs',
    para: `Cultivo o Producción y dispensa por separado: ${plata(e.un_pack, m)} cada uno.`,
    incluye: [
      `${e.plantas_floracion} plantas en floración; el vegetativo, libre`,
      e.salas == null ? 'Salas y lotes sin límite' : `${e.salas} salas y lotes sin límite`,
      `${e.sedes} ${e.sedes === 1 ? 'sede' : 'sedes'} · ${usuarios(e)}`,
      INCLUIDO_ORG,
    ],
    destacado: i === precios.escalones.length - 1,
  }))
  const pp = precios.pack_pacientes
  packs.push({
    nombre: 'Para crecer',
    precio: plata(pp.precio, m),
    periodo: `cada ${pp.pacientes} pacientes más`,
    para: `${plata(pp.por_paciente, m)} por paciente, de a ${pp.pacientes}: con 53 pacientes no hace falta pasar al escalón siguiente.`,
    incluye: [
      `Cada pack suma ${pp.pacientes} pacientes y ${pp.plantas_floracion} plantas en floración`,
      `Sede extra: ${plata(precios.sede_extra, m)} por mes`,
    ],
  })
  return packs
}
