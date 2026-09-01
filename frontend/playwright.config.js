// Pruebas de punta a punta contra la app corriendo, con la organización `e2e` sembrada por
// `rake e2e:seed`. NO tocan clubes reales: probar sobre datos de verdad es cómo se rompe una
// base de desarrollo.
//
//   docker compose exec backend bundle exec rake e2e:seed
//   npm run e2e
//
// Un solo worker y sin reintentos a propósito: los casos comparten el mismo mostrador —abrir,
// recibir, dispensar, cerrar— y en paralelo se pisarían entre ellos. Es el mismo mostrador que
// en la vida real: uno solo por sede.
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 60_000,
  reporter: [['list']],
  use: {
    baseURL: process.env.E2E_URL || 'http://localhost:5173',
    viewport: { width: 1280, height: 900 },
    // La app la usa gente en Argentina y el servidor corre en esa zona: probar desde UTC
    // esconde justo los bugs de borde de día, que son los que más aparecen.
    timezoneId: 'America/Argentina/Buenos_Aires',
    locale: 'es-AR',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
})
