// EL PIE DEL MODAL DE DISPENSA A ANCHO DE TELÉFONO.
//
// Germán mandó la captura: «$ 543.06» cortado al medio y «Cómo paga» saliéndose. Eran tres cosas
// en una fila —Cancelar, el total, el botón— y el total es un número que NO se puede partir: con
// seis cifras en monoespaciado no entra nunca. Ahora tiene su propio renglón.
//
// Se mide con el CSS COMPILADO del build, no con una copia a mano: si el archivo cambia y la regla
// se rompe, este test tiene que enterarse. Y con layout de verdad — en jsdom esto no se ve.
import { test, expect } from '@playwright/test'
import { readFileSync, readdirSync } from 'node:fs'

const DIST = new URL('../dist/assets/', import.meta.url).pathname
const CSS = readdirSync(DIST)
  .filter(f => f.startsWith('ModalNuevaDispensacion') && f.endsWith('.css'))
  .map(f => readFileSync(DIST + f, 'utf8')).join('\n')

// Los estilos del componente son SCOPED: sin el atributo `data-v-xxxx` no aplica ni una regla y
// el test mide el layout por defecto del navegador — verde por la razón equivocada, que ya pasó
// una vez en esta misma sesión. El scope se saca del propio CSS para que sobreviva a los rebuilds.
const SCOPE = (CSS.match(/\[(data-v-[0-9a-f]+)\]/) || [])[1]

// El pie tal como lo arma el componente en el paso 1, con el total de la captura.
const PIE = (total) => `
<div class="mnd__modal" ${SCOPE} style="width:100%">
  <div class="mnd__actions" ${SCOPE}>
    <div class="mnd__barra-acc" ${SCOPE}>
      <button class="mnd__btn-ghost" ${SCOPE}>Cancelar</button>
      <span class="mnd__barra-total" ${SCOPE}><b ${SCOPE}>1</b> ítem <em ${SCOPE}>$ ${total}</em></span>
      <button class="mnd__btn-primary mnd__barra-seguir" ${SCOPE}>Cómo paga <i class="bi bi-chevron-right" ${SCOPE}></i></button>
    </div>
  </div>
</div>
<style>${CSS}</style>`

test('el total y el botón entran a 320, 360 y 390 px', async ({ page }) => {
  expect(CSS, 'no se encontró el CSS compilado — ¿falta `npm run build`?').toContain('mnd__barra-acc')
  expect(SCOPE, 'sin el scope de Vue, ninguna regla aplica y el test no prueba nada').toBeTruthy()

  for (const ancho of [320, 360, 390]) {
    await page.setViewportSize({ width: ancho, height: 700 })
    await page.setContent(PIE('543.064,2'))   // el número exacto de la captura
    await page.waitForTimeout(150)

    const m = await page.evaluate(() => {
      const barra = document.querySelector('.mnd__barra-acc')
      const total = document.querySelector('.mnd__barra-total')
      const boton = document.querySelector('.mnd__barra-seguir')
      const dentro = (el) => {
        const a = el.getBoundingClientRect(), b = barra.getBoundingClientRect()
        return a.left >= b.left - 1 && a.right <= b.right + 1
      }
      return {
        pagina: document.documentElement.scrollWidth,
        ventana: document.documentElement.clientWidth,
        desborda: barra.scrollWidth > barra.clientWidth + 1,
        totalDentro: dentro(total), botonDentro: dentro(boton),
        // El total tiene que quedar en su PROPIO renglón, arriba de los botones.
        totalArriba: total.getBoundingClientRect().bottom <= boton.getBoundingClientRect().top + 1,
        aplicaElCss: getComputedStyle(total).order === '-1',
      }
    })
    console.log(ancho, JSON.stringify(m))

    expect(m.aplicaElCss, `${ancho}px: el CSS del componente no aplicó`).toBe(true)
    expect(m.pagina, `${ancho}px: la pantalla se corre`).toBeLessThanOrEqual(m.ventana + 1)
    expect(m.desborda, `${ancho}px: la barra desborda`).toBe(false)
    expect(m.totalDentro, `${ancho}px: el total se sale (lo de la captura)`).toBe(true)
    expect(m.botonDentro, `${ancho}px: el botón se sale`).toBe(true)
    expect(m.totalArriba, `${ancho}px: el total volvió a la fila de los botones`).toBe(true)
  }
})
