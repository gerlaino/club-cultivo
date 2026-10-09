<template>
  <!-- «UNA VISTA POR ROL» (Germán, 8-oct-2026; «rol» y no «oficio» desde el 9-oct): al tocar un
       rol se ve SU pantalla y una explicación corta. Administración va primero y abierta: es quien
       contrata. Delivery muestra la entrega simulada (`SimulacionEntrega`). Las pantallas replican
       las de la app con datos ficticios. -->
  <section class="hb__sec hb__sec--claro" id="roles">
    <div class="hb__wrap">
      <header class="hb__sec-h">
        <p class="hb__ceja">El equipo</p>
        <h2 class="hb__h2">Una vista por rol</h2>
        <p class="ov__intro">Cada persona entra con su usuario y ve lo que necesita para su trabajo, nada más. Tocá un rol y mirá su pantalla.</p>
      </header>

      <div class="ov__grilla">
        <div class="ov__lista" role="tablist" aria-label="Roles">
          <button v-for="r in ROLES" :key="r.k" type="button" role="tab" class="ov__rol" :class="{ 'is-on': sel === r.k }"
                  :aria-selected="sel === r.k" :aria-controls="`ov-panel-${r.k}`" @click="sel = r.k">
            <span class="ov__rol-cab"><b>{{ r.quien }}</b></span>
            <span class="ov__rol-corto">{{ r.corto }}</span>
          </button>
        </div>

        <div :id="`ov-panel-${sel}`" class="ov__panel" role="tabpanel">
          <div class="ov__texto">
            <p class="ov__ceja">{{ rol.ceja }}</p>
            <h3 class="ov__titulo">{{ rol.titulo }}</h3>
            <p class="ov__desc">{{ rol.texto }}</p>
            <ul class="ov__puntos"><li v-for="p in rol.puntos" :key="p">{{ p }}</li></ul>
          </div>

          <div class="ov__tel" aria-hidden="true">
            <div class="ov__pantalla" :key="sel">
              <div class="ov__tel-cab"><small>{{ rol.sub }}</small><b>{{ rol.pantalla }}</b></div>
              <div class="ov__tel-cuerpo">
                <template v-if="sel === 'cultivo'">
                  <div v-for="(t, i) in TAREAS" :key="t[0]" class="ov__fila" :class="{ 'ov__fila--on': !i }" :style="d(i)">
                    <div><b>{{ t[0] }}</b><small>{{ t[1] }}</small></div>
                    <div class="ov__botones"><span class="ov__b">Hecho</span><span class="ov__b ov__b--linea">No se hizo</span></div>
                  </div>
                  <p class="ov__sec">Tus salas</p>
                  <div class="ov__fila" :style="d(3)"><div><b>Flora 2</b><small>L-26-002 · día 23 de flora · 12 plantas</small></div><b class="ov__verde">24,8° · 55 %</b></div>
                </template>

                <template v-else-if="sel === 'manicura'">
                  <div class="ov__aviso">Sin señal · lo que cargues se manda solo al volver</div>
                  <div class="ov__caja" :style="d(1)">
                    <div class="ov__entre"><b>L-26-002 · secado</b><small>día 9</small></div>
                    <div class="ov__dos"><div class="ov__dato"><small>Húmedo</small><b>1.840 g</b></div><div class="ov__dato ov__dato--on"><small>Seco hoy</small><b>412 g</b></div></div>
                    <small class="ov__ambar">Merma 77,6 %</small>
                    <span class="ov__b ov__b--ancho">Mandar a aprobar</span>
                  </div>
                  <div class="ov__fila" :style="d(2)"><span>L-25-038 · curado</span><b class="ov__verde">Aprobado</b></div>
                </template>

                <template v-else-if="sel === 'mostrador'">
                  <div class="ov__entre ov__chico"><span>Paso 3 de 3 · Cobro</span><span>Caja abierta · 14:02</span></div>
                  <div class="ov__caja" :style="d(1)">
                    <b>Paciente N.º 0231 <small class="ov__verde">REPROCANN vigente</small></b>
                    <div class="ov__entre"><span>King’s Juice · 5 g</span><span>$ 25.000</span></div>
                    <div class="ov__entre"><span>Aceite 10 ml</span><span>$ 18.000</span></div>
                    <div class="ov__entre ov__verde"><span>A favor de la vez pasada</span><span>− $ 3.000</span></div>
                    <div class="ov__entre ov__total"><b>Total</b><b>$ 40.000</b></div>
                  </div>
                  <div class="ov__dos" :style="d(2)"><div class="ov__dato ov__dato--on"><small>Efectivo</small><b>$ 20.000</b></div><div class="ov__dato"><small>Transferencia</small><b>$ 20.000</b></div></div>
                  <span class="ov__b ov__b--ancho" :style="d(3)">Confirmar e imprimir etiqueta</span>
                </template>

                <template v-else-if="sel === 'medico'">
                  <div v-for="(t, i) in TURNOS" :key="t.h" class="ov__turno" :class="[`ov__turno--${t.e}`, { 'ov__turno--ahora': t.ahora }]" :style="d(i)">
                    <small>{{ t.h }}</small>
                    <div><b>{{ t.p }}</b><small>{{ t.tipo }}</small></div>
                    <span class="ov__estado">{{ t.lbl }}</span>
                  </div>
                  <div class="ov__caja ov__caja--on" :style="d(5)">
                    <small class="ov__verde ov__mayus">Atendiendo · 15:30</small>
                    <b>Paciente N.º 0302 · Revisión</b>
                    <span>Aceite 1:1 · 0,5 ml cada 12 h</span>
                    <small class="ov__ambar">Indicación: vence en 12 días · ya avisó</small>
                    <div class="ov__entre ov__chico"><span>Notas: sólo las ve el médico</span><b class="ov__verde">Prescripción PDF</b></div>
                  </div>
                </template>

                <SimulacionEntrega v-else-if="sel === 'delivery'" />

                <template v-else>
                  <div class="ov__dos" :style="d(0)"><div class="ov__dato"><small>Pacientes activos</small><b>87</b></div><div class="ov__dato"><small>Dispensado hoy</small><b>$ 412.000</b></div></div>
                  <div class="ov__dos" :style="d(1)"><div class="ov__dato"><small>Flor en stock</small><b>1.240 g</b></div><div class="ov__dato"><small>En floración</small><b>318 de 450</b></div></div>
                  <p class="ov__sec">Para mirar</p>
                  <div v-for="(a, i) in AVISOS" :key="a[0]" class="ov__fila" :style="d(i + 2)"><span>{{ a[0] }}</span><b class="ov__ambar">{{ a[1] }}</b></div>
                </template>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, computed } from 'vue'
