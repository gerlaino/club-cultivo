// LO QUE DICEN LAS PÁGINAS PÚBLICAS, por público (5-oct-2026: Germán y Javi pidieron que quien
// entra por «Autocultivo» o por «Proyectos» vea lo suyo y no todo).
//
// Regla para editar: lo que se afirma acá tiene que existir HOY en la app. Lo que se vende aparte
// (`Club::ADDONS`: delivery, IoT, IA) lleva `addon: true` («Se suma aparte»). No se nombra lo que
// está simulado (ARICCAME), lo que está en prueba (el chatbot) ni lo que está en construcción (el
// portal del paciente, Germán 5-oct). Lo que depende de una persona y
// no de la app (importar datos al arrancar, exportarlos al irse, activar después de la prueba) se
// dice así: lo hacemos nosotros.
import MuestraCadena from './muestras/MuestraCadena.vue'
import MuestraCiclo from './muestras/MuestraCiclo.vue'
import MuestraPesadas from './muestras/MuestraPesadas.vue'
import MuestraTicket from './muestras/MuestraTicket.vue'
import MuestraDelivery from './muestras/MuestraDelivery.vue'
import MuestraAmbiente from './muestras/MuestraAmbiente.vue'
import MuestraIa from './muestras/MuestraIa.vue'
import MuestraInforme from './muestras/MuestraInforme.vue'
import MuestraRendimiento from './muestras/MuestraRendimiento.vue'
import MuestraCosto from './muestras/MuestraCosto.vue'

// ── AUTOCULTIVO ──────────────────────────────────────────────────────────────────────────────────
// Vocabulario de usuario final (como en el uso personal de la app): espacio, nutrientes, próximos
// pasos. Sin pacientes, sedes ni caja.
export const TEMAS_AUTOCULTIVO = [
  {
    id: 'cultivo', label: 'Tu cultivo', muestra: MuestraCiclo,
    titulo: 'Cada planta, con su diario',
    texto: 'Tu espacio, tus lotes y cada planta, desde la semilla o el esqueje. Lo que hacés queda anotado y la app te avisa lo que viene.',
    puntos: [
      'Autos o fotoperiódicas: cada una con su reloj',
      'Riegos, nutrientes con su dosis, pH/EC y fotos por semana',
      'Los próximos pasos del ciclo, con aviso al teléfono',
      'Suelo vivo: la cama vive más que las plantas',
    ],
  },
  {
    id: 'cosecha', label: 'Cosecha y frascos', muestra: MuestraPesadas, muestraProps: { casa: true },
    titulo: 'Del secado al frasco',
    texto: 'Pesás al cosechar, al secar y al curar: la app calcula cuánto se fue en cada etapa y te deja los frascos anotados.',
    puntos: [
      'Húmedo, seco y curado, con la merma de cada etapa',
      'Cada frasco sabe de qué cosecha y de qué planta salió',
      'Las fotos de cada cosecha, para comparar la próxima',
    ],
  },
  {
    id: 'ambiente', label: 'Ambiente', addon: true, muestra: MuestraAmbiente, muestraProps: { espacio: 'Carpa' },
    titulo: 'Tu carpa, a la vista',
    texto: 'Temperatura, humedad y VPD, desde un sensor o desde la planilla de tu datalogger, con aviso cuando algo se sale del rango.',
    puntos: [
      'Sensores conectados (Sonoff u otros) o carga por CSV',
      'VPD calculado con la fase de tus plantas',
      'Aviso al teléfono cuando se sale del rango',
      'Sin sensor, lo anotás a mano desde el teléfono',
    ],
  },
  {
    id: 'ia', label: 'Asistente IA', addon: true, muestra: MuestraIa,
    titulo: 'Contalo y queda anotado',
    texto: 'Con las manos en la tierra, decís lo que hiciste y el asistente lo convierte en registros. Vos confirmás antes de que se guarde.',
    puntos: [
      'Registro por voz de tu espacio, tus lotes y tus plantas',
      'Propone; nada se guarda sin tu confirmación',
      'Lee la planilla del datalogger por vos',
    ],
  },
  {
    id: 'numeros', label: 'Tus números', muestra: MuestraCosto,
    titulo: 'Cuánto te costó cada gramo',
    texto: 'Anotás lo que gastás —semillas, sustrato, nutrientes, luz— y al cosechar la app lo divide por lo que rindió.',
    puntos: [
      'Tus gastos, por categoría',
      'El costo por gramo de cada cosecha',
      'Lo que llevás gastado en el ciclo, a la vista',
    ],
  },
]

