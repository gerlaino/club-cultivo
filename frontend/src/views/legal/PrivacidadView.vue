<template>
  <LegalLayout titulo="Política de privacidad">
    <div class="lg-resumen">
      <p><strong>En pocas palabras:</strong></p>
      <ul>
        <li>Guardamos lo necesario para que la app funcione, y nada más.</li>
        <li>Los datos de salud son sensibles: sólo los tratamos con tu consentimiento expreso y con cuidado reforzado.</li>
        <li>No vendemos datos, no hacemos publicidad y no usamos cookies de seguimiento.</li>
        <li>Podés pedir ver, corregir o borrar tus datos cuando quieras, escribiendo a <a :href="`mailto:${TITULAR.mail}`">{{ TITULAR.mail }}</a>.</li>
      </ul>
    </div>

    <h2>1. Quién es responsable de tus datos</h2>
    <p>
      Si usás Cultivo Espacial para tu cultivo personal, el responsable de tus datos es Cultivo Espacial. Para
      cualquier consulta o pedido sobre tus datos, escribinos a <a :href="`mailto:${TITULAR.mail}`">{{ TITULAR.mail }}</a>.
    </p>
    <p>
      Si tus datos los cargó una <strong>organización</strong> de la que sos paciente o miembro, la responsable es esa
      organización, y nosotros los tratamos por cuenta de ella (ver el punto 10).
    </p>

    <h2>2. Qué datos guardamos</h2>
    <ul>
      <li><strong>De tu cuenta:</strong> nombre, mail y contraseña (guardada cifrada: nadie puede leerla, ni nosotros).</li>
      <li><strong>De tu cultivo:</strong> lo que cargás — genéticas, lotes y plantas, riegos, nutrientes, mediciones, fotos, cosechas, frascos, gastos, notas y tareas.</li>
      <li><strong>Técnicos:</strong> la dirección IP y el navegador con los que te registraste y aceptaste estos términos, la fecha de tu último ingreso, y registros de errores de la app.</li>
      <li><strong>Notificaciones:</strong> si las activás, el identificador que tu navegador nos da para mandarte avisos.</li>
      <li><strong>En organizaciones</strong>, además: los datos de sus pacientes que la organización carga, que pueden incluir datos de salud (inscripción en el REPROCANN, indicaciones médicas, dispensas).</li>
    </ul>

    <h2>3. Datos de salud: datos sensibles</h2>
    <p>
      Los datos sobre tu salud y sobre el uso medicinal de cannabis son <strong>datos sensibles</strong> (art. 2 de la
      Ley 25.326). Sólo los tratamos con tu <strong>consentimiento expreso</strong>, que das al registrarte (art. 7), y
      nadie está obligado a darlos: la app funciona igual si no los cargás. Los protegemos con las medidas del punto 7 y
      nunca los usamos para nada distinto de prestarte el servicio.
    </p>

    <h2>4. Para qué los usamos</h2>
    <ul>
      <li>Para prestarte el servicio: guardar tus registros, mostrarte tu cultivo, calcular estadísticas, armar informes y mandarte los recordatorios que elegiste.</li>
      <li>Para la seguridad de tu cuenta y de la plataforma (por ejemplo, frenar intentos de acceso indebido).</li>
      <li>Para comunicarnos con vos sobre el servicio: confirmar tu mail, avisarte del fin de la prueba o de cambios en estos textos, y responder tus consultas.</li>
      <li>Para mejorar la plataforma, sólo con información agregada y anonimizada que no permita identificar a nadie.</li>
      <li>Para cumplir obligaciones legales.</li>
    </ul>
    <p>No vendemos datos, no los usamos para publicidad y no armamos perfiles comerciales.</p>

    <h2>5. Con quién los compartimos</h2>
    <p>
      No cedemos tus datos a terceros. Para funcionar usamos proveedores que los procesan por cuenta nuestra, con
      obligación de confidencialidad, y sólo para lo que les encargamos:
    </p>
    <ul>
      <li><strong>Render</strong> — servidores y base de datos de la app.</li>
      <li><strong>Amazon Web Services</strong> — almacenamiento de fotos y de las copias de seguridad.</li>
      <li><strong>Google</strong> — envío de los mails de la plataforma.</li>
      <li><strong>Sentry</strong> — registro de errores técnicos, para corregirlos.</li>
      <li><strong>Anthropic</strong> — sólo si tu cuenta tiene el asistente con inteligencia artificial y lo usás: el texto de tu pregunta y los datos necesarios para contestarla.</li>
      <li><strong>Twilio</strong> — sólo para organizaciones que activan avisos por WhatsApp.</li>
      <li><strong>Apple, Google o Mozilla</strong> — el canal de notificaciones de tu navegador, si las activás (el aviso viaja con el texto que ves en pantalla).</li>
    </ul>
    <p>
      Algunos de estos proveedores tienen sus servidores fuera de la Argentina, principalmente en Estados Unidos. Al
      aceptar esta política consentís esa transferencia internacional (art. 12 de la Ley 25.326); exigimos a los
      proveedores niveles de protección adecuados. También podemos entregar datos a una autoridad pública cuando una ley
      o una orden judicial lo exijan.
    </p>

    <h2>6. Cuánto tiempo los guardamos</h2>
    <p>
      Mientras tu cuenta exista. Si te das de baja, borramos o anonimizamos tus datos dentro de los 30 días, salvo lo que
      una ley nos obligue a conservar. Las copias de seguridad se guardan 30 días y se renuevan solas: lo que borramos
      desaparece de ellas en ese plazo.
    </p>

    <h2>7. Cómo los cuidamos</h2>
    <ul>
      <li>Todo viaja cifrado (HTTPS) y las contraseñas se guardan con un algoritmo que no se puede revertir.</li>
      <li>Cada cuenta y cada organización están aisladas: nadie ve los datos de otra.</li>
      <li>El acceso de nuestro equipo a los datos es restringido y sólo para dar soporte o resolver un problema.</li>
      <li>Las sesiones vencen solas después de 7 días sin uso, y cambiar la contraseña cierra las sesiones abiertas en otros dispositivos.</li>
      <li>Hacemos copias de seguridad todos los días.</li>
    </ul>
    <p>
      Ningún sistema es infalible. Si ocurriera un incidente de seguridad que afecte tus datos, te avisamos y te decimos
      qué hacer.
    </p>

    <h2>8. Cookies y almacenamiento en tu dispositivo</h2>
    <p>
      Usamos <strong>una sola cookie</strong>, técnica y necesaria: la que mantiene tu sesión abierta (no es accesible
      desde la página y no sirve para seguirte por internet). Además, la app guarda en tu dispositivo algunas
      preferencias y lo necesario para funcionar sin conexión. No usamos cookies de publicidad ni de análisis de terceros.
    </p>

    <h2>9. Tus derechos</h2>
    <p>
      Podés pedir <strong>acceder</strong> a tus datos, <strong>corregirlos</strong>, <strong>actualizarlos</strong> o
      <strong>suprimirlos</strong>, y retirar tu consentimiento cuando quieras (arts. 14 a 16 de la Ley 25.326),
      escribiendo a <a :href="`mailto:${TITULAR.mail}`">{{ TITULAR.mail }}</a> desde el mail de tu cuenta. Contestamos los
      pedidos de acceso dentro de los 10 días corridos y los de rectificación o supresión dentro de los 5 días hábiles. Retirar
      el consentimiento sobre los datos de salud puede implicar que dejemos de prestarte la parte del servicio que los usa.
    </p>
    <p class="lg-legal">
      El titular de los datos personales tiene la facultad de ejercer el derecho de acceso a los mismos en forma gratuita a
      intervalos no inferiores a seis meses, salvo que se acredite un interés legítimo al efecto conforme lo establecido en
      el artículo 14, inciso 3 de la Ley N° 25.326. La AGENCIA DE ACCESO A LA INFORMACIÓN PÚBLICA, en su carácter de Órgano
      de Control de la Ley N° 25.326, tiene la atribución de atender las denuncias y reclamos que interpongan quienes
      resulten afectados en sus derechos por incumplimiento de las normas vigentes en materia de protección de datos
      personales.
    </p>

    <h2>10. Si tus datos los cargó una organización</h2>
    <p>
      La organización (asociación, fundación u otra) es la responsable de esos datos: para ejercer tus derechos, dirigite
      primero a ella. Nosotros actuamos como encargados del tratamiento por su cuenta (art. 25 de la Ley 25.326): usamos
      esos datos sólo para prestarle el servicio, no los cedemos, y cuando la organización deja la plataforma se los
      devolvemos o los destruimos. Si no lográs resolverlo con la organización, escribinos y te ayudamos.
    </p>

    <h2>11. Menores de edad</h2>
    <p>La plataforma no está dirigida a menores de 18 años y no les permitimos crear una cuenta.</p>

    <h2>12. Cambios en esta política</h2>
    <p>
      Si la cambiamos, te avisamos por mail o en la app con al menos 15 días de anticipación. La fecha de la versión vigente
      está arriba. Esta política se complementa con los <RouterLink to="/terminos">Términos y condiciones</RouterLink>.
    </p>
  </LegalLayout>
</template>

<script setup>
// Política de privacidad (borrador, 4-oct-2026). Cubre lo que pide la Ley 25.326 para una app con
// datos de salud: responsable (Cultivo Espacial y su mail, sin nombres: ver titular.js), finalidad, consentimiento expreso para datos sensibles
// (art. 7), transferencia internacional a los proveedores (art. 12), derechos y plazos (arts. 14–16),
// la leyenda obligatoria de la AAIP, y el rol de encargado frente a las organizaciones (art. 25).
//
// La lista de proveedores tiene que coincidir con lo que la app usa de verdad: si se suma uno
// (otro correo, otro hosting), se agrega acá.
import LegalLayout from './LegalLayout.vue'
import { TITULAR } from './titular.js'
</script>
