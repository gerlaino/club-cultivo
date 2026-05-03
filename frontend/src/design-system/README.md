# Design System — Club Cultivo

## Íconos

**Librería oficial del DS: `lucide-vue-next`**

```vue
import { Bell, Users, Building2 } from 'lucide-vue-next'
// <Bell :size="20" :stroke-width="1.75" />
```

Tamaños estándar: sidebar nav → `size="18"`, topbar → `size="20"`. Stroke-width estándar: `1.75` (el default de lucide es 2; 1.75 queda más fino y encaja con el lenguaje visual del DS).

**NO usar `bi-*` en componentes nuevos del DS ni en pantallas refactorizadas.**

El resto de la app (cultivador, médico, dispensador, sedes, pacientes, etc.) conserva `bi-*` hasta que cada pantalla sea refactorizada en su ola. NO migrar bi-* a lucide en pantallas no refactorizadas — es deuda anotada que se cierra ola por ola.

## Tokens

Definidos en `tokens.css`. Variables de color (`--c-leaf-*`, `--c-ink-*`), espacio (`--sp-*`), tipografía (`--font-ui`, `--font-display`, `--font-mono`), bordes (`--r-*`) y sombras (`--sh-*`).

## Primitivos

| Componente | Props clave |
|---|---|
| `Avatar` | `name`, `tone`, `size` (sm/md/lg) |
| `Badge` | `variant` (leaf/amber/rust/gold/sky/ink), `size` |
| `Banner` | `variant`, `icon`; slots: default + `action` |
| `Button` | `variant`, `size`, `loading`, `disabled` |
| `Card` | `variant`, `padding` |
| `Dropdown` | `modelValue` (v-model), `align` (right/left) |
| `EmptyState` | `title`, `description`; slot default para CTA |
| `Skeleton` | `variant` (line/card/table), `rows`, `cols` |
| `Spinner` | — |
| `Stat` | `label`, `value`, `delta`, `deltaUnit`, `tone` |

## Fuentes

Cargadas en `index.html` via `<link>` (NO con `@import url()` en CSS — bug de chunk en Vite dev).

- Inter → `--font-ui`
- General Sans → `--font-display`
- Geist Mono → `--font-mono`