export const PREGUNTAS_AUTOCULTIVO = [
  { q: '¿Qué pasa cuando termina la prueba gratis?',
    r: 'No se cobra nada solo: no te pedimos tarjeta. Si querés seguir, nos escribís y la activamos. Si no, la cuenta queda en pausa y no se borra nada de lo que cargaste.' },
  { q: '¿Sirve para automáticas y para fotoperiódicas?',
    r: 'Sí. Marcás la genética como automática y la app la cuenta de semilla a cosecha, sin pedirte el cambio a floración. Las fotoperiódicas siguen su ciclo de vege y flora.' },
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

// ── PROYECTOS ────────────────────────────────────────────────────────────────────────────────
// Asociaciones, fundaciones, investigación y producción. En pantalla «proyecto»; adentro de la
// app la entidad sigue siendo «organización». Un proyecto NO dice «frasco» (Germán, 5-oct): es
// stock, unidades. «Frasco» es vocabulario de casa.
export const TEMAS_PROYECTOS = [
  {
    id: 'trazabilidad', label: 'Trazabilidad', muestra: MuestraCadena,
    titulo: 'Cada gramo sabe de dónde viene',
    texto: 'La genética, el lote, la planta, la cosecha, el stock y la entrega quedan unidos. Desde cualquier punta llegás a la otra en un toque.',
    puntos: [
      'Cada planta con su QR y su historia completa',
      'Cada unidad del stock sabe de qué cosecha y de qué plantas salió',
      'El paciente escanea el QR de su retiro y ve la genética que se llevó',
      'Lo trazable sólo sale del inventario con una entrega: lo que falta, se ve',
    ],
  },
  {
    id: 'cultivo', label: 'Cultivo', muestra: MuestraRendimiento,
    titulo: 'El ciclo, medido',
    texto: 'Lotes y plantas en sus salas, de la semilla o el esqueje a la cosecha, con los próximos pasos del ciclo avisados al teléfono.',
    puntos: [
      'Fases por sala; autos que se quedan en vege todo el ciclo',
      'Riegos, nutrientes con su dosis, pH/EC y fotos por semana',
      'Tareas del día para cada cultivador, armadas según la fase',
      'Rendimiento en g/m² por cosecha, por genética y por sala',
    ],
  },
  {
    id: 'cosecha', label: 'Cosecha y stock', muestra: MuestraPesadas,
    titulo: 'El peso que entra y el que sale',
    texto: 'Secado y curado con sus pesadas, la manicura con aprobación, y el stock por sede y por depósito con cada movimiento a la vista.',
    puntos: [
      'Húmedo, seco y curado: la merma de cada etapa, calculada',
      'Manicura que carga aun sin señal y espera aprobación',
      'Stock por sede y por depósito, con transferencias',
      'Contar no crea stock: una diferencia queda como diferencia',
    ],
  },
  {
    id: 'mostrador', label: 'Mostrador y caja', muestra: MuestraTicket,
    titulo: 'Dispensar y que la caja cierre',
    texto: 'El mostrador entrega lo que está sobre la mesa y cobra como pague cada paciente. Quien atiende abre contando y cierra sin esperar a nadie.',
    puntos: [
      'Varios productos en una dispensa, varios medios de pago',
      'Cuenta corriente: lo pagado de más se descuenta solo en la próxima',
      'Reservas, anulación con motivo y cierre de caja firmado',
      'El REPROCANN de cada paciente a la vista, con aviso antes de que venza',
    ],
  },
  {
    id: 'delivery', label: 'Delivery', addon: true, muestra: MuestraDelivery,
    titulo: 'Hasta la puerta del paciente',
    texto: 'Paquetes armados desde el stock, rutas para quien reparte y la entrega confirmada con firma en el teléfono.',
    puntos: [
      'Rutas del día en el teléfono de quien reparte',
      'Firma de entrega y cobro contra entrega',
      'Lo que no se entregó vuelve al stock, desarmado',
      'Rendición del efectivo dirigida a una persona',
    ],
  },
  {
    id: 'ambiente', label: 'Ambiente e IoT', addon: true, muestra: MuestraAmbiente,
    titulo: 'Cada sala, a la vista',
    texto: 'Temperatura, humedad y VPD de cada sala, desde sensores o desde la planilla de un datalogger, con aviso cuando algo se sale del rango.',
    puntos: [
      'Sensores conectados (Sonoff u otros) o carga por CSV',
      'VPD calculado con la fase del lote',
      'Rangos por sala y aviso al teléfono',
      'Lectura a mano desde el teléfono cuando no hay sensor',
    ],
  },
  {
    id: 'ia', label: 'Asistente IA', addon: true, muestra: MuestraIa,
    titulo: 'Contalo y queda anotado',
    texto: 'El cultivador dice lo que hizo y el asistente lo convierte en registros. Nada se guarda sin que lo confirme.',
    puntos: [
      'Registro por voz de salas, lotes y plantas',
      'Propone; nada se guarda sin confirmación',
      'Arma el plan de trabajo de la semana',
      'Lee la planilla del datalogger',
    ],
  },
  {
    id: 'informes', label: 'Informes y números', muestra: MuestraInforme,
    titulo: 'Lo que pide la normativa, de lo que ya cargaron',
    texto: 'Los informes salen de la misma data que se carga operando. Nada se arma aparte el día que te lo piden.',
    puntos: [
      'REPROCANN, INASE, producción, inventario y pérdidas',
      'Siempre se descargan; «para presentar» además valida',
      'Costo por lote y costo por gramo',
      'PDF y CSV, del mismo período que ves en pantalla',
    ],
  },
]

// Una vista por oficio: lo que ve cada rol al entrar (`User#role`). Médico y delivery dependen de
// lo contratado (el módulo médico viene con Producción y dispensa; delivery es add-on).
export const OFICIOS = [
  { quien: 'Cultivo',        que: 'Sus salas, sus lotes y las tareas del día. Riega, registra y saca fotos desde el teléfono, al lado de la planta.' },
  { quien: 'Manicura',       que: 'Las plantas a pesar y lo que entra al stock. Carga aun sin señal; lo que pesa espera la aprobación de administración.' },
  { quien: 'Mostrador',      que: 'La mesa, el carrito y su caja. Dispensa lo que está sobre la mesa y cierra su caja; no ve la contabilidad.' },
  { quien: 'Médico',         que: 'Su agenda y su horario, la historia clínica de cada paciente, sus indicaciones y las prescripciones en PDF.' },
  { quien: 'Delivery',       que: 'Su ruta del día, los paquetes, la firma de entrega y la rendición del efectivo.' },
  { quien: 'Administración', que: 'Todo: pacientes, stock, caja, contabilidad, informes y quién hace qué.' },
]

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
      `${a.espacios} espacios de cultivo y lotes sin límite`,
      'Registro por voz con el asistente IA',
      'Riegos, nutrientes, fotos, cosecha y frascos',
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
