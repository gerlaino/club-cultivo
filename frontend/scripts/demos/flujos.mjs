// LOS FLUJOS DE «MIRÁ CÓMO SE HACE». Cada uno: dónde arranca, con qué usuario y qué se hace,
// marcando cada paso (`paso('…')`) en el momento en que empieza. Los datos son del club demo y
// los deja listos `rake demo:preparar_tomas`. El orden importa: el lote usa la genética que se
// crea antes.
import { AUTOCULTIVO } from './base-autocultivo.mjs'

const ADMIN = 'admin@asociacion-ejemplo.example.com'

export const FLUJOS = [
  // ── Administración, en la compu ──────────────────────────────────────────────────────────
  {
    id: 'genetica-compu', vista: 'compu', usuario: ADMIN, ruta: '/geneticas',
    titulo: 'Una genética nueva', quien: 'En la compu, desde Cultivo › Genéticas.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Tocás «Nueva genética»')
      await tocar(p.locator('button', { hasText: /Nueva gen/ }).first()); await pausa(1000)
      paso('Le ponés nombre y tipo')
      const campo = (txt) => p.locator('.gem-form__label', { hasText: txt }).locator('xpath=following::input[1]')
      await escribir(campo('Nombre'), 'Gelato 41'); await pausa(300)
      await tocar(p.locator('.gem-form__tipo-btn', { hasText: 'Híbrida' })); await pausa(400)
      await escribir(campo('THC'), '22'); await escribir(campo('CBD'), '0.5'); await pausa(300)
      paso('Cuánto dura cada fase')
      await escribir(campo('Vegetativo'), '28'); await escribir(campo('Floración'), '63'); await pausa(300)
      await escribir(campo('Criador'), 'Banco Andino'); await pausa(500)
      paso('La guardás y ya se puede plantar')
      await tocar(p.locator('.gem-btn-new', { hasText: 'Crear genética' })); await pausa(2600)
    },
  },
  {
    id: 'lote-compu', vista: 'compu', usuario: ADMIN, ruta: '/lotes',
    titulo: 'Un lote nuevo', quien: 'En la compu, desde Cultivo › Lotes.',
    async hacer ({ p, paso, tocar, escribir, elegir, pausa }) {
      paso('Tocás «Crear lote»')
      await tocar(p.locator('.lv__btn-primary', { hasText: 'Crear lote' })); await pausa(1100)
      paso('Elegís la sala: el código sale solo')
      const campo = (txt, tipo = 'select') => p.locator('.nlm__label', { hasText: txt }).locator(`xpath=following::${tipo}[1]`)
      await elegir(campo('Sala'), 'Vegetativo'); await pausa(900)
      paso('Cuántas plantas y de qué genética')
      await tocar(p.locator('.nlm__pill', { hasText: 'Semilla' })); await pausa(300)
      await escribir(campo('Cantidad de plantas', 'input'), '12', { deUna: true }); await pausa(400)
      await elegir(campo('Genética'), 'Gelato 41'); await pausa(400)
      await elegir(campo('Tipo de luz'), 'LED'); await pausa(600)
      paso('Lo creás, con sus plantas y su QR')
      await tocar(p.locator('.nlm__btn-primary', { hasText: 'Crear lote' })); await pausa(3000)
    },
  },
  {
    id: 'paciente-compu', vista: 'compu', usuario: ADMIN, ruta: '/pacientes',
    titulo: 'Un paciente nuevo', quien: 'En la compu, desde Pacientes.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Tocás «Nuevo paciente»')
      await tocar(p.locator('button, a', { hasText: 'Nuevo paciente' }).first()); await pausa(1300)
      paso('Sus datos')
      const campo = (txt) => p.locator('.snv__label', { hasText: txt }).first().locator('xpath=following::input[1]')
      await escribir(campo('Nombre'), 'Lucía'); await escribir(campo('Apellido'), 'Benedetti')
      await escribir(campo('DNI'), '38512904', { deUna: true }); await pausa(200)
      await escribir(campo('Fecha de nacimiento'), '14/03/1991'); await pausa(200)
      await escribir(campo('Teléfono'), '+54 9 11 4567-1203', { deUna: true })
      await escribir(campo('Email'), 'lucia.benedetti@example.com', { deUna: true }); await pausa(400)
      paso('Su REPROCANN, con el vencimiento')
      await tocar(p.locator('.snv__repro-btn', { hasText: 'Vigente' })); await pausa(400)
      await escribir(campo('Número de certificado'), 'RC-2026-48213', { deUna: true })
      await escribir(campo('Fecha de vencimiento'), '15/06/2027'); await pausa(600)
      paso('Lo creás: ya se le puede dispensar')
      await tocar(p.locator('.snv__btn-primary', { hasText: 'Crear paciente' })); await pausa(1100)
      // El aviso con su acceso al portal; en local dice que el mail no salió: se cierra rápido.
      const listo = p.getByRole('button', { name: 'Listo', exact: true })
      if (await listo.isVisible().catch(() => false)) { await tocar(listo) }
      await pausa(2400)
    },
  },
  {
    id: 'dispensa-compu', vista: 'compu', usuario: ADMIN, ruta: '/pacientes',
    titulo: 'Una dispensa', quien: 'En la compu, desde la ficha del paciente.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Buscás al paciente')
      await escribir(p.locator('input[placeholder^="Buscar por nombre"]'), 'Ríos'); await pausa(800)
      await tocar(p.locator('tbody tr', { hasText: 'Martina' }).first()); await pausa(1500)
      paso('Abrís una dispensa desde su ficha')
      await tocar(p.getByRole('button', { name: /Dispensaciones/ }).first()); await pausa(800)
      await tocar(p.getByRole('button', { name: /Nueva dispensaci/ }).first()); await pausa(1300)
      paso('Elegís qué se lleva, del stock')
      await escribir(p.locator('.mnd__modal input[placeholder^="Buscar"]'), 'Amnesia'); await pausa(600)
      await tocar(p.locator('.mnd__radio').first()); await pausa(400)
      await escribir(p.locator('.mnd__modal .mnd__input:visible').first(), '5', { deUna: true }); await pausa(300)
      await tocar(p.locator('.mnd__add-item')); await pausa(1300)
      paso('El total sale solo: no se tipea')
      await tocar(p.locator('.mnd__btn-primary')); await pausa(2000)
      paso('Cobrás como pague')
      await tocar(p.locator('.mnd__btn-primary')); await pausa(900)
      await escribir(p.locator('.mnd__modal label', { hasText: 'Paga con' }).locator('xpath=following::input[1]'), '20000', { deUna: true }); await pausa(1700)
      paso('Confirmás, y el resto le queda a favor')
      await tocar(p.locator('.mnd__btn-primary')); await pausa(2000)
      await tocar(p.getByRole('button', { name: 'Confirmar', exact: true })); await pausa(2800)
    },
  },

  // ── Administración, en el teléfono ───────────────────────────────────────────────────────
  {
    id: 'genetica-telefono', vista: 'telefono', usuario: ADMIN, ruta: '/m/geneticas',
    titulo: 'Una genética nueva', quien: 'En el teléfono, desde Más › Genéticas.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Tocás «Nueva genética»')
      await tocar(p.locator('button', { hasText: /Nueva gen/ }).first()); await pausa(1000)
      paso('Le ponés nombre y tipo')
      const campo = (txt) => p.locator('.gem-form__label', { hasText: txt }).locator('xpath=following::input[1]')
      await escribir(campo('Nombre'), 'Gelato 41'); await pausa(300)
      await tocar(p.locator('.gem-form__tipo-btn', { hasText: 'Híbrida' })); await pausa(400)
      await escribir(campo('THC'), '22', { deUna: true }); await escribir(campo('CBD'), '0.5', { deUna: true }); await pausa(300)
      paso('Cuánto dura cada fase')
      await escribir(campo('Vegetativo'), '28', { deUna: true }); await escribir(campo('Floración'), '63', { deUna: true }); await pausa(500)
      paso('La guardás y ya se puede plantar')
      await tocar(p.locator('.gem-btn-new', { hasText: 'Crear genética' })); await pausa(2600)
    },
  },
  {
    id: 'lote-telefono', vista: 'telefono', usuario: ADMIN, ruta: '/m/admin/home',
    titulo: 'Un lote nuevo', quien: 'En el teléfono, desde el «+».',
    async hacer ({ p, paso, tocar, escribir, elegir, pausa }) {
      paso('Tocás «+» y «Crear lote»')
      await tocar(p.locator('[class*="fab"]').first()); await pausa(800)
      await tocar(p.locator('.mag__item', { hasText: 'Crear lote' })); await pausa(1200)
      paso('Elegís la sala: el código sale solo')
      const campo = (txt, tipo = 'select') => p.locator('.nlm__label', { hasText: txt }).locator(`xpath=following::${tipo}[1]`)
      await elegir(campo('Sala'), 'Vegetativo'); await pausa(900)
      paso('Cuántas plantas y de qué genética')
      await tocar(p.locator('.nlm__pill', { hasText: 'Semilla' })); await pausa(300)
      await escribir(campo('Cantidad de plantas', 'input'), '12', { deUna: true }); await pausa(400)
      await elegir(campo('Genética'), 'Gelato 41'); await pausa(600)
      paso('Lo creás, con sus plantas y su QR')
      await tocar(p.locator('.nlm__btn-primary', { hasText: 'Crear lote' })); await pausa(3000)
    },
  },
  {
    id: 'paciente-telefono', vista: 'telefono', usuario: ADMIN, ruta: '/m/pacientes',
    titulo: 'Un paciente nuevo', quien: 'En el teléfono, desde Más › Pacientes.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Tocás «Nuevo paciente»')
      await tocar(p.locator('button, a', { hasText: 'Nuevo paciente' }).first()); await pausa(1300)
      paso('Sus datos')
      const campo = (txt) => p.locator('.snv__label', { hasText: txt }).first().locator('xpath=following::input[1]')
      await escribir(campo('Nombre'), 'Lucía'); await escribir(campo('Apellido'), 'Benedetti')
      await escribir(campo('DNI'), '38512904', { deUna: true }); await pausa(200)
      await escribir(campo('Fecha de nacimiento'), '14/03/1991'); await pausa(200)
      await escribir(campo('Teléfono'), '+54 9 11 4567-1203', { deUna: true }); await pausa(400)
      paso('Su REPROCANN, con el vencimiento')
      await tocar(p.locator('.snv__repro-btn', { hasText: 'Vigente' })); await pausa(400)
      await escribir(campo('Número de certificado'), 'RC-2026-48213', { deUna: true })
      await escribir(campo('Fecha de vencimiento'), '15/06/2027'); await pausa(600)
      paso('Lo creás: ya se le puede dispensar')
      await tocar(p.locator('.snv__btn-primary', { hasText: 'Crear paciente' })); await pausa(1100)
      const listo = p.getByRole('button', { name: 'Listo', exact: true })
      if (await listo.isVisible().catch(() => false)) { await tocar(listo) }
      await pausa(2400)
    },
  },
  {
    id: 'dispensa-telefono', vista: 'telefono', usuario: ADMIN, ruta: '/m/dispensar',
    titulo: 'Una dispensa', quien: 'En el teléfono, desde Dispensar.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Buscás al paciente')
      await escribir(p.locator('.mdis__search'), 'Ríos'); await pausa(800)
      await tocar(p.locator('.mdis__card', { hasText: 'Martina' }).first()); await pausa(1000)
      await tocar(p.locator('.mdis__btn', { hasText: 'Dispensar' })); await pausa(1400)
      paso('Elegís qué se lleva')
      await escribir(p.locator('.mnd__buscador-input'), 'Amnesia'); await pausa(600)
      await tocar(p.locator('.mnd__stock-row', { hasText: 'Amnesia' }).first()); await pausa(700)
      await escribir(p.locator('.mnd__modal .mnd__input:visible').first(), '5', { deUna: true }); await pausa(300)
      await tocar(p.locator('.mnd__modal .mnd__btn-primary', { hasText: /^\s*Agregar\s*$/ })); await pausa(1200)
      paso('El total sale solo: no se tipea')
      await tocar(p.locator('.mnd__modal .mnd__btn-primary', { hasText: 'Cuánto sale' })); await pausa(1900)
      paso('Cobrás como pague')
      await tocar(p.locator('.mnd__modal .mnd__btn-primary', { hasText: 'Cómo paga' })); await pausa(900)
      await escribir(p.locator('.mnd__modal label', { hasText: 'Paga con' }).locator('xpath=following::input[1]'), '20000', { deUna: true }); await pausa(1600)
      paso('Confirmás, y el resto le queda a favor')
      await tocar(p.locator('.mnd__modal .mnd__btn-primary', { hasText: 'Confirmar dispensa' })); await pausa(1900)
      await tocar(p.getByRole('button', { name: 'Confirmar', exact: true })); await pausa(2700)
    },
  },

  // ── Autocultivo, en el teléfono («Para arrancar, tres cosas») ───────────────────────────
  {
    id: 'planta-autocultivo', vista: 'telefono', usuario: AUTOCULTIVO, ruta: '/m/personal/cultivo',
    titulo: 'Agregás tus plantas', quien: 'Desde «Mi cultivo», en el teléfono.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Tocás «Nueva planta»')
      await tocar(p.locator('.mmc__fab', { hasText: 'Nueva planta' })); await pausa(900)
      paso('La genética, aunque sea nueva')
      await tocar(p.locator('.np__link', { hasText: 'Genética nueva' })); await pausa(500)
      await escribir(p.locator('input[placeholder="Ej: Fruti Punchi"]'), 'Gelato Auto'); await pausa(200)
      await tocar(p.locator('.np__opcion', { hasText: 'Automática' })); await pausa(300)
      await escribir(p.locator('.np__label', { hasText: 'Días' }).locator('xpath=following::input[1]'), '70', { deUna: true }); await pausa(300)
      await tocar(p.locator('.np__btn', { hasText: 'Guardar y seguir' })); await pausa(900)
      paso('Cuántas y dónde')
      await tocar(p.locator('.np__step', { hasText: '+' })); await pausa(400)
      await tocar(p.locator('.np__opcion', { hasText: 'Semilla' })); await pausa(400)
      const donde = p.locator('.np__label', { hasText: 'Dónde' }).locator('xpath=following::select[1]')
      await tocar(donde); await donde.selectOption(await donde.evaluate(s => [...s.options].find(o => o.textContent.includes('Carpa chica'))?.value)); await pausa(600)
      paso('Listo: ya están en tu carpa')
      await tocar(p.locator('.np__btn', { hasText: 'Agregar' })); await pausa(3000)
    },
  },
  {
    id: 'riego-autocultivo', vista: 'telefono', usuario: AUTOCULTIVO, ruta: '/m/personal/cultivo',
    titulo: 'Anotás al lado de la carpa', quien: 'Desde la carpa, en el teléfono.',
    async hacer ({ p, paso, tocar, escribir, pausa }) {
      paso('Entrás a la carpa')
      await tocar(p.locator('.mmc__espacio-cab', { hasText: 'Carpa grande' })); await pausa(1500)
      paso('Tocás «Regar»')
      await tocar(p.locator('button', { hasText: /^\s*Regar\s*$/ }).first()); await pausa(1100)
      paso('Cuánto, con qué pH y EC')
      const campo = (txt) => p.locator('.rf__label', { hasText: txt }).first().locator('xpath=following::input[1]')
      await escribir(campo('Volumen'), '3', { deUna: true }); await pausa(300)
      await escribir(campo('pH entrada'), '6.2', { deUna: true }); await pausa(300)
      await escribir(campo('EC'), '1.4', { deUna: true }); await pausa(300)
      await escribir(p.locator('.rf__textarea').first(), 'Hojas sanas, sin plagas'); await pausa(500)
      paso('Guardás: queda en el diario de cada planta')
      await tocar(p.locator('.rls__btn-save')); await pausa(2600)
    },
  },
  {
    id: 'avisa-autocultivo', vista: 'telefono', usuario: AUTOCULTIVO, ruta: '/m/personal/cultivo',
    titulo: 'La app te avisa lo que viene', quien: 'En «Mi cultivo» y en cada planta.',
    async hacer ({ p, paso, tocar, pausa }) {
      paso('Cada planta, con lo que le falta')
      await p.mouse.move(195, 300); await pausa(2200)
      paso('Su ficha: el día, la fase y lo que le diste')
      await tocar(p.locator('.mmc__planta', { hasText: 'Gorilla Glue 1' })); await pausa(3200)
      await p.mouse.wheel(0, 320); await pausa(2200)
      paso('Y la carpa entera, con la cosecha estimada')
      await tocar(p.locator('.msh__tab', { hasText: 'Cultivo' })); await p.waitForSelector('.mmc__espacio-cab'); await pausa(900)
      await tocar(p.locator('.mmc__espacio-cab', { hasText: 'Carpa grande' })); await pausa(3200)
    },
  },
]