import SimulacionEntrega from './SimulacionEntrega.vue'

// Lo que se dice de cada rol existe HOY en la app (regla de `contenido.js`).
const ROLES = [
  { k: 'admin', quien: 'Administración', corto: 'Toda la organización, y quién hace qué.', ceja: 'Administración', pantalla: 'Hoy en la organización', sub: 'Sede Palermo',
    titulo: 'La organización entera, de un vistazo',
    texto: 'Administración ve pacientes, stock, caja, contabilidad e informes, y lo que necesita su atención antes de que sea un problema.',
    puntos: ['REPROCANN por vencer, con aviso', 'Pesadas y altas para aprobar', 'Informes para presentar, del mismo período que ve'] },
  { k: 'cultivo', quien: 'Cultivo', corto: 'Sus salas y las tareas del día, en el teléfono.', ceja: 'Cultivo', pantalla: 'Para hoy', sub: 'Jueves 14 · Lucía',
    titulo: 'Al lado de la planta, no en una planilla',
    texto: 'Quien cultiva ve sus salas y lo que le toca hoy. Riega, registra y saca fotos desde el teléfono, y marca cada tarea como hecha o no hecha.',
    puntos: ['Tareas armadas según la fase de cada lote', 'Riego con receta: descuenta del depósito solo', 'Ambiente de cada sala a la vista'] },
  { k: 'manicura', quien: 'Manicura', corto: 'Las pesadas, aun sin señal, con aprobación.', ceja: 'Manicura', pantalla: 'Por pesar', sub: 'Secado y curado',
    titulo: 'Lo que se pesa, queda pesado',
    texto: 'La manicura carga húmedo, seco y curado. Sin señal se guarda en el teléfono; lo que pesa espera la aprobación de administración antes de entrar al stock.',
    puntos: ['La merma de cada etapa, calculada', 'Funciona sin señal y se sincroniza solo', 'Nada entra al stock sin aprobación'] },
  { k: 'mostrador', quien: 'Mostrador', corto: 'La mesa, el carrito y su caja.', ceja: 'Mostrador', pantalla: 'Dispensa', sub: 'Caja de Sofía',
    titulo: 'Dispensar en tres pasos, y que la caja cierre',
    texto: 'Quien atiende dispensa lo que está sobre la mesa, cobra como pague cada paciente y cierra su caja sin esperar a nadie. No ve la contabilidad.',
    puntos: ['Lo pagado de más se descuenta solo la próxima vez', 'Varios medios de pago en una dispensa', 'El REPROCANN del paciente a la vista'] },
  { k: 'medico', quien: 'Médico', corto: 'Su agenda, sus pacientes y la historia clínica.', ceja: 'Módulo médico · viene con Producción y dispensa', pantalla: 'Agenda · Dra. López', sub: 'Martes 14 · 14 a 18 h',
    titulo: 'El consultorio y el turnero, adentro',
    texto: 'Los médicos atienden en el mismo sistema donde se cultiva y se dispensa. La agenda, la historia clínica y la indicación de cada paciente están al lado de lo que retira.',
    puntos: ['Ve sólo a sus pacientes vinculados', 'Turnos con aviso al teléfono y «Lo vi»; los que quedan sin cerrar, a la vista',
             'Indicación con vencimiento y prescripción en PDF; lo clínico va cifrado'] },
  { k: 'delivery', quien: 'Delivery', corto: 'Su ruta, la firma y la rendición.', ceja: 'Delivery', pantalla: 'Ruta de hoy', sub: 'Nico · 3 paradas',
    titulo: 'Hasta la puerta del paciente',
    texto: 'Quien reparte tiene su ruta del día en el teléfono, cobra contra entrega y hace firmar. Lo que no se entregó vuelve al stock, y el efectivo se rinde a una persona.',
    puntos: ['Paquetes armados desde el stock', 'Firma y cobro en la puerta', 'Rendición dirigida, sin plata suelta'] },
]
const TAREAS = [['Regar Flora 2', '12 plantas · receta Floración 3'], ['Defoliar L-26-007', 'Flora 1 · semana 3'], ['Foto de la semana', 'Vege 1']]
// Estados y tipos de `Turno`; «Sin cerrar» = turno pasado sin cerrar (pendiente de entrevista).
const TURNOS = [
  { h: '14:00', p: 'Paciente N.º 0231', tipo: 'Seguimiento', e: 'realizado', lbl: 'Realizado' },
  { h: '14:30', p: 'Paciente N.º 0187', tipo: 'Primera vez', e: 'ausente', lbl: 'Faltó' },
  { h: '15:00', p: 'Paciente N.º 0412', tipo: 'Pendiente de entrevista', e: 'pendiente', lbl: 'Sin cerrar' },
  { h: '15:30', p: 'Paciente N.º 0302', tipo: 'Revisión', e: 'confirmado', lbl: 'Confirmado', ahora: true },
  { h: '16:00', p: 'Paciente N.º 0145', tipo: 'Seguimiento', e: 'programado', lbl: 'Programado' },
]
const AVISOS = [['REPROCANN por vencer', '6 pacientes'], ['Pesadas para aprobar', '2'], ['Turnos sin cerrar', '1']]

