<template>
  <LegalLayout titulo="Términos y condiciones de uso">
    <div class="lg-resumen">
      <p><strong>En pocas palabras:</strong></p>
      <ul>
        <li>Cultivo Espacial es una herramienta para registrar y ordenar tu cultivo. No autoriza a cultivar: eso lo dan la ley y el REPROCANN, y es tu responsabilidad.</li>
        <li>Tus datos son tuyos. No los vendemos ni los usamos para publicidad.</li>
        <li>El uso personal se prueba gratis {{ diasPrueba }} días, sin tarjeta. Nunca cobramos sin que lo aceptes antes.</li>
        <li>Te podés arrepentir dentro de los 10 días y dar de baja cuando quieras, sin explicar nada.</li>
        <li>Lo que la app calcula o sugiere (incluida la IA) es orientativo: no es consejo médico.</li>
      </ul>
      <p>Este resumen ayuda a leer; lo que vale es el texto completo de abajo.</p>
    </div>

    <h2>1. Quiénes somos</h2>
    <p>
      Cultivo Espacial («la plataforma», «nosotros») es un software en internet para registrar y gestionar
      cultivos de cannabis: el de una persona para su propio uso autorizado y el de organizaciones (asociaciones,
      fundaciones, investigación y producción). Contacto: <a :href="`mailto:${TITULAR.mail}`">{{ TITULAR.mail }}</a>.
    </p>

    <h2>2. Aceptación</h2>
    <p>
      Al crear una cuenta, o al usar la plataforma, aceptás estos términos y la
      <RouterLink to="/privacidad">Política de privacidad</RouterLink>. Si no estás de acuerdo, no la uses.
      Cuando una organización contrata la plataforma, además rige el acuerdo comercial que firmemos con ella;
      si algo de ese acuerdo contradice estos términos, prevalece el acuerdo.
    </p>

    <h2>3. Quién puede usarla, y para qué</h2>
    <ul>
      <li>Personas mayores de 18 años con capacidad para contratar.</li>
      <li>
        El <strong>uso personal</strong> es para quien cultiva para sí dentro del marco legal argentino (Ley 27.350 de
        uso medicinal del cannabis, su Decreto reglamentario 883/2020 y el Registro del Programa de Cannabis,
        REPROCANN). <strong>Contar con las autorizaciones que correspondan es tu responsabilidad.</strong>
        Cultivo Espacial no las otorga, no las verifica y no las reemplaza; registrar un cultivo en la plataforma
        no lo vuelve legal.
      </li>
      <li>
        No podés usar la plataforma para actividades prohibidas por la ley (entre otras, la Ley 23.737), ni para
        comercializar cannabis fuera de lo que la normativa permita.
      </li>
    </ul>

    <h2>4. Tu cuenta</h2>
    <ul>
      <li>Los datos con los que te registrás tienen que ser verdaderos, y el mail, tuyo: te vamos a pedir que lo confirmes. Si no lo confirmás dentro de los 7 días de recibido el mail, la cuenta se pausa hasta que lo hagas (no se borra nada).</li>
      <li>Tu contraseña es personal. Sos responsable de lo que se haga desde tu cuenta; si sospechás que alguien más entró, cambiala y avisanos.</li>
      <li>Por comodidad, la sesión queda abierta en tu dispositivo hasta 7 días sin uso. En una computadora compartida, cerrá sesión al terminar.</li>
    </ul>

    <h2>5. Prueba gratis y precio</h2>
    <ul>
      <li>El uso personal tiene una prueba gratis de {{ diasPrueba }} días, sin tarjeta ni medio de pago.</li>
      <li>Al terminar la prueba, si no acordaste continuar, la cuenta se pausa: no se borra nada, y la podés reactivar o pedir tus datos.</li>
      <li>El precio después de la prueba, y el de las organizaciones, se consulta y se acuerda antes de cualquier cobro. <strong>Nunca te vamos a cobrar sin que hayas aceptado expresamente el precio final.</strong></li>
      <li>Si cambia el precio de algo que ya pagás, te avisamos con al menos 30 días de anticipación y podés darte de baja antes sin costo.</li>
    </ul>

    <h2 id="arrepentimiento">6. Arrepentimiento y baja</h2>
    <ul>
      <li>
        <strong>Arrepentimiento:</strong> podés revocar la aceptación del servicio dentro de los 10 días corridos desde
        que lo contrataste o desde que estuvo disponible, lo último que ocurra, sin costo y sin dar explicaciones
        (art. 34 de la Ley 24.240 de Defensa del Consumidor y art. 1110 del Código Civil y Comercial). Lo pedís desde el
        <RouterLink :to="{ path: '/contacto', query: { tipo: 'baja' } }">botón de arrepentimiento</RouterLink>
        de nuestra página, que está siempre a la vista, o por mail. Al pedirlo desde la página te damos en el momento
        un código de trámite (por mail, dentro de las 24 horas). Si hubieras pagado algo, te lo devolvemos completo.
      </li>
      <li><strong>Baja:</strong> te podés dar de baja cuando quieras, por el mismo medio (o el que prefieras de los anteriores), sin trámites adicionales.</li>
      <li>Antes de irte podés pedirnos una copia de tus datos.</li>
    </ul>

    <h2>7. Tus datos y tu contenido</h2>
    <ul>
      <li>Todo lo que cargás (registros, mediciones, fotos, notas, gastos) es tuyo.</li>
      <li>
        Nos das un permiso limitado, no exclusivo y gratuito para guardarlo, procesarlo y mostrártelo
        <strong>sólo para prestarte el servicio</strong>: copias de seguridad, informes, estadísticas y recordatorios.
        El permiso termina cuando borrás el contenido o te das de baja (salvo lo que la ley nos obligue a conservar).
      </li>
      <li>No vendemos tus datos ni los usamos para publicidad. Podemos usar información agregada y anonimizada, que no permita identificar a nadie, para mejorar la plataforma.</li>
      <li>
        Sos responsable de verificar que las publicaciones que realizás, incluidas aquellas en las que aparecen terceras
        personas, cuenten con la debida autorización para su difusión, cuando esta resulte legalmente exigible.
      </li>
      <li>Cómo tratamos los datos personales, y en particular los de salud, está en la <RouterLink to="/privacidad">Política de privacidad</RouterLink>.</li>
    </ul>

    <h2>8. Lo que no se puede hacer</h2>
    <p>No está permitido:</p>
    <ul>
      <li>intentar acceder a cuentas o datos ajenos, o vulnerar la seguridad de la plataforma;</li>
      <li>copiar, descompilar o hacer ingeniería inversa del software, o revenderlo;</li>
      <li>sobrecargar la plataforma o usarla en forma automatizada sin nuestro permiso;</li>
      <li>cargar contenido ilegal, o usarla para publicitar o vender cannabis o derivados en infracción a la normativa.</li>
    </ul>

    <h2>9. No es consejo médico ni agronómico</h2>
    <p>
      Los recordatorios, cálculos (dosis, VPD, rendimiento, fechas estimadas), sugerencias y respuestas del asistente
      con inteligencia artificial son <strong>orientativos</strong>: pueden tener errores y no reemplazan el criterio de
      un profesional. La inteligencia artificial, en particular, puede equivocarse. Las decisiones sobre tu salud y tu
      tratamiento, consultalas con tu médico.
    </p>

    <h2>10. Disponibilidad y cambios en la plataforma</h2>
    <p>
      Hacemos lo razonable para que la plataforma funcione siempre y para resguardar tus datos (con copias de seguridad
      diarias), pero puede haber interrupciones por mantenimiento, por fallas de proveedores o de conectividad. La
      plataforma evoluciona: podemos agregar, cambiar o retirar funciones. Si quitamos algo esencial de lo que pagás, te
      avisamos con anticipación y podés darte de baja sin costo.
    </p>

    <h2>11. Responsabilidad</h2>
    <p>
      Respondemos por el servicio según la ley aplicable. No somos responsables por las decisiones de cultivo o de salud
      que tomes con la información de la plataforma, por los resultados de una cosecha, por el uso contrario a la ley que
      alguien haga de ella, por el contenido que cargan los usuarios, ni por fallas de terceros o hechos fuera de nuestro
      control razonable (caso fortuito o fuerza mayor). <strong>Nada de estos términos limita los derechos que la Ley 24.240
      de Defensa del Consumidor te reconoce y que no se pueden renunciar.</strong>
    </p>

    <h2>12. Organizaciones y datos de sus pacientes</h2>
    <p>
      Cuando una organización carga datos de sus pacientes o miembros, <strong>la organización es la responsable</strong>
      de esos datos y de contar con el consentimiento de sus titulares y las autorizaciones regulatorias que su actividad
      requiera. Cultivo Espacial actúa como <strong>encargado del tratamiento</strong> por cuenta de ella (art. 25 de la
      Ley 25.326): usamos esos datos sólo para prestarle el servicio, los tratamos con confidencialidad, no los cedemos, y
      al terminar la relación se los devolvemos o los destruimos, según nos indique.
    </p>

    <h2>13. Suspensión</h2>
    <p>
      No revisamos en forma permanente el uso de cada cuenta. En caso de detectarse o advertirse un uso
      indebido —por nuestros propios medios o por requerimiento de una autoridad competente—, nos reservamos el
      derecho de suspender o dar de baja la cuenta que incumpla estos términos o la ley, avisando antes cuando sea posible. Mientras una cuenta está suspendida no se borran sus datos, y su titular puede pedir una copia.
    </p>

    <h2>14. Cambios en estos términos</h2>
    <p>
      Si cambiamos estos términos, te avisamos por mail o en la app con al menos 15 días de anticipación. Si no estás de
      acuerdo con el cambio, podés darte de baja antes de que entre en vigencia. La fecha de la versión vigente está arriba.
    </p>

    <h2>15. Ley aplicable y reclamos</h2>
    <p>
      Rigen las leyes de la República Argentina. Si sos consumidor, son competentes los tribunales de tu domicilio
      (art. 36 de la Ley 24.240), y también podés reclamar ante la autoridad de defensa del consumidor de tu jurisdicción
      o en la Ventanilla Única Federal de Defensa del Consumidor. Para organizaciones, son competentes los tribunales
      que fije el acuerdo comercial. Antes de cualquier reclamo, escribinos: casi todo se resuelve así.
    </p>
  </LegalLayout>
</template>

<script setup>
// Términos y condiciones (borrador de Germán y Claude, 4-oct-2026). Escritos para que se entiendan
// —con un resumen arriba, como hacen las apps que se leen de verdad— y con lo que la ley argentina
// exige a un servicio que se contrata por internet: contacto (sin nombres: ver titular.js), arrepentimiento y
// baja (Ley 24.240, Res. SCI 424/2020), y el rol de encargado frente a los datos de las
// organizaciones (Ley 25.326). Los días de prueba los dice el backend.
//
// Si cambia algo que afecte a lo aceptado, subir `Legal::TERMINOS_VERSION` y `VIGENCIA`.
import { ref, onMounted } from 'vue'
import LegalLayout from './LegalLayout.vue'
import { TITULAR } from './titular.js'
import { getRegistroInfo } from '../../lib/api.js'

const diasPrueba = ref(30)
onMounted(async () => {
  try { diasPrueba.value = (await getRegistroInfo()).data.dias_prueba } catch {}
})
</script>
