# Íconos de la app

`logo-ce-redondo.png` (500×500) es el ícono de todo: favicon y apple-touch-icon en
`index.html`, y el ícono del manifest en `vite.config.js`. Un solo archivo, un solo lugar.

Hasta agosto 2026 el manifest apuntaba a `icons/*.svg`, que eran placeholders generados en marzo
(un cuadrado verde con un emoji 🌿). El favicon ya usaba el logo bueno, así que la pestaña se veía
bien y **la app instalada seguía con el provisorio** — que es el que aparece en el escritorio.

## Lo que falta: el ícono `maskable`

Android le aplica una máscara al ícono (círculo, squircle, gota según el fabricante) y **recorta
hasta un 10% de cada borde**. Nuestro logo tiene fondo transparente, así que recortado se ve el
borde comido y la transparencia alrededor.

No está declarado en el manifest a propósito: **es mejor no tener maskable que tener uno que se
vea cortado** — sin él, Android le pone su propio fondo al ícono normal y queda aceptable.

Para agregarlo hace falta exportar del diseño, no se puede derivar del PNG actual:

- **512×512 PNG**, fondo **sólido** `#0F2A1E` (el `theme_color` del manifest, sin transparencia)
- El dibujo **dentro del 80% central** (410×410 centrado): todo lo que quede fuera se puede
  recortar
- Guardar como `public/logo-ce-maskable.png`

Y sumarlo a los `icons` del manifest en `vite.config.js`:

```js
{ src: 'logo-ce-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
```

Probar en https://maskable.app/editor antes de subirlo — muestra cómo queda con cada máscara.

## Por qué PNG y no SVG

Chrome de escritorio elige mal entre íconos SVG al instalar una PWA, y el soporte de SVG
`maskable` en Android es irregular. Todo el manifest usa PNG.

## Después de cambiarlo

El ícono se cachea **al instalar**: hay que desinstalar la PWA y volver a instalarla para verlo.
Un refresh no alcanza.