const sel = ref('admin')
const rol = computed(() => ROLES.find(r => r.k === sel.value))
// Las filas entran de a una, como en las demás muestras.
const d = (i) => ({ animationDelay: `${120 + i * 110}ms` })
</script>

<style scoped>
.ov__intro { margin: 10px 0 0; color: var(--hb-tinta-2); }
.ov__grilla { display: grid; grid-template-columns: minmax(0, 300px) minmax(0, 1fr); gap: 28px; align-items: start; }
@media (max-width: 900px) { .ov__grilla { grid-template-columns: minmax(0, 1fr); } }
.ov__lista { display: flex; flex-direction: column; gap: 8px; }
@media (max-width: 900px) { .ov__lista { flex-direction: row; overflow-x: auto; padding-bottom: 4px; } .ov__rol { min-width: 200px; } }
.ov__rol {
  text-align: left; padding: 14px 16px; background: transparent; border: 1px solid var(--hb-regla); cursor: pointer;
  display: flex; flex-direction: column; gap: 4px; font: inherit; color: var(--hb-tinta);
}
.ov__rol:hover { border-color: var(--hb-verde); }
.ov__rol.is-on { background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); box-shadow: 4px 4px 0 var(--hb-salvia); }
.ov__rol:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 2px; }
.ov__rol-cab { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.ov__rol-cab b { font-size: 1.05rem; }
.ov__rol-corto { font-size: .9rem; color: var(--hb-tinta-2); line-height: 1.4; }

.ov__panel { background: var(--hb-bosque); color: var(--hb-papel-claro); padding: clamp(20px, 3vw, 32px); display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 320px); gap: 28px; align-items: center; }
@media (max-width: 700px) { .ov__panel { grid-template-columns: minmax(0, 1fr); } }
.ov__texto { min-width: 0; }
.ov__ceja { margin: 0; font: 500 12px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-menta); }
.ov__titulo { margin: 10px 0 0; font: 600 clamp(1.5rem, 2.4vw, 1.9rem)/1.15 var(--hb-serif); }
.ov__desc { margin: 12px 0 0; color: color-mix(in srgb, var(--hb-papel-claro) 82%, transparent); line-height: 1.55; }
.ov__puntos { list-style: none; margin: 16px 0 0; padding: 0; display: grid; gap: 8px; }
.ov__puntos li { display: flex; gap: 10px; line-height: 1.45; }
.ov__puntos li::before { content: '✓'; color: var(--hb-menta); font-weight: 700; }

