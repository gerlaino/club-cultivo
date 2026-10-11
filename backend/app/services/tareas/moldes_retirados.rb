module Tareas
  module MoldesRetirados
    # LA APP YA NO CREA TAREAS SOLA AL CAMBIAR DE FASE (Germán, 11-oct-2026: «que las tareas las
    # generen los usuarios, no nosotros»). Hasta entonces `TareasAutoService` creaba una lista fija
    # cada vez que un lote entraba en una fase —medir EC/pH y «primer riego» al pasar a vegetativo,
    # cinco al entrar en floración…—, sin mirar lo que la persona ya había hecho ni preguntarle: le
    # agendaba un riego que acababa de registrar.
    #
    # Quedan sólo los títulos, para reconocer las que quedaron pendientes (no tienen otra marca):
    # deshacer una floración las cancela (`Salas::CambiarFase`) y `rake tareas:cancelar_automaticas`
    # limpia las viejas. Si algún día vuelve, que sea como propuesta que la persona confirma.
    POR_FASE = {
      'vegetativo' => ['Medir EC y pH del sustrato', 'Primer riego en vegetativo', 'Inspección de plagas',
                       'Revisar humedad del suelo y el mulch'],
      'floracion'  => ['Ajustar fotoperiodo a 12/12', 'Revisar/ajustar SCROG o LST', 'Defoliación de inicio de flor',
                       'Medir VPD y ajustar si necesario', 'Inspección preventiva de plagas y hongos'],
      'cosecha'    => ['Cosechar lote — coordinar equipo', 'Limpiar y preparar sala post-cosecha',
                       'Cortar al ras y dejar las raíces; tapar la cama con mulch'],
      'secado'     => ['Control de temperatura y humedad en secado', 'Inspección visual de secado (botritis)'],
      'curado'     => ['Control de humedad en frascos', 'Burping — ventilación de frascos'],
    }.freeze

    TITULOS = POR_FASE.values.flatten.freeze
  end
end
