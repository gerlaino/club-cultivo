import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar } from './helpers.js'

// El modal con el que el repartidor registra una entrega, MIRADO EN LA PANTALLA.
//
// Tenía la tarjeta "Tu próxima entrega" pegada dos veces: la copia mala había quedado adentro
// del `<template v-else>` del cartel de cobro, o sea que aparecía en medio del modal EXACTAMENTE
// cuando efectivo + transferencia cubrían el total — y se comía el "Cubierto ✓". Ninguna suite
// lo veía: el template compila igual y el bug es dónde está dibujado.
//
// Escenario: `rake e2e:seed && rake e2e:entrega_a_cobrar` deja a Beto con un paquete en viaje de
// $212.500 a cobrar contra entrega. Es el único estado donde este panel se dibuja.
test.describe.configure({ mode: 'serial' })

test.beforeAll(() => sembrar('seed', 'entrega_a_cobrar'))

test('el modal de entrega no dibuja la próxima parada adentro', async ({ page }) => {
  const errores = vigilarErrores(page)

  await entrar(page, 'delivery')
  await page.goto('/delivery')

  // La tarjeta de foco SÍ va en la pantalla: una sola vez, y fuera de cualquier modal.
  await expect(page.locator('.dlv__foco')).toHaveCount(1)

  await page.locator('.dlv__foco-btn--ok').click()
  const modal = page.locator('.dlv__modal')
  await expect(modal).toBeVisible()
  await expect(modal.locator('.dlv__cobro-head')).toContainText('212.500')

  // Todavía falta plata: el cartel dice cuánto queda y la tarjeta no aparece por ningún lado.
  await modal.locator('.dlv__cobro-cell input').first().fill('150000')
  await expect(modal.locator('.dlv__cobro-resto')).toContainText('Resto a cuenta corriente')
  await expect(modal.locator('.dlv__foco')).toHaveCount(0)

  // Y con el total cubierto —la rama donde estaba pegada— tiene que decir "Cubierto".
  await modal.locator('.dlv__cobro-cell input').nth(1).fill('62500')
  await expect(modal.locator('.dlv__cobro-resto')).toContainText('Cubierto')
  await expect(modal.locator('.dlv__foco')).toHaveCount(0)
  await expect(modal.getByText('Tu próxima entrega')).toHaveCount(0)

  expect(errores).toEqual([])
})