.ov__tel { justify-self: center; width: min(320px, 100%); padding: 8px; border-radius: 30px; background: #0c1a12; box-shadow: 0 30px 60px -30px rgb(0 0 0 / .6); }
.ov__pantalla { border-radius: 23px; overflow: hidden; background: #F4F8F5; color: #1A1D1F; min-height: 430px; font-family: var(--hb-sans); }
.ov__tel-cab { background: #1A3D2E; color: #fff; padding: 14px 16px; display: flex; flex-direction: column; }
.ov__tel-cab small { font-size: 11px; color: #A8C9B5; }
.ov__tel-cab b { font-size: 16px; }
.ov__tel-cuerpo { padding: 12px; display: flex; flex-direction: column; gap: 7px; font-size: 12px; }
.ov__tel-cuerpo > * { opacity: 0; animation: ov-entra .35s ease forwards; }
.ov__fila { background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 9px 10px; display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.ov__fila > div { display: flex; flex-direction: column; min-width: 0; }
.ov__fila small, .ov__caja small, .ov__turno small { font-size: 10.5px; color: #3A3F44; }
.ov__fila--on { border-color: #2D4A3E; }
.ov__fila > .ov__botones { display: flex; gap: 4px; flex-direction: row; }
.ov__b { padding: 4px 8px; border-radius: 8px; background: #2D4A3E; color: #fff; font-size: 10.5px; font-weight: 700; white-space: nowrap; text-align: center; }
.ov__b--linea { background: #fff; color: #1A1D1F; border: 1px solid #D1D5DB; font-weight: 600; }
.ov__b--ancho { padding: 10px; font-size: 12px; display: block; }
.ov__sec { margin: 4px 0 0; font-size: 10.5px; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; color: #3A3F44; }
.ov__aviso { background: #FEF3C7; color: #92400E; border-radius: 10px; padding: 8px 10px; font-size: 11px; font-weight: 600; }
.ov__caja { background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 10px; display: flex; flex-direction: column; gap: 6px; }
.ov__caja--on { border: 1.5px solid #2D4A3E; }
.ov__entre { display: flex; justify-content: space-between; gap: 8px; }
.ov__chico { font-size: 10.5px; color: #3A3F44; }
.ov__total { border-top: 1px solid #1A1D1F; padding-top: 6px; }
.ov__dos { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; }
.ov__dato { background: #fff; border: 1px solid #D1D5DB; border-radius: 8px; padding: 7px 9px; display: flex; flex-direction: column; }
.ov__dato b { font-size: 14px; }
.ov__dato--on { border: 2px solid #2D4A3E; }
.ov__turno { display: grid; grid-template-columns: 34px minmax(0, 1fr) auto; gap: 6px; align-items: center; background: #fff; border: 1px solid #E1E8E3; border-left: 3px solid #D1D5DB; border-radius: 6px; padding: 6px 8px; }
.ov__turno > div { display: flex; flex-direction: column; min-width: 0; }
.ov__turno--realizado, .ov__turno--confirmado { border-left-color: #2D4A3E; }
.ov__turno--ausente { border-left-color: #B98532; }
.ov__turno--pendiente { border-left-color: #9B2C1E; }
.ov__turno--ahora { border-color: #2D4A3E; box-shadow: 0 0 0 3px #DCEDE1; }
.ov__estado { font: 500 9.5px var(--hb-mono); text-transform: uppercase; letter-spacing: .04em; padding: 2px 6px; border-radius: 99px; border: 1px solid #D1D5DB; color: #3A3F44; white-space: nowrap; }
.ov__turno--pendiente .ov__estado { border-color: #9B2C1E; color: #9B2C1E; }
.ov__turno--ahora .ov__estado { background: #2D4A3E; border-color: #2D4A3E; color: #fff; }
.ov__verde { color: #2D4A3E; }
.ov__ambar { color: #B45309; }
.ov__mayus { text-transform: uppercase; letter-spacing: .06em; font-weight: 700; }
@keyframes ov-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .ov__tel-cuerpo > * { animation: none; opacity: 1; } }
</style>
