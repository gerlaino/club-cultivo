import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, elegirPorTexto, sembrar, idDeUsuario, USUARIOS } from './helpers.js'

// La entrega de la recaudación del repartidor, con las dos personas adentro: él la inicia y
// elige a quién, el que recibe CUENTA, y si ajustó el monto vuelve a él para que deje constancia.
//
// La plata nunca queda en el aire: el que cuenta es el que la tiene en la mano, y ese número es
// el que entra al cajón. No hay estado "en disputa" — dejaría plata que no está en ningún lado.
//
// Escenario: `rake e2e:seed && rake e2e:reparto` deja a Beto con $100.000 cobrados en dos
// entregas y un paquete de 25 g que no pudo entregar.
test.describe.configure({ mode: 'serial' })

// Mostrador abierto con 100 g y recibido, y Beto con $100.000 cobrados y un paquete sin entregar.
test.beforeAll(() => sembrar('seed', 'reparto'))

test('la rendición del repartidor, de punta a punta', async ({ page }) => {
  const errores = vigilarErrores(page)

  // El escenario lo deja `rake e2e:reparto`: mostrador abierto con 100 g y recibido por Dana,
  // y Beto con $100.000 cobrados y un paquete de 25 g sin entregar. Armarlo por pantalla haría
  // que un fallo del setup se lea como un fallo de lo que se está probando.

  // ── 2. Beto rinde y elige a quién ─────────────────────────────────────────
  await entrar(page, 'delivery')
  await page.goto('/delivery')
  await expect(page.getByText('Rendir la caja')).toBeVisible()
  // El monto NO lo escribe él: no hay ningún campo de plata en su pantalla.
  await expect(page.locator('.rnd__input')).toHaveCount(0)

  await elegirPorTexto(page, '.rnd__select', 'Dana')
  await page.click('.rnd__btn--primary')
  await expect(page.getByText(/Rendiste \$100\.000/)).toBeVisible()
  await expect(page.getByText(/Esperando que .* la reciba/)).toBeVisible()

  // ── 3. Dana lo ve al entrar al mostrador, y cuenta ────────────────────────
  await entrar(page, 'dispensador')
  await page.goto('/mostrador')
  await expect(page.getByText(/te está rindiendo/)).toBeVisible()
  await expect(page.getByText(/2 entregas · declara \$100\.000/)).toBeVisible()

  // El paquete que vuelve se lista: se desarma solo, no se elige.
  await expect(page.getByText('Trae 1 paquete sin entregar')).toBeVisible()
  await expect(page.locator('.rnd__paquete')).toContainText('25 g')
  await expect(page.locator('.rnd__paquete input')).toHaveCount(0)

  // Trae $80.000 de los $100.000: la diferencia queda a su nombre, no se da por perdida.
  await page.fill('.rnd__input', '80000')
  await expect(page.locator('.rnd__falta')).toContainText('Faltan $20.000')
  await expect(page.locator('.rnd__falta')).toContainText('no se dan por perdidos')

  // Sin motivo no se recibe.
  await page.click('.rnd__btn--primary')
  await expect(page.getByText(/te está rindiendo/)).toBeVisible()

  await page.fill('.rnd__input--motivo', 'se quedó 20 a cuenta de sueldo')
  await page.click('.rnd__btn--primary')
  await expect(page.getByText(/te está rindiendo/)).toHaveCount(0, { timeout: 15_000 })

  // ── 4. El paquete que volvió está sobre la mesa ───────────────────────────
  // 100 que cargó el admin + los 25 que volvieron. Antes el gramo se iba al depósito y el que
  // atiende no lo tenía para el próximo que lo pidiera, con el paquete ahí adelante.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('125')

  // ── 5. Beto deja constancia de si está de acuerdo ─────────────────────────
  await entrar(page, 'delivery')
  await page.goto('/delivery')
  await expect(page.getByText(/recibió \$80\.000 de los \$100\.000 que cobraste/)).toBeVisible()
  await expect(page.getByText('se quedó 20 a cuenta de sueldo')).toBeVisible()
  await page.click('.rnd__btn--primary') // "Estoy de acuerdo"
  await expect(page.getByText(/recibió \$80\.000/)).toHaveCount(0, { timeout: 15_000 })

  expect(errores, errores.join('\n')).toEqual([])
})

test('el admin ve la rendición en el historial y lo acumulado en la ficha', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  // El historial, en la solapa del mostrador.
  await page.goto('/mostrador')
  await page.locator('.mst__tab', { hasText: 'Rendiciones' }).click()
  const fila = page.locator('.rnd__tabla tbody tr').first()
  await expect(fila).toContainText('Beto')
  await expect(fila).toContainText('$100.000')
  await expect(fila).toContainText('$80.000')
  await expect(fila.locator('.rnd__dif')).toHaveText('−$20.000')
  // La conformó, así que no queda pendiente de nadie.
  await expect(fila).toContainText('Conformada')

  // Y lo acumulado, en la ficha de Beto.
  const id = await idDeUsuario(page, USUARIOS.delivery)
  expect(id, 'no se encontró al repartidor en el equipo').toBeTruthy()
  await page.goto(`/usuarios/${id}`)
  await expect(page.getByText('Tiene del club')).toBeVisible({ timeout: 15_000 })
  await expect(page.locator('.udc__acuenta-val')).toContainText('20.000')
  await expect(page.getByText(/No es una pérdida/)).toBeVisible()

  expect(errores, errores.join('\n')).toEqual([])
})

// Y cuando trae el resto, se salda. Sin esto lo que se quedó se acumulaba PARA SIEMPRE: no había
// forma de decir "ya la devolvió". Lo registra quien la recibe, nunca él.
test('el admin registra la devolución y el saldo vuelve a cero', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  const id = await idDeUsuario(page, USUARIOS.delivery)
  await page.goto(`/usuarios/${id}`)
  await expect(page.locator('.udc__acuenta-val')).toContainText('20.000', { timeout: 15_000 })

  await page.fill('.udc__saldar-input', '20000')
  await page.click('.udc__saldar-btn')

  // Saldado: la tarjeta de "tiene del club" desaparece porque ya no tiene nada.
  await expect(page.locator('.udc__saldar')).toHaveCount(0, { timeout: 15_000 })

  expect(errores, errores.join('\n')).toEqual([])
})
