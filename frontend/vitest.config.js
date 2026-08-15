import { fileURLToPath } from 'node:url'
import { mergeConfig, defineConfig, configDefaults } from 'vitest/config'
import viteConfig from './vite.config'

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      environment: 'jsdom',
      // El chequeo de variables inexistentes corre ESLint sobre todo `src` y ocupa un núcleo
      // ~13s. Con el default de 5s, los tests de DOM que se ejecutan en paralelo con él hacían
      // timeout de a uno y la suite salía roja al azar. No miden performance: darles aire es
      // más honesto que perseguir un verde intermitente.
      testTimeout: 20_000,
      exclude: [...configDefaults.exclude, 'e2e/**'],
      root: fileURLToPath(new URL('./', import.meta.url)),
    },
  }),
)
