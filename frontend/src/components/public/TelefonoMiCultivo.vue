<template>
  <!-- El encabezado de la página de autocultivo (Germán, 9-oct-2026): en vez de repetir la planta
       que crece de la portada, el TELÉFONO con «Mi cultivo» como se ve de verdad en la app — las
       carpas con sus plantas, autos y fotos juntas, y lo que le toca a cada una. -->
  <div class="tmc" role="img" aria-label="La app en el teléfono: Mi cultivo, con las carpas y sus plantas">
    <div class="tmc__pantalla">
      <div class="tmc__cab">
        <span class="tmc__fecha">Jueves 8 de octubre</span>
        <b class="tmc__titulo">Mi cultivo</b>
        <span class="tmc__sub">6 plantas en 2 carpas</span>
      </div>
      <div class="tmc__cuerpo">
        <div v-for="c in CARPAS" :key="c.nombre" class="tmc__carpa">
          <div class="tmc__carpa-cab"><b>{{ c.nombre }}</b><small>{{ c.luz }}</small></div>
          <div class="tmc__grilla">
            <div v-for="(p, i) in c.plantas" :key="p.n" class="tmc__planta" :style="{ animationDelay: `${300 + i * 120}ms` }">
              <span class="tmc__top"><b>{{ p.n }}</b><i :class="p.auto ? 'tmc__auto' : 'tmc__foto'">{{ p.auto ? 'Auto' : 'Foto' }}</i></span>
              <small>{{ p.d }}</small>
              <em v-if="p.toca">{{ p.toca }}</em>
            </div>
          </div>
        </div>
      </div>
      <div class="tmc__fab">+ Nueva planta</div>
      <div class="tmc__nav"><span>Hoy</span><span class="tmc__nav--on">Cultivo</span><b>+</b><span>Stock</span><span>Gastos</span></div>
    </div>
  </div>
</template>

<script setup>
const CARPAS = [
  { nombre: 'Carpa grande', luz: '12/12 · floración', plantas: [
    { n: 'Gorilla 1', d: 'Flora · día 23', toca: 'Regar hoy' },
    { n: 'La petisa', d: 'Día 61 de 77', toca: 'Cosecha en 16 d', auto: true },
    { n: 'Ananda 1', d: 'Flora · día 23' },
    { n: 'Gorilla 2', d: 'Flora · día 23', toca: 'Regar hoy' },
  ] },
  { nombre: 'Carpa chica', luz: '18/6 · vegetativo', plantas: [
    { n: 'Fruti 1', d: 'Día 19 de 75', toca: '1.er fertilizante', auto: true },
    { n: 'Esqueje Ananda', d: 'Vege · día 12' },
  ] },
]
</script>

<style scoped>
.tmc {
  justify-self: center; width: min(310px, 100%); aspect-ratio: 9 / 18.5; padding: 10px;
  border-radius: 44px; background: #0c1a12; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .45), inset 0 0 0 2px rgb(255 255 255 / .08);
  transform: rotate(2deg);
}
.tmc__pantalla { position: relative; height: 100%; border-radius: 34px; overflow: hidden; background: #F4F8F5; color: #1A1D1F; display: flex; flex-direction: column; font-family: var(--hb-sans); }
.tmc__cab { background: #1A3D2E; color: #fff; padding: 30px 16px 14px; border-radius: 0 0 20px 20px; display: flex; flex-direction: column; gap: 1px; }
.tmc__fecha { font-size: 10px; color: #A8C9B5; }
.tmc__titulo { font-size: 20px; letter-spacing: -.01em; }
.tmc__sub { font-size: 10.5px; color: #E8F0EB; }
.tmc__cuerpo { padding: 10px 10px 0; display: flex; flex-direction: column; gap: 10px; overflow: hidden; }
.tmc__carpa { display: flex; flex-direction: column; }
.tmc__carpa-cab { display: flex; flex-direction: column; margin-bottom: 5px; }
.tmc__carpa-cab b { font-size: 12.5px; }
.tmc__carpa-cab small { font-size: 9.5px; color: #3A3F44; }
.tmc__grilla { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; }
.tmc__planta {
  background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 7px 8px; display: flex; flex-direction: column; gap: 2px;
  opacity: 0; animation: tmc-entra .35s ease forwards;
}
.tmc__top { display: flex; align-items: center; justify-content: space-between; gap: 4px; }
.tmc__top b { font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tmc__top i { font-style: normal; font-size: 8.5px; font-weight: 700; padding: 1px 6px; border-radius: 99px; }
.tmc__auto { background: #FEF3C7; color: #92400E; }
.tmc__foto { background: #E8F0EB; color: #1A3D2E; }
.tmc__planta small { font-size: 9.5px; color: #3A3F44; }
.tmc__planta em { font-style: normal; font-size: 9.5px; font-weight: 600; color: #92400E; }
.tmc__fab { position: absolute; right: 12px; bottom: 58px; background: #2D4A3E; color: #fff; border-radius: 99px; padding: 8px 12px; font-size: 10.5px; font-weight: 700; box-shadow: 0 8px 16px -8px rgb(15 42 30 / .6); }
.tmc__nav { margin-top: auto; display: flex; align-items: center; justify-content: space-around; padding: 9px 8px 13px; border-top: 1px solid #E1E8E3; background: #fff; font-size: 10px; color: #6B7280; }
.tmc__nav--on { color: #1A3D2E; font-weight: 700; }
.tmc__nav b { width: 32px; height: 32px; border-radius: 50%; display: grid; place-items: center; background: #2E7D4F; color: #fff; font-size: 18px; font-weight: 400; margin-top: -16px; }
@keyframes tmc-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .tmc__planta { animation: none; opacity: 1; } }
</style>
