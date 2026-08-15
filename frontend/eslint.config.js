import { defineConfig, globalIgnores } from 'eslint/config'
import globals from 'globals'
import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'
import pluginVitest from '@vitest/eslint-plugin'
import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'

export default defineConfig([
  {
    name: 'app/files-to-lint',
    files: ['**/*.{js,mjs,jsx,vue}'],
  },

  globalIgnores(['**/dist/**', '**/dist-ssr/**', '**/coverage/**']),

  {
    languageOptions: {
      globals: {
        ...globals.browser,
        // Los reemplaza Vite al compilar (ver `define` en vite.config.js): existen en el bundle
        // pero no en el código, así que sin declararlos `no-undef` los marca y tapa los de verdad.
        __APP_BUILD__: 'readonly',
        __APP_BUILD_AT__: 'readonly',
      },
    },
  },

  // El service worker no corre en la ventana: tiene sus propios globals.
  {
    files: ['src/sw.js'],
    languageOptions: { globals: { ...globals.serviceworker } },
  },

  // Los tests corren en Node.
  {
    files: ['src/**/__tests__/**'],
    languageOptions: { globals: { ...globals.node } },
  },

  js.configs.recommended,
  ...pluginVue.configs['flat/essential'],
  
  {
    ...pluginVitest.configs.recommended,
    files: ['src/**/__tests__/*'],
  },
  skipFormatting,
])
